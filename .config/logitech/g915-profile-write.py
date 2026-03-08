#!/usr/bin/env python3
"""Write lighting config to G915 TKL onboard profile (flash memory).

Sets all 3 profile slots (M1/M2/M3) to:
  - Zone 0 (Logo): static FFFF33 (electric yellow)
  - Zone 1 (Keyboard): static 0000FF (blue)

This survives power cycles, KVM drops, and suspend/resume.
"""
import glob
import os
import sys
import time

VENDOR = "046D"
PIDS = {"C343", "C545", "C33E"}
SECTOR_SIZE = 255


def send_recv(fd, pkt):
    buf = bytes(pkt) + bytes(20 - len(pkt))
    os.write(fd, buf)
    time.sleep(0.08)
    resps = []
    while True:
        try:
            resp = os.read(fd, 64)
            resps.append(resp)
        except BlockingIOError:
            break
    return resps


def find_device():
    for path in sorted(glob.glob("/sys/class/hidraw/hidraw*/device/uevent")):
        with open(path) as f:
            content = f.read()
        if VENDOR not in content or not any(pid in content for pid in PIDS):
            continue
        dev = "/dev/" + path.split("/")[4]
        try:
            fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
        except (PermissionError, OSError):
            continue
        for di in (0xFF, 0x01):
            pkt = [0x11, di, 0x00, 0x0D, 0x81, 0x00, 0x00]
            try:
                os.write(fd, bytes(pkt) + bytes(13))
            except (BrokenPipeError, OSError):
                continue
            time.sleep(0.1)
            while True:
                try:
                    resp = os.read(fd, 64)
                    if len(resp) >= 5 and resp[2] == 0x00 and (resp[3] & 0x0F) == 0x0D and resp[4] > 0:
                        return fd, di, resp[4]
                except BlockingIOError:
                    break
        os.close(fd)
    return None, None, None


def crc_ccitt(data):
    crc = 0xFFFF
    for byte in data:
        temp = (crc >> 8) ^ byte
        crc = (crc << 8) & 0xFFFF
        quick = temp ^ (temp >> 4)
        crc ^= quick
        quick = (quick << 5) & 0xFFFF
        crc ^= quick
        quick = (quick << 7) & 0xFFFF
        crc ^= quick
    return crc


def read_sector(fd, di, feat, sector):
    data = bytearray(SECTOR_SIZE)
    offset = 0
    while offset < SECTOR_SIZE:
        if SECTOR_SIZE - offset < 16:
            offset = SECTOR_SIZE - 16
        s_hi = (sector >> 8) & 0xFF
        s_lo = sector & 0xFF
        o_hi = (offset >> 8) & 0xFF
        o_lo = offset & 0xFF
        resps = send_recv(fd, [0x11, di, feat, 0x5D, s_hi, s_lo, o_hi, o_lo])
        for resp in resps:
            if len(resp) >= 20 and resp[2] == feat and (resp[3] & 0xF0) == 0x50:
                end = min(offset + 16, SECTOR_SIZE)
                data[offset:end] = resp[4:4 + (end - offset)]
                break
        offset += 16
    return data


def write_sector(fd, di, feat, sector, data):
    s_hi = (sector >> 8) & 0xFF
    s_lo = sector & 0xFF
    send_recv(fd, [0x11, di, feat, 0x6D, s_hi, s_lo, 0x00, 0x00, 0x00, 0xFF])
    padded = bytearray(data) + bytearray(1)
    for i in range(0, 256, 16):
        send_recv(fd, [0x11, di, feat, 0x7D] + list(padded[i:i + 16]))
    resps = send_recv(fd, [0x11, di, feat, 0x8D])
    for resp in resps:
        if len(resp) >= 4 and resp[2] == 0xFF:
            return False
    return True


def main():
    fd, di, feat_8100 = find_device()
    if fd is None:
        print("Error: G915 TKL not found.", file=sys.stderr)
        sys.exit(1)
    print(f"Found device (di=0x{di:02X}, 0x8100 at index 0x{feat_8100:02X})")

    # LED effects: static yellow logo, static blue keyboard
    logo_effect = bytearray([0x01, 0xFF, 0xFF, 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    kb_effect = bytearray([0x01, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    disabled = bytearray(11)

    for sector in (0x0001, 0x0002, 0x0003):
        name = {0x0001: "M1", 0x0002: "M2", 0x0003: "M3"}[sector]
        print(f"  {name} (sector 0x{sector:04X}): ", end="", flush=True)

        data = read_sector(fd, di, feat_8100, sector)

        data[208:219] = logo_effect
        data[219:230] = kb_effect
        data[230:241] = disabled
        data[241:252] = disabled

        crc = crc_ccitt(data[:253])
        data[253] = (crc >> 8) & 0xFF
        data[254] = crc & 0xFF

        if write_sector(fd, di, feat_8100, sector, data):
            print("OK")
        else:
            print("FAILED")

    # Ensure onboard mode and select M3
    send_recv(fd, [0x11, di, feat_8100, 0x1D, 0x01])
    send_recv(fd, [0x11, di, feat_8100, 0x3D, 0x00, 0x03])
    print("Onboard mode set, M3 selected.")

    os.close(fd)


if __name__ == "__main__":
    main()
