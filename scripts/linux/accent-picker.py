#!/usr/bin/env python3
"""
accent-picker: macOS-style press-and-hold accent popup for Wayland/Hyprland.

Hold a letter key to show a rofi popup with accent variants.
Select with arrow keys + Enter, or press Escape to cancel.

Requirements: python3-evdev, rofi-wayland, wtype
Permissions: user must be in the 'input' group
"""

import argparse
import asyncio
import json
import signal
import sys

import evdev
from evdev import InputDevice, UInput, ecodes

# ── Accent map (French-focused) ────────────────────────────────────────

ACCENTS = {
    "e": ["é", "è", "ê", "ë"],
    "a": ["à", "â", "æ"],
    "u": ["ù", "û", "ü"],
    "i": ["î", "ï"],
    "o": ["ô", "ö", "œ"],
    "c": ["ç"],
    "y": ["ÿ"],
}

ACCENTS_UPPER = {k: [c.upper() for c in v] for k, v in ACCENTS.items()}

KEY_TO_LETTER = {
    getattr(ecodes, f"KEY_{c.upper()}"): c for c in ACCENTS
}

# ── Rofi theme for horizontal accent strip ──────────────────────────────

ROFI_THEME = (
    "window {{ location: center; anchor: center; "
    "border-radius: 12px; padding: 4px; background-color: #1e1e2e; }} "
    "listview {{ columns: {n}; lines: 1; scrollbar: false; "
    "fixed-columns: true; spacing: 4px; }} "
    "element {{ padding: 10px 18px; border-radius: 8px; "
    "background-color: transparent; text-color: #cdd6f4; }} "
    "element selected {{ background-color: #585b70; text-color: #cdd6f4; }} "
    "element-text {{ font: \"sans 20\"; horizontal-align: 0.5; }} "
    "inputbar {{ enabled: true; padding: 0; margin: 0; "
    "background-color: transparent; children: [entry]; }} "
    "entry {{ enabled: true; text-color: transparent; "
    "cursor-color: transparent; padding: 0; }} "
    "mainbox {{ spacing: 0; children: [inputbar, listview]; }}"
)

# ── Core ────────────────────────────────────────────────────────────────


