# AGENTS.md

This file provides guidance to LLM agents when working with code in this repository.

## Tool Version Management (mise)

This project uses [mise](https://mise.jdx.dev/) for managing Elixir and Erlang versions.

- **`.mise.toml`** — committed; defines required Elixir/Erlang versions
- **`.mise.local.toml`** — gitignored; use for local overrides

```sh
mise install          # Install versions declared in .mise.toml
mise exec -- mix ...  # Run mix commands under mise-managed runtime (if not activated in shell)
```

Before running any `mix` commands, ensure `mise` is active in your shell or use `mise exec`.

## Quick Reference

```sh
# Dependencies
mix deps.get

# Build (compiles Elixir + C port via elixir_make)
mix compile

# Run tests
mix test
mix test test/path/to/test.exs:42  # Specific test
mix test --failed                   # Re-run failed tests

# Code quality
mix format                # Format Elixir code
mix format --check-formatted  # Check formatting (CI)
mix credo -a --strict     # Lint

# Documentation
mix docs                  # Generate ExDoc HTML in doc/

# Build C port manually (on target hardware)
cd c_src && make
```

## Architecture

**This is a Port-based hardware driver library.** Understand the design before writing code.

### Why a Port, not a NIF?

ePaper display refreshes take 1–30 seconds and involve hardware I/O that can fault.
A Port crash (hardware fault, lgpio error) kills only the OS process — the BEAM VM and
your supervision tree stay alive. A NIF segfault kills the whole VM.

### System overview

```
Caller
  │
  ▼
Papyrus (public API) — thin delegating module
  │
  ▼
Papyrus.Display (GenServer)
  │  owns and monitors
  ▼
priv/epd_port (C binary via OS Port)
  │  GPIO/SPI via liblgpio
  ▼
Waveshare 12.48" ePaper hardware
```

### Module map

| Module | Role |
|--------|------|
| `Papyrus` | Public API — delegates to `Papyrus.Display` |
| `Papyrus.Display` | GenServer; owns the port, serialises all hardware calls |
| `Papyrus.Protocol` | Binary encode/decode for the port wire protocol |
| `Papyrus.DisplaySpec` | Behaviour + struct describing a display model |
| `Papyrus.Displays.Waveshare12in48` | Concrete spec for the 12.48" B&W panel |
| `Papyrus.Application` | OTP application entry point (empty supervisor root) |
| `c_src/epd_port.c` | C port binary — init/display/clear/sleep over stdin/stdout |
| `c_src/waveshare/epd12in48/` | Extracted Waveshare C driver (EPD + DEV_Config) |

### Port wire protocol

```
Request  (Elixir → C):  [1 byte: cmd][4 bytes: payload_len BE][payload_len bytes]
Response (C → Elixir):  [1 byte: status 0=ok/1=err][4 bytes: msg_len BE][msg_len bytes]
```

Commands:

| Byte | Atom | Payload |
|------|------|---------|
| `0x01` | `:init` | empty |
| `0x02` | `:display` | 160,392-byte image buffer |
| `0x03` | `:clear` | empty |
| `0x04` | `:sleep` | empty |

### Image buffer format

- Size: `ceil(width / 8) × height` = `163 × 984` = 160,392 bytes
- Bit order: MSB first; bit 7 of byte 0 = pixel (0, 0)
- `1` = white, `0` = black

## Adding a New Display Model

1. **Add the C driver sources** to `c_src/waveshare/<model>/` (or equivalent vendor dir)
2. **Update `c_src/Makefile`** to compile the new source files
3. **Add a new command byte** to `c_src/epd_port.c` if the display needs different commands
4. **Update `Papyrus.Protocol`** with new command atoms and `cmd_byte/1` clauses
5. **Create the display spec module** `lib/papyrus/displays/<vendor>_<model>.ex` implementing `@behaviour Papyrus.DisplaySpec`
6. **Update `mix.exs`** `groups_for_modules` under `docs` to include the new module
7. **Add to the README** supported hardware table

## Code Style — Non-Negotiables

These rules apply to ALL Elixir code in this repository.

**Pattern matching — NEVER use `cond`, `case`, or `if` when pattern matching works:**
- NEVER use `cond` — use multiple pattern-matched function heads with guards instead.
- Avoid `case` when a pattern-matched function head or `with` will do.
- Use `with` to chain `{:ok, _}` / `{:error, _}` operations instead of nested `case`.

```elixir
# WRONG — case when function heads work
def decode(<<0::8, rest::binary>>), do:
  case rest do
    <<len::32-big, msg::binary-size(len)>> -> {:ok, msg}
    _ -> :incomplete
  end

# RIGHT — pattern match everything in the head
def decode(<<0::8, len::32-big, msg::binary-size(len)>>), do: {:ok, msg}
def decode(_), do: :incomplete
```

**Logging — ALWAYS use `Logger`, NEVER `IO.puts`/`IO.warn`:**
- `Logger.info/1` for progress/status
- `Logger.warning/1` for recoverable issues
- `Logger.error/1` for failures requiring attention
- `IO.puts` and `IO.warn` are **never** acceptable in library or application code

```elixir
# WRONG
IO.puts("Port opened")

# RIGHT
Logger.info("epd_port opened at #{port_path}")
```

**Extract repeated logic:**
- If the same block appears more than once, extract it into a private helper immediately.

## C Code Guidelines

- Keep all C code confined to `c_src/`
- Vendor driver code lives under `c_src/<vendor>/<model>/` — do not modify it unless strictly necessary; prefer wrapping
- `epd_port.c` is the only file that speaks the port protocol; keep display dispatch in the `switch` statement clean
- Use `send_ok()` / `send_error()` helpers consistently — never write raw `write()` calls for responses
- All I/O must go through `read_exact` / `write_exact` — partial reads/writes are silent corruption bugs
- The port binary must never write to stdout for any purpose other than protocol responses (no debug `printf`); use stderr for debug output during development, remove before committing

## Testing

There is no real hardware in CI. Tests must work without the physical display.

**Strategy: inject a mock port binary via `:port_binary` option.**

`Papyrus.Display.start_link/1` accepts a `:port_binary` option that overrides the default
`priv/epd_port` path. In tests, point this at a small script or compiled stub that speaks
the same protocol.

```elixir
# In test/support/mock_epd_port — a minimal shell script that ACKs every command:
# #!/bin/sh
# while true; do
#   read -r -n 5 hdr || exit 0          # consume 5-byte header
#   printf '\x00\x00\x00\x00\x02ok'     # status=ok, len=2, msg="ok"
# done

# In tests:
{:ok, display} =
  Papyrus.Display.start_link(
    display_module: Papyrus.Displays.Waveshare12in48,
    port_binary: "test/support/mock_epd_port"
  )
```

**General testing rules:**
- Use `start_supervised!/1` for GenServers — never start processes outside the test supervisor
- Avoid `Process.sleep/1` — use `Process.monitor` + `assert_receive {:DOWN, ...}` or `:sys.get_state/1` to synchronise
- Test `Papyrus.Protocol` encode/decode directly — it is pure and has no hardware dependency
- Test `Papyrus.DisplaySpec` structs directly — no process needed

## Code Quality

**Run before every commit:**

```sh
mix format --check-formatted
mix credo -a --strict
mix test
```

There is no `mix check` alias yet — add one to `mix.exs` if you set up dialyzer.

## Git Workflow

- `main` — stable, releasable
- Feature branches: `feat/<short-description>`
- Bug fixes: `fix/<short-description>`

Commit message convention: `type(scope): description`
- `feat(display): add support for Waveshare 7.5" V2`
- `fix(protocol): handle truncated response across two port messages`
- `docs(readme): add 7.5" V2 to supported hardware table`
