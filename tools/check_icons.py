#!/usr/bin/env python3
"""Validate the local app icon theme without rendering or changing files."""
from __future__ import annotations

import argparse
import configparser
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
TAGS = {"svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "title", "desc"}
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
REQUIRED = {"firefox", "org.gnome.Nautilus", "kitty", "mpv", "pavucontrol", "steam",
            "discord", "com.spotify.Client", "visual-studio-code", "org.gnome.Settings",
            "folder", "user-home", "folder-documents", "folder-download", "folder-pictures",
            "folder-music", "folder-videos", "folder-symbolic", "user-home-symbolic",
            "applications-system", "applications-system-symbolic", "view-app-grid-symbolic"}


def validate_svg(path: Path) -> None:
    data = path.read_bytes()
    if len(data) > 128 * 1024 or b"<!DOCTYPE" in data.upper() or b"<!ENTITY" in data.upper():
        raise ValueError(f"SVG inválido: {path.name}")
    root = ET.fromstring(data)
    if root.tag != f"{{{SVG}}}svg" or root.get("viewBox") != "0 0 64 64":
        raise ValueError(f"Dimensões SVG inválidas: {path.name}")
    for element in root.iter():
        if element.tag not in {f"{{{SVG}}}{tag}" for tag in TAGS}:
            raise ValueError(f"Elemento SVG não permitido: {path.name}")
        for key, value in element.attrib.items():
            attribute = key.rsplit("}", 1)[-1].lower()
            if attribute.startswith("on") or attribute in {"href", "style", "filter", "font-family"} or "url(" in value.lower():
                raise ValueError(f"Recurso externo ou ativo no SVG: {path.name}")


def validate_theme(theme: Path) -> tuple[int, int]:
    if theme.is_symlink() or not theme.is_dir():
        raise ValueError("Diretório de ícones ausente ou inválido")
    paths = list(theme.rglob("*"))
    if any(p.is_symlink() or not (p.is_file() or p.is_dir()) for p in paths):
        raise ValueError("O tema contém links ou arquivos especiais")
    actual = {p.relative_to(theme).as_posix() for p in paths if p.is_file()}
    manifest = theme / "SHA256SUMS"
    listed = set()
    for line in manifest.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise ValueError("Manifesto de ícones inválido")
        digest, name = match.groups()
        relative = PurePosixPath(name)
        if (relative.is_absolute() or ".." in relative.parts or "\\" in name
                or relative.as_posix() != name or name in listed or name == "SHA256SUMS"):
            raise ValueError("Caminho inválido ou repetido no manifesto de ícones")
        listed.add(name)
        path = theme / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f"Integridade do ícone não confere: {name}")
    if listed != actual - {"SHA256SUMS"}:
        raise ValueError("Manifesto incompleto ou arquivo inesperado no tema")
    index = configparser.ConfigParser(interpolation=None)
    index.read_string((theme / "index.theme").read_text(encoding="utf-8"))
    section = index["Icon Theme"]
    if (section.get("Name") != "Juno" or section.get("Inherits") != "Adwaita,hicolor"
            or section.get("Directories") != "scalable/apps,scalable/places,scalable/categories,scalable/actions"):
        raise ValueError("Índice ou fallback do tema inválido")
    size = index["scalable/apps"]
    if (size.get("Type") != "Scalable" or size.get("Context") != "Applications"
            or size.getint("MinSize") > 16 or size.getint("MaxSize") < 128 or size.getint("Size") != 64):
        raise ValueError("Escala ou contexto dos ícones inválido")
    for directory, context in (("places", "Places"), ("categories", "Categories"), ("actions", "Actions")):
        size = index[f"scalable/{directory}"]
        if (size.get("Type") != "Scalable" or size.get("Context") != context
                or size.getint("MinSize") > 16 or size.getint("MaxSize") < 128 or size.getint("Size") != 64):
            raise ValueError("Escala ou contexto dos ícones inválido")
    metadata = json.loads((theme / "source.json").read_text(encoding="utf-8"))
    if metadata.get("version") != 1 or metadata.get("license") != "CC0-1.0" or not metadata.get("icons"):
        raise ValueError("Metadados dos ícones inválidos")
    names, portable_names = set(), set()
    svg_paths = set()
    for icon in metadata["icons"]:
        primary = icon["name"]
        context = icon.get("context", "apps")
        if context not in {"apps", "places", "categories", "actions"}:
            raise ValueError("Contexto de ícone inválido")
        for name in (primary, *icon["aliases"]):
            if not isinstance(name, str) or not NAME.fullmatch(name) or name.casefold() in portable_names:
                raise ValueError("Nome de ícone inválido ou repetido")
            names.add(name)
            portable_names.add(name.casefold())
            relative = f"scalable/{context}/{name}.svg"
            svg_paths.add(relative)
            path = theme / relative
            validate_svg(path)
            if path.read_bytes() != (theme / f"scalable/{context}" / (primary + ".svg")).read_bytes():
                raise ValueError(f"Alias diferente do ícone original: {name}")
    if not REQUIRED <= names or svg_paths != {p for p in actual if p.endswith(".svg")}:
        raise ValueError("Cobertura dos aplicativos ou aliases incompleta")
    return len(metadata["icons"]), len(names)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("theme", nargs="?", type=Path,
                        default=Path(__file__).resolve().parents[1] / "assets/icons/Juno")
    args = parser.parse_args()
    try:
        designs, files = validate_theme(args.theme)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError, configparser.Error) as error:
        print(f"Tema de ícones recusado: {error}", file=sys.stderr)
        return 1
    print(f"Ícones conferidos: {designs} desenhos, {files} SVGs e fallback nativo.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
