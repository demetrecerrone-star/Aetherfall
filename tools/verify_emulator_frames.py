#!/usr/bin/env python3
"""Reject black or frozen Android emulator frames without external Python packages."""
import hashlib
from pathlib import Path
import struct
import sys
import zlib


def visible_ratio(path: Path) -> float:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"{path} is not a PNG")
    pos, pieces = 8, []
    width = height = channels = None
    while pos < len(data):
        length = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if (depth, compression, filtering, interlace) != (8, 0, 0, 0) or color not in (2, 6):
                raise ValueError("Expected non-interlaced, 8-bit RGB/RGBA screenshot")
            channels = 3 if color == 2 else 4
        elif kind == b"IDAT":
            pieces.append(payload)
        elif kind == b"IEND":
            break
    if not pieces or width is None:
        raise ValueError("Missing image data")
    pixels = zlib.decompress(b"".join(pieces))
    row_size = width * channels
    last = bytearray(row_size)
    bright = sampled = offset = 0
    step_x, step_y = max(1, width // 80), max(1, height // 45)
    for y in range(height):
        filter_type = pixels[offset]
        offset += 1
        row = bytearray(pixels[offset:offset + row_size])
        offset += row_size
        if len(row) != row_size or filter_type > 4:
            raise ValueError("Malformed screenshot")
        if filter_type:
            for i in range(row_size):
                a = row[i - channels] if i >= channels else 0
                b = last[i]
                c = last[i - channels] if i >= channels else 0
                if filter_type == 1:
                    predictor = a
                elif filter_type == 2:
                    predictor = b
                elif filter_type == 3:
                    predictor = (a + b) // 2
                else:
                    p = a + b - c
                    d = (abs(p-a), abs(p-b), abs(p-c))
                    predictor = (a, b, c)[d.index(min(d))]
                row[i] = (row[i] + predictor) & 255
        if y % step_y == 0:
            for x in range(0, width, step_x):
                start = x * channels
                bright += max(row[start:start + 3]) > 35
                sampled += 1
        last = row
    return bright / sampled if sampled else 0.0


def main(folder: str) -> int:
    files = sorted(Path(folder).glob("*.png"))
    if any(not any(p.name.startswith(f"{n:02d}_") for p in files) for n in range(1, 8)):
        print("QA_RENDER_FAILED: missing one or more of seven gameplay screenshots", file=sys.stderr)
        return 1
    ratios = {}
    for path in files:
        ratios[path.name] = visible_ratio(path)
        print(f"{path.name}: visible pixels {ratios[path.name]:.1%}")
    for prefix in ("01_", "05_"):
        name = next(path.name for path in files if path.name.startswith(prefix))
        if ratios[name] < 0.04:
            print(f"QA_RENDER_FAILED: {name} is black or nearly blank", file=sys.stderr)
            return 1
    if len({hashlib.sha256(f.read_bytes()).digest() for f in files}) < 3:
        print("QA_RENDER_FAILED: emulator screenshots are frozen", file=sys.stderr)
        return 1
    print("QA_VISUAL_OK: visible gameplay and changing frames")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "qa-results"))
