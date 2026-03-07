# Logitech G915 TKL LED Control on Linux

Hard-won knowledge from reverse-engineering HID++ communication on Fedora.

## Hardware

- **Keyboard**: Logitech G915 TKL LIGHTSPEED Wireless RGB Mechanical Gaming
- **Mouse**: Logitech G PRO X Superlight (separate Lightspeed receiver)
- **USB PIDs**:
  - `0xC343` = G915 TKL (wired PID — appears even when in wireless mode via USB cable)
  - `0xC547` = Lightspeed USB Receiver (shared PID for multiple receiver types)
  - `0xC33E` = G915 full-size wired (NOT TKL)
  - `0xC545` = G915 TKL wireless-only PID (via receiver, no USB cable)

## USB Interface Layout

The G915 TKL connected via micro USB cable exposes **3 HID interfaces**:

| Interface | Protocol | Purpose | hidraw writes |
|-----------|----------|---------|---------------|
| input0 | Keyboard (1) | Standard key input | BrokenPipeError (no output reports in descriptor) |
| input1 | Mouse (2) | Media keys / DJ | BrokenPipeError (no output reports in descriptor) |
| input2 | None (0) | **HID++ control (LED, features)** | **Works!** (descriptor includes output reports) |

**Critical**: Interface 2 (input2) is the ONLY interface that accepts HID++ writes.
The BrokenPipeError on input0/1 is NOT caused by the driver — it's because those USB
interfaces' HID report descriptors don't define output reports. Input2's descriptor does.

## The Driver Situation

### logitech-hidpp-device
- Binds to input0 and input1 automatically
- Also works on input2 — **does NOT block writes** (previous assumption was wrong)
- BrokenPipeError on input0/input1 is from the USB HID report descriptor, not the driver
- Use this driver on input2 for LED control

### The "Missing input2" Problem
After driver unbind/rebind cycles, input2's HID device (`0003:046D:C343.00BB`) can end up
with **no driver bound at all**. When this happens:
- No hidraw is created for input2
- The device exists in `/sys/bus/hid/devices/` but has no `driver` symlink
- Fix: `echo "0003:046D:C343.00BB" > /sys/bus/hid/drivers/logitech-hidpp-device/bind`
- The `.00BB` suffix increments across unbind/rebind cycles (00BB, 00BC, etc.)

### Diagnosing
```bash
# Check all 3 interfaces
for iface in /sys/bus/usb/devices/5-2.3:1.*/; do
    echo "=== $(basename $iface) ==="
    cat "$iface/bInterfaceNumber"
    ls "$iface" | grep "^0003:"
    [ -L "$iface/driver" ] && readlink "$iface/driver" | xargs basename || echo "NO DRIVER"
done

# Check HID device for input2
ls /sys/bus/hid/devices/ | grep C343
# Look for the one with input2 in uevent
cat /sys/bus/hid/devices/0003:046D:C343.*/uevent | grep input2
```

## HID++ Protocol (G915 TKL Wired)

### Basics
- **Device index**: `0xFF` for wired USB, `0x01` for wireless via receiver
- **Report ID**: `0x11` = long report (20 bytes), `0x10` = short report (7 bytes)
- **Packet format**: `[report_id, dev_index, feature_index, function|sw_id, params...]`

### Feature Discovery
Features are at different indices on every device. Discover at runtime:
```
IRoot (feature 0x0000) is always at index 0x00.
getFeature: [0x11, dev_idx, 0x00, 0x0D, feat_hi, feat_lo, 0x00, ...]
Response:   [0x11, dev_idx, 0x00, 0x0D, feat_index, ...]
feat_index=0 means not found.
```

### Known Feature Indices (wired, may vary)
| Feature ID | Typical Index | Name |
|-----------|--------------|------|
| 0x4522 | 0x0E | DisableKeysByUsage (used for mode init) |
| 0x8071 | 0x09 | Color LED Effects |
| 0x8081 | 0x0A | Per Key Lighting V2 |

### Mode Setting Protocol (confirmed working)
```
1. BeginModeSet:     [0x11, 0xFF, F_4522, 0x3E]
                     [0x11, 0xFF, F_4522, 0x1E]
2. InitializeModeSet:[0x11, 0xFF, F_8071, 0x5E, 0x01, 0x03, 0x07]
3. SendMode:         [0x11, 0xFF, F_8071, 0x1E, zone, mode, R, G, B, ...]
```

### Zones
- `0x00` = Logo
- `0x01` = Keyboard

### Modes
| Mode | Keyboard | Logo |
|------|----------|------|
| Off | 0x00 | 0x00 |
| Static | 0x01 | 0x01 |
| Breathing | 0x02 | 0x03 |
| Cycle | 0x03 | 0x02 |
| Wave | 0x04 | — |
| Ripple | 0x05 | — |

