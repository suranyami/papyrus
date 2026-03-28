---
phase: 01-displayspec-and-c-port-foundation
plan: 02
subsystem: infra
tags: [c, epd-port, select, stdin, eof-detection, gpio, spi]

# Dependency graph
requires: []
provides:
  - select()-based stdin EOF detection in epd_port.c main loop
  - Guaranteed DEV_ModuleExit() on all exit paths via cleanup label
affects:
  - Phase 2 (multi-display C port dispatch — inherits the hardened main loop)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "select()-before-read pattern: poll stdin for readability before blocking read_exact() to catch EOF during idle waits"
    - "goto cleanup label: single exit path for all error/EOF conditions ensures deterministic resource cleanup"

key-files:
  created: []
  modified:
    - c_src/epd_port.c

key-decisions:
  - "Select in idle loop only (not in busy-pin polling loops) — simplest approach satisfying the 'exits within one timeout cycle' criterion"
  - "EINTR from select treated as fatal (goto cleanup) — avoids infinite retry loops on signal delivery"
  - "Payload read EOF also routes through goto cleanup — consistent cleanup on any stdin close mid-frame"

patterns-established:
  - "select()-before-read: always poll stdin readability before blocking read to enable sub-second zombie detection"

requirements-completed:
  - DRIVER-01

# Metrics
duration: 5min
completed: 2026-03-28
---

# Phase 01 Plan 02: select()-based stdin EOF detection in epd_port.c Summary

**select()-with-1-second-timeout wraps the idle wait before read_exact() so the C port exits within one cycle when the BEAM VM is killed**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-28T03:42:52Z
- **Completed:** 2026-03-28T03:48:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added `#include <sys/select.h>` and `STDIN_POLL_TIMEOUT_SEC 1` constant to epd_port.c
- Replaced direct blocking `read_exact(hdr, 5)` with an inner select() poll loop that re-polls every second until stdin is readable
- Routed all exit paths (select error, header EOF, payload EOF) through a single `cleanup:` label guaranteeing `DEV_ModuleExit()` is called
- Command dispatch switch (CMD_INIT, CMD_DISPLAY, CMD_CLEAR, CMD_SLEEP) left completely unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Add select()-based stdin EOF detection to epd_port.c main loop** - `0bca8f2` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `c_src/epd_port.c` - Added sys/select.h include, STDIN_POLL_TIMEOUT_SEC define, inner select() poll loop before read_exact(), cleanup: label for deterministic exit

## Decisions Made
- Selected "select() in idle loop only" per Claude's Discretion in 01-CONTEXT.md — the simplest approach that satisfies the "exits within one select timeout cycle" criterion without touching the BUSY-pin polling loops
- Treated EINTR from select() as fatal (goto cleanup) rather than retrying — avoids masking unexpected signal conditions during development/testing
- All three exit points (select error, header read failure, payload read failure) use `goto cleanup` for a single guaranteed teardown path

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- epd_port.c is hardened: zombie processes are prevented when BEAM VM dies during an idle wait
- Ready for Phase 2 multi-display dispatch work; the hardened main loop will be the base for any future select() extension if BUSY-pin polling loops need similar treatment

## Self-Check: PASSED
- c_src/epd_port.c: FOUND
- 01-02-SUMMARY.md: FOUND
- commit 0bca8f2: FOUND

---
*Phase: 01-displayspec-and-c-port-foundation*
*Completed: 2026-03-28*
