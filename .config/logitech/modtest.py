#!/usr/bin/env python3
"""Interactive modifier key mapping test. Run directly in terminal."""
import os, time

fd = os.open('/dev/hidraw6', os.O_RDWR | os.O_NONBLOCK)

def send_pkt(data):
    buf = bytes(data) + bytes(20 - len(data))
    os.write(fd, buf)
    time.sleep(0.05)
    while True:
        try: os.read(fd, 64)
        except BlockingIOError: break

f4522, f8071, f8081 = 0x0E, 0x09, 0x0A

# Init direct mode
send_pkt([0x11, 0xFF, f4522, 0x3E])
send_pkt([0x11, 0xFF, f4522, 0x1E])
send_pkt([0x11, 0xFF, f8071, 0x1E] + [0x00]*12 + [0x01])
send_pkt([0x11, 0xFF, f8071, 0x1E, 0x01] + [0x00]*11 + [0x01])

# Black out everything
for i in range(0, 0x50, 4):
    send_pkt([0x11, 0xFF, f8081, 0x1F, i,0,0,0, i+1,0,0,0, i+2,0,0,0, i+3,0,0,0])
for i in range(0x61, 0x70, 4):
    batch = []
    for j in range(min(4, 0x70-i)):
        batch.extend([i+j, 0,0,0])
    batch.extend([0]*(16-len(batch)))
    send_pkt([0x11, 0xFF, f8081, 0x1F] + batch)
send_pkt([0x11, 0xFF, f8081, 0x7F])

print("All keys dark. Press Enter to start.")
input()

results = {}
for code in range(0x61, 0x70):
    # Black out all modifiers
    for i in range(0x61, 0x70, 4):
        batch = []
        for j in range(min(4, 0x70-i)):
            batch.extend([i+j, 0,0,0])
        batch.extend([0]*(16-len(batch)))
        send_pkt([0x11, 0xFF, f8081, 0x1F] + batch)

    # Light ONLY this code white
    send_pkt([0x11, 0xFF, f8081, 0x1F, code, 0xFF,0xFF,0xFF, 0,0,0,0, 0,0,0,0, 0,0,0,0])
    send_pkt([0x11, 0xFF, f8081, 0x7F])

    key = input(f"0x{code:02X} - which key is white? (or 'none'): ").strip()
    if key and key != 'none':
        results[code] = key

os.close(fd)
print("\nResults:")
for code, key in sorted(results.items()):
    print(f"  0x{code:02X} = {key}")
