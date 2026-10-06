import argparse
import struct
from pathlib import Path


REPRESENTATIONS = (
    (b"icp4", 16, 1),
    (b"ic11", 16, 2),
    (b"icp5", 32, 1),
    (b"ic12", 32, 2),
    (b"ic07", 128, 1),
    (b"ic13", 128, 2),
    (b"ic08", 256, 1),
    (b"ic14", 256, 2),
    (b"ic09", 512, 1),
    (b"ic10", 512, 2),
)


def pack_icon(iconset: Path, destination: Path) -> None:
    chunks = []
    for kind, points, scale in REPRESENTATIONS:
        suffix = "@2x" if scale == 2 else ""
        source = iconset / f"icon_{points}x{points}{suffix}.png"
        data = source.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError(f"Not a PNG: {source.name}")
        expected = points * scale
        if struct.unpack(">II", data[16:24]) != (expected, expected):
            raise ValueError(f"Incorrect dimensions: {source.name}")
        chunks.append(kind + struct.pack(">I", len(data) + 8) + data)
    body = b"".join(chunks)
    destination.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
    print(f"Packed {len(chunks)} icon representations")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Package existing PNG representations without modifying image data.")
    parser.add_argument("iconset", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    pack_icon(args.iconset, args.destination)
