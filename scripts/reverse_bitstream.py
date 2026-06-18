#!/usr/bin/env python3
"""Bit-reverse each byte of a Quartus .rbf into the Analogue Pocket .rbf_r format.

The Analogue Pocket loads a bit-reversed raw binary file (.rbf_r): every byte of
the Quartus-generated .rbf has its bit order flipped (bit 7 <-> bit 0, etc).

See: https://www.analogue.co/developer/docs/packaging-a-core

Usage:
    python3 scripts/reverse_bitstream.py input.rbf output.rbf_r
"""
import sys

# Precomputed lookup table: index i -> i with its 8 bits reversed.
_REVERSED = bytes(int(f"{i:08b}"[::-1], 2) for i in range(256))


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.rbf output.rbf_r", file=sys.stderr)
        return 1

    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        data = f.read()

    reversed_data = data.translate(_REVERSED)

    with open(dst, "wb") as f:
        f.write(reversed_data)

    print(f"Reversed {len(data)} bytes: {src} -> {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
