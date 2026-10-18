#!/usr/bin/env python3
"""Recria o papel editorial em PNG indexado e SVG, sem bibliotecas externas."""

from __future__ import annotations

import argparse
import hashlib
import struct
import zlib
from pathlib import Path

WIDTH, HEIGHT = 3840, 2160
PALETTE = (
    "FFFDF5", "111111", "FFFFFF", "F4EDDB", "FF5B35",
    "FFCC00", "FFE066", "B8F2E6", "FF9B85",
)


def rectangles() -> list[tuple[int, int, int, int, int]]:
    """Geometria inteira mantém o mesmo mestre e apenas as cores autorizadas."""
    shapes = [(0, 0, WIDTH, HEIGHT, 0)]
    # Microtextura de impressão. Jitter determinístico evita um grid rígido.
    for y in range(20, HEIGHT, 32):
        for x in range(20, WIDTH, 32):
            seed = (x * 73856093) ^ (y * 19349663)
            shapes.append((x + seed % 7 - 3, y + seed // 7 % 7 - 3, 2, 2, 3))
    # Ficha discreta no canto: recortes retos e sombra de tinta sem blur.
    x, y, w, h = 3040, 1740, 640, 260
    shapes.extend([
        (x + 12, y + 12, w, h, 1),
        (x, y, w, h, 1),
        (x + 4, y + 4, w - 8, h - 8, 2),
        (x + 4, y + 4, 190, 56, 5),
        (x + 4, y + 60, w - 8, 4, 1),
        (x + 32, y + 96, w - 64, 4, 3),
        (x + 32, y + 140, w - 64, 4, 3),
        (x + 32, y + 184, w - 64, 4, 3),
        (x + w - 48, y + 216, 16, 16, 4),
    ])
    return shapes


def chunk(kind: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))


def png(shapes: list[tuple[int, int, int, int, int]]) -> bytes:
    pixels = [bytearray(WIDTH) for _ in range(HEIGHT)]
    for x, y, width, height, color in shapes:
        for row in pixels[y:y + height]:
            row[x:x + width] = bytes([color]) * width
    rows = b"".join(b"\0" + bytes(row) for row in pixels)
    palette = b"".join(bytes.fromhex(color) for color in PALETTE)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 3, 0, 0, 0))
            + chunk(b"PLTE", palette)
            + chunk(b"IDAT", zlib.compress(rows, level=9))
            + chunk(b"IEND", b""))


def png_content(data: bytes) -> tuple[bytes, bytes, bytes]:
    """Compare estrutura e pixels; a compressão varia entre builds de zlib."""
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Assinatura PNG inválida")
    offset, header, palette, compressed = 8, b"", b"", bytearray()
    kinds: list[bytes] = []
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("Chunk PNG incompleto")
        size = struct.unpack_from(">I", data, offset)[0]
        end = offset + size + 12
        if end > len(data):
            raise ValueError("Chunk PNG truncado")
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:end - 4]
        expected_crc = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError("CRC PNG inválido")
        kinds.append(kind)
        if kind == b"IHDR":
            header = payload
        elif kind == b"PLTE":
            palette = payload
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            if payload or end != len(data):
                raise ValueError("Final PNG inválido")
        else:
            raise ValueError(f"Chunk PNG inesperado: {kind!r}")
        offset = end
    if (len(kinds) < 4 or kinds[:2] != [b"IHDR", b"PLTE"] or
            kinds[-1:] != [b"IEND"] or any(kind != b"IDAT" for kind in kinds[2:-1])):
        raise ValueError("Estrutura PNG inválida")
    expected_header = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 3, 0, 0, 0)
    if header != expected_header:
        raise ValueError("Formato PNG inesperado")
    decoder = zlib.decompressobj()
    rows = decoder.decompress(compressed, HEIGHT * (WIDTH + 1) + 1)
    if (not decoder.eof or decoder.unused_data or decoder.unconsumed_tail or
            len(rows) != HEIGHT * (WIDTH + 1)):
        raise ValueError("Pixels PNG inválidos")
    return header, palette, rows


def svg(shapes: list[tuple[int, int, int, int, int]]) -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160"',
        '     viewBox="0 0 3840 2160" shape-rendering="crispEdges">',
        '  <title>Juno — papel editorial</title>',
        '  <desc>Papel creme com microtextura bege e uma ficha de cantos retos.</desc>',
    ]
    lines.extend(
        f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#{PALETTE[c]}"/>'
        for x, y, w, h, c in shapes
    )
    return "\n".join([*lines, "</svg>", ""])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verifica sem gravar arquivos.")
    args = parser.parse_args()
    destination = Path(__file__).resolve().parents[1] / "assets/desktop/wallpapers"
    shapes = rectangles()
    outputs = {"juno-paper.png": png(shapes), "juno-paper.svg": svg(shapes).encode("utf-8")}
    if args.check:
        for name, content in outputs.items():
            existing = (destination / name).read_bytes()
            if name.endswith(".png"):
                matches = png_content(existing) == png_content(content)
            else:
                matches = existing == content
            if not matches:
                raise SystemExit(f"Wallpaper desatualizado: {name}")
        print("Wallpaper conferido: estrutura e pixels PNG e conteúdo SVG correspondem ao gerador.")
        return
    destination.mkdir(parents=True, exist_ok=True)
    for name, content in outputs.items():
        (destination / name).write_bytes(content)
    checksums = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n" for name, data in outputs.items())
    (destination / "SHA256SUMS").write_text(checksums, encoding="utf-8", newline="\n")
    print(f"Wallpaper gerado em {destination}")


if __name__ == "__main__":
    main()
