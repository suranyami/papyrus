---
status: awaiting_human_verify
trigger: "Running mix run examples/load_images.exs (and likely hello_papyrus.exs) frequently fails with a 30-second timeout during the C port process init handshake"
created: 2026-04-14T00:00:00Z
updated: 2026-04-14T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED — EPD_M1_ReadBusy() (and siblings) had no timeout guard. During V2 init, EPD_M1_ReadTemperature() → EPD_M1_ReadBusy() spun indefinitely if the BUSY pin stayed high, preventing send_ok("ok") from ever being reached, causing the 30s Elixir timeout.
test: Fix applied — added BUSY_TIMEOUT_MS=25000 deadline to all four ReadBusy functions using clock_gettime(CLOCK_MONOTONIC). On timeout they return -1 with a stderr diagnostic. Error propagated up through EPD_M1_ReadTemperature → EPD_12in48B_Init → epd_port.c which calls send_error() with a descriptive message. Elixir then receives {:error, "..."} instead of timing out.
expecting: On hardware that previously hung, the C port now returns a descriptive error within 25s (before the 30s Elixir timeout fires), giving actionable information. On good hardware, behavior is unchanged.
next_action: User verifies on Raspberry Pi — rebuild C port with mix compile, run examples/load_images.exs

## Symptoms

expected: The C port process initialises successfully within the timeout window and returns an init response
actual: The port process either never sends the init response, or sends it too late, and the Elixir side exits with the timeout error
errors: `** (EXIT from #PID<0.95.0>) "epd_port timed out after 30s waiting for init response"`
reproduction: mix run examples/load_images.exs on a Raspberry Pi with Waveshare ePaper display
started: Happening "quite a bit" — not every time, but frequently enough to be a real problem

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-04-14T00:01:00Z
  checked: lib/papyrus/display.ex init flow
  found: GenServer.init/1 calls Port.open then immediately calls send_command(state, :init) synchronously via collect_response/3 with a hard 30_000ms after timeout. If no data arrives within 30s, the GenServer stops with the exact error message seen.
  implication: The 30s timeout fires in the Elixir receive loop. The question is what the C side is doing for those 30 seconds.

- timestamp: 2026-04-14T00:02:00Z
  checked: c_src/epd_port.c main() startup sequence
  found: On process start, C calls DEV_ModuleInit() FIRST before entering the command loop. DEV_ModuleInit() does a popen("cat /proc/cpuinfo | grep 'Raspberry Pi 5'") subprocess, opens a GPIO chip handle, configures GPIO pins, then returns 0. Only THEN does C enter the for(;;) command-dispatch loop. DEV_ModuleInit() failure sends an error response immediately (before the loop), but ONLY if it fails — on success it sends nothing and waits for commands.
  implication: The normal (success) startup path sends nothing until Elixir sends the CMD_INIT command. This is correct behavior — no race condition on the init command handshake itself.

- timestamp: 2026-04-14T00:03:00Z
  checked: EPD_12in48B_Init() in EPD_12in48b.c, specifically the Version==2 path
  found: Version 2 init sequence ends with EPD_M1_ReadTemperature() which calls EPD_M1_ReadBusy(). EPD_M1_ReadBusy() is a spin-loop: `do { EPD_M1_SendCommand(0x71); busy = DEV_Digital_Read(EPD_M1_BUSY_PIN); busy = !(busy & 0x01); } while(busy);` — NO timeout guard, NO iteration limit, NO sleep between polls. It will spin until the BUSY pin goes low.
  implication: If EPD_M1_BUSY_PIN stays high (display not ready, wiring issue, display still in previous operation, or cold-start condition), this spins indefinitely and EPD_12in48B_Init() never returns, so send_ok("ok") is never called, so Elixir's collect_response times out after 30s.

- timestamp: 2026-04-14T00:04:00Z
  checked: EPD_M1_ReadBusy spin loop — what triggers it to complete normally
  found: The 0x71 command is a "get status" command. The busy pin goes low when the display panel completes its current operation. After EPD_Reset() (which does RST toggle with 200ms delays), the display needs time to fully wake up and become ready. The temperature read command (0x40) is sent first, THEN ReadBusy is called. If the display panel is cold, slow, or was left in a mid-operation state (previous crash/timeout killed the port while display was busy), the BUSY pin could stay high for an extended or indefinite period.
  implication: The busy-wait is the smoking gun. It's intermittent because most of the time the display becomes ready within 30s, but occasionally (cold boot, previous run crashed mid-refresh, environmental factors) it takes longer OR hangs indefinitely.