### Per-Key (Direct) Mode Protocol (confirmed working)
```
1. Initialize:  BeginModeSet sequence (same as above)
                [0x11, 0xFF, F_8071, 0x1E, 0x00*12, 0x01]
                [0x11, 0xFF, F_8071, 0x1E, 0x01, 0x00*11, 0x01]
2. Send frames: [0x11, 0xFF, F_8081, FRAME_LITTLE, key_code, R, G, B, ...]
3. Commit:      [0x11, 0xFF, F_8081, 0x7F]
```

Frame types: `0x1F` = little (up to 4 keys), `0x6F` = big (up to 13 keys)

### Key Code Mapping

Standard keys use **HID usage code minus 3** as their firmware LED code:
- `a` = 0x01 (HID 0x04 - 3), `b` = 0x02, ... `z` = 0x1A
- `1` = 0x1B, `2` = 0x1C, ... `0` = 0x24
- `enter` = 0x25, `esc` = 0x26, `backspace` = 0x27, `tab` = 0x28, `space` = 0x29
- F-keys: `f1` = 0x37, ... `f12` = 0x42
- Nav: `insert` = 0x46, `home` = 0x47, `pageup` = 0x48, `delete` = 0x49, `end` = 0x4A, `pagedown` = 0x4B
- Arrows: `right` = 0x4C, `left` = 0x4D, `down` = 0x4E, `up` = 0x4F

Modifier keys use **custom firmware codes** (0x62-0x6F), completely unrelated to HID modifier codes (0xE0-0xE7):
| Code | Key |
|------|-----|
| 0x62 | Context menu |
| 0x68 | Left Ctrl |
| 0x69 | Left Shift |
| 0x6A | Left Alt |
| 0x6B | Left Win/Super |
| 0x6C | Right Ctrl |
| 0x6D | Right Shift |
| 0x6E | Right Alt |
| 0x6F | Fn |

Codes 0x61, 0x63-0x67 exist in the firmware bitmap but don't visibly map to any key on TKL (may be full-size or numpad keys).

### HID++ Error Codes
| Code | HID++ 2.0 | HID++ 1.0 (receiver) |
|------|-----------|---------------------|
| 0x01 | Unknown | Unknown |
| 0x02 | Invalid argument | Invalid sub_id |
| 0x08 | Busy | Busy |
| 0x09 | Unsupported | Unknown device |

Error response format: `[report_id, dev_idx, 0x8F, feat_idx, fn|sw, error_code, 0x00]`

## Lightspeed Receiver vs Direct USB

### Direct USB (what works)
- Keyboard at its own USB port (e.g., `5-2.3`)
- Use input2 with logitech-hidpp-device driver
- Device index = `0xFF`
- No receiver involved

### Via Lightspeed Receiver (problematic)
- Receiver (C547) at a different USB port
- Should use receiver's input2 with device index `0x01`
- Returns "busy" (0x08) error — likely because `logitech-hidpp-device` on the
  keyboard's USB interfaces (input0/1) holds a lock or interferes
- Even unbinding C343 from logitech-hidpp-device doesn't fix the "busy" error
- **Avoid this path** — use direct USB instead

## Tools Tested

| Tool | Works? | Notes |
|------|--------|-------|
| OpenRGB GUI | Partial | Static mode only (single color). Direct mode broken |
| OpenRGB CLI | No | Same limitations as GUI |
| Solaar | No | Can see device but LED control doesn't work |
| Piper | N/A | Mouse only |
| ratbagctl | No | Caches locally, never writes to hardware |
| g915-led (this script) | Yes | Direct HID++ to input2 via logitech-hidpp-device |

## Key Lessons

1. **input2 is the magic interface**: Only interface whose HID report descriptor includes output reports
2. **The driver doesn't block writes**: BrokenPipeError on input0/1 is from USB HID descriptors, not the driver
3. **logitech-hidpp-device works on input2**: Bind it to create a writable hidraw
4. **hid-generic CANNOT bind to C343**: Returns ENODEV — use logitech-hidpp-device instead
5. **input2 can lose its driver**: After unbind/rebind cycles, it ends up driverless
6. **Feature indices are NOT fixed**: Must discover at runtime via IRoot.getFeature
7. **Don't use the Lightspeed receiver path**: Direct USB works, receiver returns "busy"
8. **hidraw numbers change**: After driver cycles, hidraw devices get renumbered
9. **HID device suffixes increment**: `.00B8` → `.00B9` → `.00BA` etc. across unbind/rebind
10. **setSWControl doesn't work on wired**: Returns invalid_argument. Use BeginModeSet instead
11. **Key codes ≠ HID codes**: Firmware LED codes = HID usage - 3 for standard keys; modifiers use custom 0x62-0x6F range
12. **BrokenPipeError = no output reports in descriptor**: Not a driver issue — those interfaces simply can't accept writes