class AccentPicker:
    def __init__(self, device_path=None, threshold=0.5, apps=None):
        self.threshold = threshold
        self.allowed_apps = [a.lower() for a in (apps or [])]
        self.devices = self._find_devices(device_path)
        self.uinput = UInput.from_device(self.devices[0], name="accent-picker-vkbd")
        self.held_key = None
        self.hold_task = None
        self.shift = False
        self.picker_active = False

    def _find_devices(self, path):
        if path:
            d = InputDevice(path)
            print(f"Using: {d.name} ({d.path})")
            return [d]
        found = []
        for p in evdev.list_devices():
            d = InputDevice(p)
            # Skip our own virtual keyboard
            if d.name == "accent-picker-vkbd":
                continue
            caps = d.capabilities(verbose=False).get(ecodes.EV_KEY, [])
            if all(
                getattr(ecodes, f"KEY_{c}") in caps for c in "AEZQWM"
            ):
                print(f"Found keyboard: {d.name} ({d.path})")
                found.append(d)
        if not found:
            print("No keyboard found. Available devices:", file=sys.stderr)
            for p in evdev.list_devices():
                d = InputDevice(p)
                print(f"  {d.path}: {d.name}", file=sys.stderr)
            sys.exit(1)
        return found

    async def _check_app(self):
        """Check if focused app is in the allowed list."""
        if not self.allowed_apps:
            return True
        try:
            proc = await asyncio.create_subprocess_exec(
                "hyprctl", "activewindow", "-j",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await proc.communicate()
            cls = json.loads(stdout.decode()).get("class", "").lower()
            return any(a in cls for a in self.allowed_apps)
        except Exception:
            return False

    async def _on_hold(self, key_code):
        """Wait for hold threshold, then show the accent picker."""
        await asyncio.sleep(self.threshold)

        # Check per-app filter (async, only when we actually need the picker)
        if not await self._check_app():
            self.hold_task = None
            return

        letter = KEY_TO_LETTER[key_code]
        accents = ACCENTS_UPPER[letter] if self.shift else ACCENTS[letter]
        self.picker_active = True

        # Release the key and delete the character we already typed
        self.uinput.write(ecodes.EV_KEY, key_code, 0)
        self.uinput.syn()
        await asyncio.sleep(0.01)

        # If shift was held, release it before sending backspace
        if self.shift:
            self.uinput.write(ecodes.EV_KEY, ecodes.KEY_LEFTSHIFT, 0)
            self.uinput.syn()
            await asyncio.sleep(0.01)

        self.uinput.write(ecodes.EV_KEY, ecodes.KEY_BACKSPACE, 1)
        self.uinput.write(ecodes.EV_KEY, ecodes.KEY_BACKSPACE, 0)
        self.uinput.syn()
        await asyncio.sleep(0.03)

        # Re-press shift if it was held (so state stays consistent)
        if self.shift:
            self.uinput.write(ecodes.EV_KEY, ecodes.KEY_LEFTSHIFT, 1)
            self.uinput.syn()

        # Show rofi with numbered entries — typing a number auto-selects
        theme = ROFI_THEME.format(n=len(accents))
        labeled = [f"{i + 1}  {c}" for i, c in enumerate(accents)]

        proc = await asyncio.create_subprocess_exec(
            "rofi", "-dmenu", "-p", "",
            "-theme-str", theme, "-selected-row", "0",
            "-auto-select",
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        stdout, _ = await proc.communicate("\n".join(labeled).encode())
        exit_code = proc.returncode

        self.picker_active = False
        await asyncio.sleep(0.05)

        selected = None
        if exit_code == 0:
            raw = stdout.decode().strip()
            # Extract the accent character after the number prefix
            for c in accents:
                if c in raw:
                    selected = c
                    break

        char = selected if selected else (
            letter.upper() if self.shift else letter
        )
        await self._type_char(char)

    async def _type_char(self, char):
        """Type a character via clipboard paste (works in Flatpak/Electron)."""
        # Save current clipboard
        save = await asyncio.create_subprocess_exec(
            "wl-paste", "-n",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        old_clip, _ = await save.communicate()

        # Copy accent to clipboard and paste it
        copy = await asyncio.create_subprocess_exec(
            "wl-copy", "--", char,
        )
        await copy.wait()
        await (await asyncio.create_subprocess_exec(
            "wtype", "-M", "ctrl", "v", "-m", "ctrl",
        )).wait()

        # Restore previous clipboard
        await asyncio.sleep(0.05)
        restore = await asyncio.create_subprocess_exec(
            "wl-copy", "--",
            stdin=asyncio.subprocess.PIPE,
        )
        await restore.communicate(old_clip)

    def _forward(self, event):
        self.uinput.write_event(event)
        self.uinput.syn()

    async def _handle_device(self, dev):
        """Read events from one keyboard device."""
        async for event in dev.async_read_loop():
            if event.type != ecodes.EV_KEY:
                self._forward(event)
                continue

            code, value = event.code, event.value

            # Track shift
            if code in (ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT):
                self.shift = value > 0
                if not self.picker_active:
                    self._forward(event)
                continue

            # Accent-capable key (not during picker)
            if code in KEY_TO_LETTER and not self.picker_active:
                if value == 1:  # press
                    self.held_key = code
                    self._forward(event)
                    if self.hold_task:
                        self.hold_task.cancel()
                    self.hold_task = asyncio.create_task(
                        self._on_hold(code)
                    )

                elif value == 0:  # release
                    if self.hold_task:
                        self.hold_task.cancel()
                        self.hold_task = None
                    self._forward(event)
                    self.held_key = None

                elif value == 2:  # repeat
                    if self.hold_task is None:
                        self._forward(event)
                    # suppress repeats while hold timer is running

                continue

            # During picker: swallow the held key's release
            if self.picker_active and code == self.held_key:
                if value == 0:
                    self.held_key = None
                continue

            # Everything else: pass through
            self._forward(event)

    async def run(self):
        for dev in self.devices:
            dev.grab()
        print(f"Accent picker active (hold: {self.threshold}s, "
              f"apps: {', '.join(self.allowed_apps) or 'all'}, "
              f"devices: {len(self.devices)})")

        try:
            await asyncio.gather(
                *(self._handle_device(dev) for dev in self.devices)
            )
        finally:
            for dev in self.devices:
                try:
                    dev.ungrab()
                except Exception:
                    pass
            print("Keyboard released.")


def main():
    parser = argparse.ArgumentParser(
        description="macOS-style press-and-hold accent picker for Wayland"
    )
    parser.add_argument(
        "-d", "--device", help="Keyboard device path (auto-detected if omitted)"
    )
    parser.add_argument(
        "-t", "--threshold", type=float, default=0.5,
        help="Hold time in seconds before showing picker (default: 0.5)",
    )
    parser.add_argument(
        "-a", "--apps", nargs="*",
        help="Window classes to enable for (default: all apps)",
    )
    args = parser.parse_args()

    picker = AccentPicker(args.device, args.threshold, args.apps)

    loop = asyncio.new_event_loop()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, loop.stop)

    try:
        loop.run_until_complete(picker.run())
    except (KeyboardInterrupt, asyncio.CancelledError, RuntimeError):
        pass
    finally:
        # Cancel any pending tasks silently
        for task in asyncio.all_tasks(loop):
            task.cancel()
        loop.run_until_complete(loop.shutdown_asyncgens())
        loop.close()


if __name__ == "__main__":
    main()
