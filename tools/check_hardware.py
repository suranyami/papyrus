#!/usr/bin/env python3
"""
Papyrus hardware diagnostic for Waveshare 12.48" B (three-color ePaper).

Checks each hardware layer independently — no Elixir, no compiled C port needed.
Run this first when the display is misbehaving to isolate where the problem is.

Usage:
    python3 tools/check_hardware.py           # read-only checks
    python3 tools/check_hardware.py --reset   # also pulse RST lines to wake a stuck display

Requirements:
    sudo apt install python3-lgpio          # preferred (Raspberry Pi OS Bookworm+)
    # or: python3 -m venv venv --system-site-packages && source venv/bin/activate && pip install lgpio
"""

import sys
import time
import argparse

# ---------------------------------------------------------------------------
# Pin assignments (must match DEV_Config.h)
# ---------------------------------------------------------------------------

PINS = {
    "SCK":      11,
    "MOSI":     10,
    "M1_CS":     8,
    "S1_CS":     7,
    "M2_CS":    17,
    "S2_CS":    18,
    "M1S1_DC":  13,
    "M2S2_DC":  22,
    "M1S1_RST":  6,
    "M2S2_RST": 23,
    "M1_BUSY":   5,
    "S1_BUSY":  19,
    "M2_BUSY":  27,
    "S2_BUSY":  24,
}

BUSY_PINS  = ["M1_BUSY", "S1_BUSY", "M2_BUSY", "S2_BUSY"]
RST_PINS   = ["M1S1_RST", "M2S2_RST"]
CS_PINS    = ["M1_CS", "S1_CS", "M2_CS", "S2_CS"]
DC_PINS    = ["M1S1_DC", "M2S2_DC"]
OUTPUT_PINS = ["SCK", "MOSI"] + CS_PINS + DC_PINS + RST_PINS

OK   = "\033[32m✓\033[0m"
FAIL = "\033[31m✗\033[0m"
WARN = "\033[33m!\033[0m"
INFO = "\033[36m·\033[0m"

def section(title):
    print(f"\n── {title} {'─' * (50 - len(title))}")

def check(label, ok, detail=""):
    icon = OK if ok else FAIL
    suffix = f"  ({detail})" if detail else ""
    print(f"  {icon}  {label}{suffix}")
    return ok

# ---------------------------------------------------------------------------
# Step 1 — Python dependencies
# ---------------------------------------------------------------------------

def check_dependencies():
    section("Dependencies")
    try:
        import lgpio
        check("lgpio installed", True, f"module at {lgpio.__file__}")
        return lgpio
    except ImportError:
        check("lgpio installed", False, "run: pip install lgpio")
        return None

# ---------------------------------------------------------------------------
# Step 2 — gpiochip access
# ---------------------------------------------------------------------------

def open_gpio(lgpio):
    section("GPIO chip")
    # Pi 5 uses gpiochip4, earlier Pis use gpiochip0
    for chip in (4, 0):
        h = lgpio.gpiochip_open(chip)
        if h >= 0:
            check(f"gpiochip{chip} opened", True)
            return h, chip
        else:
            check(f"gpiochip{chip} opened", False, f"error {h}")

    print(f"\n  {FAIL}  Could not open any GPIO chip.")
    print("       Check: are you running as root or in the 'gpio' group?")
    print("       Try:   sudo python3 tools/check_hardware.py")
    return None, None

# ---------------------------------------------------------------------------
# Step 3 — Claim output pins and read BUSY pins
# ---------------------------------------------------------------------------

def check_pins(lgpio, h):
    section("Output pins (claim as output)")
    all_ok = True
    for name in OUTPUT_PINS:
        pin = PINS[name]
        # CS pins idle HIGH (deselected); all other output pins start LOW
        initial_value = 1 if name in CS_PINS else 0
        rc = lgpio.gpio_claim_output(h, 0, pin, initial_value)
        ok = rc == 0
        check(f"GPIO {pin:2d}  {name}", ok, f"rc={rc}" if not ok else "")
        all_ok = all_ok and ok

    section("BUSY pins (read state — LOW = ready, HIGH = busy)")
    busy_states = {}
    for name in BUSY_PINS:
        pin = PINS[name]
        lgpio.gpio_claim_input(h, 0, pin)
        val = lgpio.gpio_read(h, pin)
        state = "BUSY (HIGH)" if val else "ready (LOW)"
        ok = val == 0
        check(f"GPIO {pin:2d}  {name}", ok, state)
        busy_states[name] = val

    stuck = [n for n, v in busy_states.items() if v != 0]
    if stuck:
        print(f"\n  {WARN}  {len(stuck)} panel(s) showing BUSY: {', '.join(stuck)}")
        print("       This means the panel did not finish its last refresh.")
        print("       Run with --reset to pulse RST and try to clear it.")
    else:
        print(f"\n  {OK}  All panels ready.")

    # Check CS pins for stuck-LOW (panel locked in selected state).
    # These are already claimed as outputs above — read directly, no re-claim needed.
    section("CS pins (should be HIGH = deselected when idle)")
    for name in CS_PINS:
        pin = PINS[name]
        # Drive HIGH (idle/deselected), then read back to confirm
        lgpio.gpio_write(h, pin, 1)
        val = lgpio.gpio_read(h, pin)
        state = "HIGH (idle)" if val else "LOW — stuck selected!"
        check(f"GPIO {pin:2d}  {name}", val == 1, state)

    return all_ok, busy_states