- timestamp: 2026-04-14T00:05:00Z
  checked: Whether there's any retry logic after the 30s timeout in Elixir
  found: No retry. collect_response/3 on timeout returns {:error, "epd_port timed out after 30s waiting for init response"}, GenServer.init returns {:stop, reason}, which terminates the GenServer. The port is NOT explicitly killed — Port.open created it with :exit_status but not :kill_on_exit, however the port is linked to the GenServer process so it will be terminated when the GenServer stops. There is no supervisor restart configured in the examples.
  implication: One timeout = permanent failure. No retry, no recovery path.

- timestamp: 2026-04-14T00:06:00Z
  checked: EPD_M1_ReadBusy during normal init — what calls it
  found: In Version==2 path, EPD_12in48B_Init() calls EPD_M1_ReadTemperature(), which: (1) sends command 0x40, (2) calls EPD_M1_ReadBusy() which spins waiting for display ready, (3) delays 300ms, (4) reads temperature via SPI. This is the ONLY ReadBusy call during init on V2 hardware. The ReadBusy calls in TurnOnDisplay (EPD_M1/S1/M2/S2_ReadBusy) are for display refresh, not init.
  implication: The timeout is caused by EPD_M1_ReadBusy() spinning without bound during EPD_M1_ReadTemperature() in the V2 init path. Adding a timeout to this loop is the fix.

- timestamp: 2026-04-14T00:07:00Z
  checked: DEV_Delay_us implementation — whether spinning is expensive
  found: DEV_Delay_us is a busy-wait: `while(xus) { for(i = 0; i < software_spi.Clock; i++); xus--; }` with software_spi.Clock = 10. Each EPD_M1_SendCommand call inside the ReadBusy loop does a DEV_SPI_WriteByte which calls DEV_Delay_us(5) + 8 bits × (DEV_Delay_us(10) + DEV_Delay_us(10) + DEV_Delay_us(10)) = DEV_Delay_us(5 + 240) per byte. Plus DEV_Digital_Write calls (lgGpioWrite). So each ReadBusy iteration takes real time (~microseconds to milliseconds), but the loop can still spin for 30+ seconds if busy stays high.
  implication: Confirms this is a genuine hardware-dependent stall, not a software logic error. The fix must add a timeout to the ReadBusy loop.

## Resolution

root_cause: EPD_M1_ReadBusy() (and its siblings M2/S1/S2) spin indefinitely with no timeout guard — a `do { poll BUSY pin } while(busy)` loop with no iteration limit or deadline. During V2 init, EPD_12in48B_Init() calls EPD_M1_ReadTemperature() which calls EPD_M1_ReadBusy(). If the display BUSY pin stays high (cold boot, display left mid-refresh by a prior crash, wiring issue), this loop never terminates. The C process never calls send_ok("ok"), so Elixir's collect_response/3 hits the `after 30_000` clause and returns the timeout error. The error is intermittent because under normal conditions the display becomes ready within seconds, but under stress (first boot, hot restart after an aborted refresh) it can take much longer or hang indefinitely.
fix: Added `#define BUSY_TIMEOUT_MS 25000` and a `clock_gettime(CLOCK_MONOTONIC)` deadline to all four ReadBusy functions. On timeout they print a diagnostic to stderr and return -1. EPD_M1_ReadTemperature, EPD_12in48B_Init, EPD_12in48B_TurnOnDisplay, EPD_12in48B_Clear, and EPD_12in48B_Display all propagate this return code. epd_port.c dispatches to send_error() with an actionable message. The 25s C-side timeout fires before the 30s Elixir-side timeout, so the caller now receives {:error, "EPD_12in48B_Init failed: panel BUSY pin did not clear — check display wiring..."} instead of a generic timeout. Elixir error message for the 30s fallback also improved.
verification: Awaiting hardware test on Raspberry Pi.
files_changed:
  - c_src/waveshare/epd12in48/EPD_12in48b.c
  - c_src/waveshare/epd12in48/EPD_12in48b.h
  - c_src/epd_port.c
  - c_src/Makefile
  - lib/papyrus/display.ex
