---
phase: 02-test-infrastructure-and-testpattern
plan: "02"
subsystem: test-infrastructure
tags: [mock-port, testing, protocol, tdd]
dependency_graph:
  requires: []
  provides: [Papyrus.MockPort, test/support/mock_port_script.exs, test/support/mock_port.sh]
  affects: [test/papyrus/mock_port_test.exs]
tech_stack:
  added: []
  patterns:
    - Compile-time path resolution via __DIR__ module attribute for test support files
    - Erlang binary term format for inter-process response configuration
    - Port.monitor + :DOWN message for port lifecycle assertions (not Port.close + :exit_status)
    - :file.read/:file.write for raw binary stdin/stdout in elixir scripts
key_files:
  created:
    - lib/papyrus/mock_port.ex
    - test/support/mock_port_script.exs
    - test/support/mock_port.sh
  modified:
    - test/papyrus/mock_port_test.exs
    - lib/papyrus/displays/waveshare_12in48.ex
decisions:
  - Use :file.read/:file.write (not IO.binread/IO.binwrite) for raw binary port I/O in elixir scripts
  - Compile-time __DIR__ for test support path resolution, not runtime :code.priv_dir which resolves to _build
  - Port.monitor + :DOWN message to test port lifecycle — Port.close does not deliver :exit_status
  - Per-invocation shell wrapper script written to System.tmp_dir! for configurable responses, since Port.open does not support args
metrics:
  duration_seconds: 274
  completed_date: "2026-03-29"
  tasks_completed: 1
  files_modified: 5
---

# Phase 02 Plan 02: MockPort — Configurable Mock Port for Hardware-Free Testing Summary

Mock port binary (Elixir script + shell wrapper) that speaks the Papyrus length-prefixed binary protocol over stdin/stdout, with per-test configurable responses enabling error-path testing without hardware.

## What Was Built

### `test/support/mock_port_script.exs`
Standalone Elixir script run via `elixir`. Reads an optional response config file path from `System.argv()`. Loops reading 5-byte headers (`cmd::8, len::32-big`), reads payload bytes if len > 0, looks up `%{cmd_byte => {status, message}}` in the response map (defaulting to `{0, ""}` on miss), and writes the response `<<status::8, msg_len::32-big, message::binary>>`. Uses `:file.read/:file.write` for raw binary I/O.

### `test/support/mock_port.sh`
Executable shell wrapper: `exec elixir "$(dirname "$0")/mock_port_script.exs" "$@"`. Passes through any arguments (response file path).

### `lib/papyrus/mock_port.ex`
Helper module with:
- `port_executable/0` — returns path to the shell wrapper for default (all-success) responses
- `port_executable/1` — takes a response file path, writes a per-invocation tmp wrapper that bakes in the path, returns its path
- `write_response_file/2` — serializes a `%{cmd_byte => {status, message}}` map to Erlang binary term format, writes to `System.tmp_dir!()`, returns path
- `command_byte/1` — maps `:init → 0x01, :display → 0x02, :clear → 0x03, :sleep → 0x04`

### `test/papyrus/mock_port_test.exs`
11 tests covering all acceptance criteria.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed missing :bit_order field in Waveshare12in48 struct**
- **Found during:** Compilation phase (prevented test compilation)
- **Issue:** `DisplaySpec` struct added `:bit_order` to `enforce_keys` in a previous plan, but `Waveshare12in48.spec/0` was not updated to include it
- **Fix:** Added `bit_order: :white_high` (matching the existing bit_order value set by Phase 01 plan 01)
- **Files modified:** `lib/papyrus/displays/waveshare_12in48.ex`
- **Commit:** 9edb5e1

**2. [Rule 1 - Bug] Fixed I/O approach: :file.read/:file.write instead of IO.binread/IO.binwrite**
- **Found during:** Manual testing of mock_port_script.exs
- **Issue:** The plan notes warned that `IO.binread` may not work for raw binary port I/O. After testing, `:file.read/:file.write` on `:standard_io` reliably handles binary frames.
- **Fix:** Used `:file.read(:standard_io, n)` and `:file.write(:standard_io, data)` in the script
- **Files modified:** `test/support/mock_port_script.exs`

**3. [Rule 1 - Bug] Fixed path resolution: compile-time __DIR__ instead of :code.priv_dir**
- **Found during:** Task 1, GREEN phase
- **Issue:** `:code.priv_dir(:papyrus)` resolves to `_build/test/lib/papyrus/priv` at test time, not the source tree
- **Fix:** Used `@project_root Path.expand("../..", __DIR__)` to resolve the project root at compile time from the module's source location (`lib/papyrus/mock_port.ex`)

**4. [Rule 1 - Bug] Fixed port exit test: Port.monitor + :DOWN instead of Port.close + :exit_status**
- **Found during:** Task 1, GREEN phase
- **Issue:** `Port.close/1` does not deliver `:exit_status` messages — it immediately tears down the Erlang port, discarding any pending OS process signals. The test timed out with empty mailbox.
- **Fix:** Used `Port.monitor(port)` before `Port.close(port)` and `assert_receive {:DOWN, ^ref, :port, ^port, :normal}` to verify clean exit

## Known Stubs

None — all behavior is fully implemented and verified.

## Self-Check: PASSED

All key files exist:
- FOUND: lib/papyrus/mock_port.ex
- FOUND: test/support/mock_port_script.exs
- FOUND: test/support/mock_port.sh
- FOUND: test/papyrus/mock_port_test.exs

All commits exist:
- FOUND: 9edb5e1 (test RED phase)
- FOUND: 1dece6a (feat GREEN phase)