# ---------------------------------------------------------------------------
# Step 4 — Optional RST pulse (wakes a display stuck mid-refresh)
# ---------------------------------------------------------------------------

def reset_display(lgpio, h):
    section("RST pulse (hardware reset)")
    for name in RST_PINS:
        pin = PINS[name]
        lgpio.gpio_write(h, pin, 0)
    print(f"  {INFO}  RST lines LOW — holding 200ms...")
    time.sleep(0.2)
    for name in RST_PINS:
        pin = PINS[name]
        lgpio.gpio_write(h, pin, 1)
    print(f"  {INFO}  RST lines HIGH — waiting 2s for panels to boot...")
    time.sleep(2.0)

    # Re-read BUSY
    print()
    for name in BUSY_PINS:
        pin = PINS[name]
        val = lgpio.gpio_read(h, pin)
        state = "BUSY (HIGH)" if val else "ready (LOW)"
        check(f"GPIO {pin:2d}  {name} after reset", val == 0, state)

# ---------------------------------------------------------------------------
# Step 5 — Software SPI loopback (SCK/MOSI toggling)
# ---------------------------------------------------------------------------

def check_spi_bit_bang(lgpio, h):
    section("Software SPI bit-bang (toggle SCK + MOSI)")
    sck  = PINS["SCK"]
    mosi = PINS["MOSI"]

    errors = 0
    for bit in [0, 1, 0, 1]:
        lgpio.gpio_write(h, sck,  0)
        lgpio.gpio_write(h, mosi, bit)
        time.sleep(0.001)
        lgpio.gpio_write(h, sck,  1)
        time.sleep(0.001)
        lgpio.gpio_write(h, sck,  0)

    check("SCK/MOSI toggles without error", errors == 0)
    print(f"  {INFO}  Note: without a loopback wire you can't confirm the signal reaches")
    print( "         the display — use an oscilloscope or logic analyser to verify.")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

def summary(busy_states, do_reset):
    section("Summary")
    stuck = [n for n, v in busy_states.items() if v != 0]
    if not stuck:
        print(f"  {OK}  Hardware looks healthy. If Elixir still times out:")
        print("       1. Recompile the C port:  mix deps.compile --force")
        print("       2. Check for a previous crashed run holding the GPIO chip")
        print("          (lsof | grep gpiochip  or  fuser /dev/gpiochip0)")
        print("       3. Try a power cycle — power-cycle the display, not just the Pi")
    else:
        if do_reset:
            still_stuck = stuck  # already post-reset
            if still_stuck:
                print(f"\n  {FAIL}  {', '.join(still_stuck)} still BUSY after RST pulse.")
                _print_physical_guidance(still_stuck)
            else:
                print(f"\n  {OK}  All panels ready after reset.")
        else:
            print(f"  {FAIL}  Panels are stuck BUSY: {', '.join(stuck)}")
            print("       Run again with --reset to send a hardware reset pulse.")
            print("       If that doesn't help: power-cycle the display.")

def _print_physical_guidance(stuck):
    # Map BUSY pin names to their panel's physical location and ribbon cable
    panel_info = {
        "M1_BUSY": ("M1", "left-half master",  "M1S1_RST (GPIO  6)", "M1_CS  (GPIO  8)"),
        "S1_BUSY": ("S1", "left-half slave",   "M1S1_RST (GPIO  6)", "S1_CS  (GPIO  7)"),
        "M2_BUSY": ("M2", "right-half master", "M2S2_RST (GPIO 23)", "M2_CS  (GPIO 17)"),
        "S2_BUSY": ("S2", "right-half slave",  "M2S2_RST (GPIO 23)", "S2_CS  (GPIO 18)"),
    }
    for name in stuck:
        panel, location, rst, cs = panel_info[name]
        print(f"\n  Panel {panel} ({location}) — BUSY pin stuck HIGH after RST:")
        print(f"    RST shared with: {rst}")
        print(f"    CS pin:          {cs}")
        print( "    Physical checks:")
        print(f"    1. Reseat the ribbon cable connecting to the {panel} board")
        print(f"       (slaves connect to their master via a short FPC ribbon)")
        print(f"    2. Check {panel} board power — feel for warmth, look for damage")
        print(f"    3. Check CS pin above — if LOW, the panel is stuck selected")
        print( "    4. Power-cycle the entire display (cut 5V, wait 10s, restore)")

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Papyrus hardware diagnostic")
    parser.add_argument("--reset", action="store_true",
                        help="Pulse RST lines to wake a display stuck mid-refresh")
    args = parser.parse_args()

    print("Papyrus Hardware Diagnostic — Waveshare 12.48\" B")
    print("=" * 52)

    lgpio = check_dependencies()
    if lgpio is None:
        sys.exit(1)

    h, chip = open_gpio(lgpio)
    if h is None:
        sys.exit(1)

    try:
        pins_ok, busy_states = check_pins(lgpio, h)

        if args.reset:
            reset_display(lgpio, h)

        check_spi_bit_bang(lgpio, h)
        summary(busy_states, args.reset)

    finally:
        lgpio.gpiochip_close(h)
        print(f"\n  {INFO}  GPIO chip closed cleanly.\n")

if __name__ == "__main__":
    main()
