#!/usr/bin/env python3
"""
accent-picker: macOS-style press-and-hold accent popup for Wayland/Hyprland.

Hold a letter key to show a rofi popup with accent variants.
Select with arrow keys + Enter, number key, or press Escape to cancel.

Requirements: python3-evdev, rofi-wayland, wtype, wl-clipboard
Permissions: user must be in the 'input' group
"""

import argparse
import asyncio
import json
import signal
import sys

import evdev
import pyudev
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

# Apps where hold-for-accent is disabled (terminals, editors, etc.)
DEFAULT_EXCLUDED = [
    "ghostty",
    "kitty",
    "alacritty",
    "foot",
    "wezterm",
    "cursor",
    "code",
    "codium",
    "neovide",
    "emacs",
]

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

VKBD_NAME = "accent-picker-vkbd"

# ── Core ────────────────────────────────────────────────────────────────


def is_keyboard(dev):
    """Check if an evdev device is a real keyboard (has common letter keys)."""
    if dev.name == VKBD_NAME:
        return False
    caps = dev.capabilities(verbose=False).get(ecodes.EV_KEY, [])
    return all(getattr(ecodes, f"KEY_{c}") in caps for c in "AEZQWM")


class AccentPicker:
    def __init__(self, threshold=0.3, excluded=None):
        self.threshold = threshold
        self.excluded_apps = [a.lower() for a in (excluded or DEFAULT_EXCLUDED)]
        self.devices = {}  # path -> InputDevice
        self.uinput = None
        self.held_key = None
        self.hold_task = None
        self.shift = False
        self.picker_active = False
        self._running = True

    def _scan_keyboards(self):
        """Find all keyboard devices not yet grabbed."""
        new = []
        for p in evdev.list_devices():
            if p in self.devices:
                continue
            try:
                d = InputDevice(p)
                if is_keyboard(d):
                    new.append(d)
            except Exception:
                continue
        return new

    def _ensure_uinput(self, dev):
        """Create virtual keyboard from the first real device found."""
        if self.uinput is None:
            self.uinput = UInput.from_device(dev, name=VKBD_NAME)

    async def _check_app(self):
        """Check if focused app is excluded."""
        if not self.excluded_apps:
            return True
        try:
            proc = await asyncio.create_subprocess_exec(
                "hyprctl", "activewindow", "-j",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL,
            )
            stdout, _ = await proc.communicate()
            cls = json.loads(stdout.decode()).get("class", "").lower()
            return not any(a in cls for a in self.excluded_apps)
        except Exception:
            return True

    async def _on_hold(self, key_code):
        """Wait for hold threshold, then show the accent picker."""
        await asyncio.sleep(self.threshold)

        if not await self._check_app():
            self.hold_task = None
            return

        letter = KEY_TO_LETTER[key_code]
        accents = ACCENTS_UPPER[letter] if self.shift else ACCENTS[letter]
        self.picker_active = True

        # Delete the single character we typed (key already released on press)
        self.uinput.write(ecodes.EV_KEY, ecodes.KEY_BACKSPACE, 1)
        self.uinput.write(ecodes.EV_KEY, ecodes.KEY_BACKSPACE, 0)
        self.uinput.syn()
        await asyncio.sleep(0.03)

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
        try:
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
                        # Immediately release to prevent compositor repeats
                        # (character is typed on press, release just stops repeat)
                        self.uinput.write(ecodes.EV_KEY, code, 0)
                        self.uinput.syn()
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

        except OSError:
            # Device disconnected
            print(f"Device disconnected: {dev.name} ({dev.path})")
        finally:
            self.devices.pop(dev.path, None)
            try:
                dev.ungrab()
            except Exception:
                pass

    async def _hotplug_monitor(self):
        """Watch udev events for new keyboard devices."""
        context = pyudev.Context()
        monitor = pyudev.Monitor.from_netlink(context)
        monitor.filter_by(subsystem="input")
        monitor.start()
        fd = monitor.fileno()
        loop = asyncio.get_event_loop()
        event = asyncio.Event()
        loop.add_reader(fd, event.set)

        try:
            while self._running:
                await event.wait()
                event.clear()
                for action, device in iter(monitor.poll, None):
                    if action != "add" or device.device_node is None:
                        continue
                    if not device.device_node.startswith("/dev/input/event"):
                        continue
                    # Small delay for device to settle
                    await asyncio.sleep(0.5)
                    for dev in self._scan_keyboards():
                        try:
                            self._ensure_uinput(dev)
                            dev.grab()
                            self.devices[dev.path] = dev
                            print(f"Hotplug: grabbed {dev.name} ({dev.path})")
                            asyncio.create_task(self._handle_device(dev))
                        except Exception as e:
                            print(f"Hotplug: failed to grab {dev.name}: {e}")
                    break  # processed pending events, wait for next
        finally:
            loop.remove_reader(fd)

    async def run(self):
        # Initial scan
        for dev in self._scan_keyboards():
            self._ensure_uinput(dev)
            dev.grab()
            self.devices[dev.path] = dev
            print(f"Grabbed: {dev.name} ({dev.path})")

        if not self.devices:
            print("No keyboard found. Available devices:", file=sys.stderr)
            for p in evdev.list_devices():
                d = InputDevice(p)
                print(f"  {d.path}: {d.name}", file=sys.stderr)
            sys.exit(1)

        excl = ", ".join(self.excluded_apps[:5])
        if len(self.excluded_apps) > 5:
            excl += f" +{len(self.excluded_apps) - 5} more"
        print(f"Accent picker active (hold: {self.threshold}s, "
              f"excluded: {excl}, devices: {len(self.devices)})")

        try:
            await asyncio.gather(
                self._hotplug_monitor(),
                *(self._handle_device(dev) for dev in list(self.devices.values()))
            )
        finally:
            self._running = False
            for dev in list(self.devices.values()):
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
        "-t", "--threshold", type=float, default=0.3,
        help="Hold time in seconds before showing picker (default: 0.3)",
    )
    parser.add_argument(
        "-e", "--exclude", nargs="*",
        help=f"Window classes to disable for (default: {', '.join(DEFAULT_EXCLUDED[:5])}...)",
    )
    parser.add_argument(
        "--no-exclude", action="store_true",
        help="Disable the default exclusion list (enable for all apps)",
    )
    args = parser.parse_args()

    excluded = [] if args.no_exclude else (args.exclude or DEFAULT_EXCLUDED)
    picker = AccentPicker(args.threshold, excluded)

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
