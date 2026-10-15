#!/usr/bin/env python3
"""Valida identidade, recursos e checksums sem dependências externas."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
import zlib
from pathlib import Path

PALETTE = {
    "FFFDF5", "111111", "FFFFFF", "F4EDDB", "FF5B35",
    "FFCC00", "FFE066", "B8F2E6", "FF9B85",
}


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def check_text(path: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for color in re.findall(r"#([\da-fA-F]{6}(?:[\da-fA-F]{2})?)(?![\da-fA-F])", text):
        require(color[:6].upper() in PALETTE, f"{path.name}: cor fora da paleta #{color}", errors)
        require(len(color) == 6 or color[6:].upper() == "FF", f"{path.name}: cor translúcida #{color}", errors)
    # A sintaxe rgb(HEX) é usada por Hyprlock; rgb(17,17,17) também é aceita.
    for color in re.findall(r"\brgba?\(\s*([\da-fA-F]{6,8})\s*\)", text):
        require(color[:6].upper() in PALETTE, f"{path.name}: rgb({color}) fora da paleta", errors)
        require(len(color) == 6 or color[6:].upper() == "FF", f"{path.name}: rgb translúcido", errors)
    for values in re.findall(r"\brgba?\(([\d.,\s]+)\)", text):
        parts = [value.strip() for value in values.split(",")]
        if len(parts) not in (3, 4):
            continue
        try:
            color = "".join(f"{int(value):02X}" for value in parts[:3])
        except ValueError:
            errors.append(f"{path.name}: formato RGB inválido {values}")
            continue
        require(color in PALETTE, f"{path.name}: RGB fora da paleta {values}", errors)
        if len(parts) == 4:
            require(float(parts[3]) == 1, f"{path.name}: alpha diferente de 1", errors)
    for value in re.findall(r"\b(?:border-radius|rounding|dots_rounding)\s*[:=]\s*(-?[\d.]+)", text):
        require(float(value) == 0, f"{path.name}: arredondamento diferente de zero", errors)
    for value in re.findall(r"\bbox-shadow\s*:\s*([^;]+)", text):
        if value.strip() == "none":
            continue
        lengths = re.findall(r"(?<![\w#])(-?\d+(?:\.\d+)?)(?:px)?(?!\w)", value)
        require(len(lengths) >= 3 and float(lengths[2]) == 0,
                f"{path.name}: sombra com desfoque", errors)
    for value in re.findall(r"\b(?:font_family|font-family|bold_font|italic_font|bold_italic_font|font)\s*[:= ]+([^;\n]+)", text):
        family = value.strip().strip('"').strip("'")
        require(family.startswith(("Roboto", "Space Mono")),
                f"{path.name}: fonte fora da identidade: {family}", errors)
    for value in re.findall(r"\b(?:background_opacity|active_opacity|inactive_opacity|fullscreen_opacity|inactive_text_alpha)\s*[:= ]+([\d.]+)", text):
        require(float(value) == 1, f"{path.name}: superfície translúcida", errors)
    for value in re.findall(r"\b(?:shadow_passes|blur_passes)\s*=\s*(\d+)", text):
        require(int(value) == 0, f"{path.name}: blur/sombra nativa habilitado", errors)
    require(not re.search(r"\b(?:shadow|blur|motion_blur|glow|animations)\s*=\s*\{\s*enabled\s*=\s*true", text),
            f"{path.name}: efeito nativo ou animação habilitados", errors)


def check_manifest(directory: Path, errors: list[str]) -> None:
    manifest = directory / "SHA256SUMS"
    require(manifest.is_file(), f"Checksum ausente: {manifest}", errors)
    if not manifest.is_file():
        return
    for line in manifest.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([\w.-]+)", line)
        if not match:
            errors.append(f"Manifesto inválido: {manifest}")
            continue
        digest, name = match.groups()
        target = directory / name
        require(target.is_file(), f"Recurso ausente: {target}", errors)
        if target.is_file():
            require(hashlib.sha256(target.read_bytes()).hexdigest() == digest,
                    f"Checksum incorreto: {target}", errors)


def check_png(path: Path, errors: list[str]) -> None:
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", "Wallpaper não é PNG", errors)
    offset, compressed, palette = 8, bytearray(), b""
    header = None
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        expected_crc = struct.unpack(">I", data[offset + 8 + size:offset + 12 + size])[0]
        require((zlib.crc32(kind + payload) & 0xFFFFFFFF) == expected_crc,
                f"CRC PNG inválido: {kind!r}", errors)
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"PLTE":
            palette = payload
        elif kind == b"IDAT":
            compressed.extend(payload)
        offset += size + 12
    require(header == (3840, 2160, 8, 3, 0, 0, 0), "Wallpaper deve ser PNG indexado opaco 3840×2160", errors)
    require(len(palette) == 27 and all(palette[n:n + 3].hex().upper() in PALETTE for n in range(0, len(palette), 3)),
            "Wallpaper contém cores fora da identidade", errors)
    require(b"tRNS" not in data, "Wallpaper deve ser opaco", errors)
    rows = zlib.decompress(compressed)
    require(len(rows) == 2160 * 3841, "Pixels do wallpaper incompletos", errors)
    require(all(rows[y * 3841] == 0 for y in range(2160)), "PNG deve usar filtro zero", errors)
    require(max(rows) < 9, "PNG contém índice fora da paleta", errors)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root, errors = args.root, []
    config = root / "config"
    for path in sorted(config.rglob("*")):
        if path.is_file():
            check_text(path, errors)
    waybar = json.loads((config / "waybar/config.jsonc").read_text(encoding="utf-8"))
    require("battery" not in waybar["modules-right"] and "backlight" not in waybar["modules-right"],
            "Hardware opcional deve ser detectado na sessão", errors)
    kitty = (config / "kitty/kitty.conf").read_text(encoding="utf-8")
    require(all(f"color{index} " in kitty for index in range(16)), "Kitty precisa definir as 16 cores ANSI", errors)
    for directory in (root / "assets/fonts/spacemono", root / "assets/desktop/wallpapers"):
        check_manifest(directory, errors)
    fonts = root / "assets/fonts/spacemono"
    metadata = json.loads((fonts / "source.json").read_text(encoding="utf-8"))
    require(bool(re.fullmatch(r"[0-9a-f]{40}", metadata["revision"])), "Revisão das fontes deve ser imutável", errors)
    for name in ("Regular", "Bold", "Italic", "BoldItalic"):
        data = (fonts / f"SpaceMono-{name}.ttf").read_bytes()
        require(data[:4] == b"\x00\x01\x00\x00", f"Space Mono {name}: TTF inválido", errors)
        require(hashlib.sha256(data).hexdigest() == metadata["sha256"][f"SpaceMono-{name}.ttf"],
                f"Space Mono {name}: metadados não conferem", errors)
    check_text(root / "assets/desktop/wallpapers/juno-paper.svg", errors)
    check_png(root / "assets/desktop/wallpapers/juno-paper.png", errors)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("Identidade conferida: paleta, cantos, sombras, fontes originais e wallpaper.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, struct.error, zlib.error) as error:
        print(f"Validação interrompida: {error}", file=sys.stderr)
        raise SystemExit(1) from None
