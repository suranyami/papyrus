# Testing Papyrus

## Two-Tier Test Taxonomy

Papyrus tests are organized into two tiers:

### Tier 1: CI-Safe Tests (default)

**Location:** `test/papyrus/`
**Run with:** `mix test`

These tests run on any machine (macOS, Linux, CI) with no display hardware.
They use `Papyrus.MockPort` — an Elixir script that speaks the length-prefixed
binary protocol — instead of the real C port binary.

The mock port supports **configurable responses per-test**: tests can specify
what the mock returns for each command, enabling error-path testing without hardware.
See `Papyrus.MockPort.write_response_file/2` for details.

Modules tested:
- `Papyrus.Protocol` — encode/decode round-trips
- `Papyrus.DisplaySpec` — struct enforcement and field validation
- `Papyrus.TestPattern` — buffer generation for all pattern types
- `Papyrus.Display` — GenServer lifecycle via mock port (happy and error paths)

### Tier 2: Hardware-Required Tests

**Location:** `test/hardware/`
**Run with:** `mix test test/hardware/ --include hardware`

These tests require a Raspberry Pi with a Waveshare ePaper display physically
connected. They are excluded from `mix test` by default via the `:hardware` tag
in `test/test_helper.exs`.

Use these for:
- End-to-end display refresh verification
- GPIO pin configuration validation
- SPI timing and panel addressing
- Visual confirmation of test patterns on real hardware

### Writing New Tests

**CI-safe test:** Place in `test/papyrus/`. Use `Papyrus.MockPort.port_executable()`
when you need a Display GenServer. No special tags needed.

**Error-path test:** Use `Papyrus.MockPort.write_response_file/2` to configure
which commands should return errors:

    responses = %{MockPort.command_byte(:clear) => {1, "hardware fault"}}
    path = MockPort.write_response_file(responses, "my_test")
    {:ok, pid} = Display.start_link(
      display_module: MyDisplay,
      port_binary: MockPort.port_executable(path)
    )

**Hardware test:** Place in `test/hardware/`. Tag the module:

    @moduletag :hardware

This ensures `mix test` skips it unless `--include hardware` is passed.

## Running Tests

```bash
# Run all CI-safe tests (default)
mix test

# Run a specific test file
mix test test/papyrus/protocol_test.exs

# Run hardware tests on a Raspberry Pi
mix test test/hardware/ --include hardware

# Run everything (CI + hardware)
mix test --include hardware
```
