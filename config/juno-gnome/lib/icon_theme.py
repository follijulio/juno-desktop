#!/usr/bin/env python3
"""Local Juno launcher treatment. Never evaluates desktop Exec or user shell files."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib

MARKER = "# Juno-Icons: "
PALETTE = ((49, 158, 154), (66, 105, 206), (138, 107, 182), (231, 139, 69), (219, 98, 97))
INDEX = """[Icon Theme]
Name=Juno Auto
Comment=Juno: aplicativos adaptados automaticamente
Inherits=Juno,Adwaita,hicolor
Directories=64x64/apps

[64x64/apps]
Size=64
Type=Fixed
Context=Applications
"""


def digest(data):
    return hashlib.sha256(data).hexdigest()


def desktop_roots(home):
    # XDG_DATA_DIRS may be absent in a TTY; include Flatpak and Snap exports.
    roots = [home / ".local/share/applications", home / ".local/share/flatpak/exports/share/applications"]
    roots += [Path(p) / "applications" for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p.startswith("/")]
    roots += [Path("/var/lib/flatpak/exports/share/applications"), Path("/var/lib/snapd/desktop/applications")]
    return list(dict.fromkeys(roots))


def read_desktop(path):
    # Exported Flatpak desktop files may be symlinks to deployment files.
    if not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise ValueError(f"desktop inválido: {path}")
    text = path.read_text(encoding="utf-8")
    if "\x00" in text:
        raise ValueError(f"desktop contém NUL: {path}")
    return text


def fields(text):
    section = None
    result = {}
    for line in text.splitlines():
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif section and "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            identity = (section, key)
            if identity in result:
                raise ValueError(f"chave desktop duplicada: {section}/{key}")
            result[identity] = value
    return result


def unpack(text):
    lines = text.splitlines(keepends=True)
    if not lines or not lines[0].startswith(MARKER):
        return text, None
    meta = json.loads(base64.b64decode(lines[0][len(MARKER):].strip(), validate=True))
    if (not isinstance(meta, dict) or set(meta) != {"version", "source", "body_sha256", "icons"}
            or type(meta["version"]) is not int or meta["version"] != 1
            or not isinstance(meta["source"], str) or not Path(meta["source"]).is_absolute()
            or not isinstance(meta["body_sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", meta["body_sha256"])
            or not isinstance(meta["icons"], list)
            or any(not isinstance(item, list) or len(item) != 4 or any(not isinstance(value, str) for value in item) for item in meta["icons"])):
        raise ValueError("metadados de ícone Juno inválidos")
    return "".join(lines[1:]), meta


def replace_icons(text, replacements):
    section = None
    output = []
    for line in text.splitlines(keepends=True):
        stripped = line.rstrip("\r\n")
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
        if "=" in stripped and not stripped.startswith("#"):
            key = stripped.split("=", 1)[0]
            if (section, key) in replacements:
                line = key + "=" + replacements[section, key] + "\n"
        output.append(line)
    return "".join(output)


def originals(body, meta):
    # Preserve user edits; restore only Icon fields still bearing our value.
    values = fields(body)
    replacements = {}
    for item in meta["icons"]:
        identity = (item[0], item[1])
        if values.get(identity) == item[3]:
            replacements[identity] = item[2]
    return replace_icons(body, replacements)


def discover(home, user_input, roots=None):
    roots = desktop_roots(home) if roots is None else roots
    candidates = {}
    for root in roots:
        if not root.is_dir():
            continue
        actual = user_input if root == home / ".local/share/applications" else root
        if not actual.exists():
            continue
        for path in sorted(actual.rglob("*.desktop")):
            name = "-".join(path.relative_to(actual).parts)
            if name.startswith(".") or any(ord(char) < 32 or char in "/\\" for char in name):
                continue
            candidates.setdefault(name, []).append((path, root / path.relative_to(actual)))
    result = []
    for name, options in sorted(candidates.items()):
        path, origin = options[0]
        body, meta = unpack(read_desktop(path))
        if meta:
            unchanged = digest(body.encode()) == meta["body_sha256"]
            upstream = next(((p, o) for p, o in options[1:] if str(o) == meta["source"]), None)
            if unchanged and meta["source"] != str(origin):
                if upstream is None:
                    result.append((name, None, None))  # Uninstalled upstream app.
                    continue
                path, origin = upstream
                body = read_desktop(path)
            else:
                body = originals(body, meta)
                if not unchanged:
                    origin = home / ".local/share/applications" / name
        values = fields(body)
        if ("Desktop Entry", "Icon") not in values:
            if "[Desktop Entry]" not in body:
                raise ValueError(f"grupo Desktop Entry ausente: {name}")
            body = body.replace("[Desktop Entry]", "[Desktop Entry]\nIcon=application-x-executable", 1)
            values = fields(body)
        if values.get(("Desktop Entry", "Hidden")) == "true":
            if meta and str(origin) != str(home / ".local/share/applications" / name):
                result.append((name, None, None))
            continue
        if values.get(("Desktop Entry", "Type"), "Application") != "Application":
            continue
        result.append((name, body, str(origin)))
    return result


def png(width, height, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    rows = b"".join(b"\0" + pixels[y * width * 4:(y + 1) * width * 4] for y in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")


def stylize(pixels, width, height, identity):
    """Cream glyph, dark ink outline and rounded muted-color tile, matching Juno."""
    color = PALETTE[int(digest(identity.encode())[:8], 16) % len(PALETTE)]
    output = bytearray(64 * 64 * 4)
    for y in range(64):
        for x in range(64):
            dx, dy = max(8 - x, 0, x - 55), max(8 - y, 0, y - 55)
            if dx * dx + dy * dy <= 36 and 2 <= x <= 61 and 2 <= y <= 61:
                edge = x < 5 or x > 58 or y < 5 or y > 58
                c = (36, 52, 58) if edge else color
                offset = (y * 64 + x) * 4
                output[offset:offset + 4] = bytes((*c, 255))
    for y in range(height):
        for x in range(width):
            i = (y * width + x) * 4
            r, g, b, a = pixels[i:i + 4]
            if not a:
                continue
            # Retain the original glyph details through a small tonal palette.
            c = (255, 244, 215) if max(r, g, b) > 100 else (36, 52, 58)
            target = (((64 - height) // 2 + y) * 64 + (64 - width) // 2 + x) * 4
            old = output[target:target + 3]
            output[target:target + 4] = bytes((*(round(c[k] * a / 255 + old[k] * (1 - a / 255)) for k in range(3)), 255))
    return png(64, 64, bytes(output))


class Renderer:
    def __init__(self, home, base):
        import gi
        gi.require_version("Gtk", "3.0")
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import Gtk, GdkPixbuf
        self.Gtk, self.Pixbuf = Gtk, GdkPixbuf
        self.base = base.resolve()
        self.home = home
        self.fallback_files = None
        self.theme = Gtk.IconTheme.new()
        self.theme.set_search_path([str(base.parent), str(home / ".local/share/icons"), str(home / ".icons"), "/usr/local/share/icons", "/usr/share/icons", "/usr/share/pixmaps"])
        self.theme.set_custom_theme("Juno")

    def fallback(self, name):
        # Some Zorin applications install their artwork only inside the Zorin
        # theme. It is not in Adwaita/hicolor's inheritance chain. Index those
        # files once, rather than replacing a perfectly good logo with a stub.
        if self.fallback_files is None:
            candidates = []
            for root in (self.home / ".local/share/icons", self.home / ".icons", Path("/usr/local/share/icons"), Path("/usr/share/icons"), Path("/usr/share/pixmaps")):
                if root.is_dir():
                    candidates.extend(path for path in root.rglob("*") if path.suffix.lower() in (".svg", ".png", ".xpm", ".ico") and path.is_file() and "Juno-Auto" not in path.parts)
            self.fallback_files = {}
            for path in sorted(candidates, key=lambda p: (p.suffix.lower() != ".svg", str(p))):
                self.fallback_files.setdefault(path.stem, path)
                self.fallback_files.setdefault(path.name, path)
        return self.fallback_files.get(name)

    def render(self, icon, identity):
        path = Path(icon) if Path(icon).is_absolute() else None
        if path is None:
            # Staging directories are not named Juno yet; consult curated SVGs
            # explicitly before looking in the system theme inheritance chain.
            if re.fullmatch(r"[\w.+@-]+", icon, re.ASCII):
                path = next(iter(sorted(self.base.glob("scalable/*/" + icon + ".svg"))), None)
            if path is None:
                info = self.theme.lookup_icon(icon, 64, self.Gtk.IconLookupFlags.FORCE_SIZE)
                path = Path(info.get_filename()) if info and info.get_filename() else None
            if path is None:
                path = self.fallback(icon)
        curated = path is not None and self.base in path.resolve().parents
        if path is not None:
            try:
                if path.stat().st_size > 8 * 1024 * 1024:
                    raise ValueError("ícone grande demais")
                if path.suffix.lower() == ".svg":
                    data = path.read_text(encoding="utf-8")
                    if re.search(r"<!DOCTYPE|<!ENTITY|<script|<foreignObject|@import|(?:href\s*=\s*['\"](?!#))|url\(\s*['\"]?(?!#)", data, re.I):
                        raise ValueError("SVG com referências externas")
                size = self.Pixbuf.Pixbuf.get_file_info(str(path))
                if size is None or max(size[1:]) > 8192:
                    raise ValueError("dimensões inválidas")
                image = self.Pixbuf.Pixbuf.new_from_file_at_scale(str(path), 64 if curated else 42, 64 if curated else 42, True)
                if not image.get_has_alpha():
                    image = image.add_alpha(False, 0, 0, 0)
                width, height, stride = image.get_width(), image.get_height(), image.get_rowstride()
                data = image.get_pixels()
                packed = b"".join(data[y * stride:y * stride + width * 4] for y in range(height))
                return png(width, height, packed) if curated else stylize(packed, width, height, identity)
            except Exception as exc:
                print(f"Juno: ícone {icon}: {exc}; usando símbolo genérico.", file=sys.stderr)
        # An unknown or invalid source still receives a Juno tile.
        pixels = b"".join(bytes((248, 238, 209, 255 if (x in (3, 20) or y in (3, 20)) else 0)) for y in range(24) for x in range(24))
        return stylize(pixels, 24, 24, identity)


def build(home, user_input, apps_output, theme_output, renderer, roots=None):
    if user_input.is_symlink() or (user_input.exists() and not user_input.is_dir()):
        raise ValueError("applications deve ser um diretório real")
    if user_input.exists():
        shutil.copytree(user_input, apps_output, dirs_exist_ok=True, symlinks=True)
    apps_output.mkdir(parents=True, exist_ok=True)
    image_dir = theme_output / "64x64/apps"
    image_dir.mkdir(parents=True, exist_ok=True)
    (theme_output / "index.theme").write_text(INDEX, encoding="utf-8")
    count = 0
    for name, body, origin in discover(home, user_input, roots):
        destination = apps_output / name
        user_root = home / ".local/share/applications"
        if origin is not None and Path(origin).is_relative_to(user_root):
            destination = apps_output / Path(origin).relative_to(user_root)
        # Never follow a user launcher symlink while writing. Preserve it.
        if destination.is_symlink():
            continue
        if body is None:
            if destination.exists():
                destination.unlink()
            continue
        values = fields(body)
        replacements, records = {}, []
        for (section, key), icon in values.items():
            if not (section == "Desktop Entry" or section.startswith("Desktop Action ")) or not re.fullmatch(r"Icon(?:\[[^\]]+\])?", key):
                continue
            filename = "juno-" + digest((name + "\0" + section + "\0" + key).encode())[:24] + ".png"
            data = renderer.render(icon, name)
            (image_dir / filename).write_bytes(data)
            # Absolute paths also work for apps whose vendor Icon was absolute.
            generated = str(home / ".local/share/icons/Juno-Auto/64x64/apps" / filename)
            replacements[section, key] = generated
            records.append([section, key, icon, generated])
        if not records:
            continue
        changed = replace_icons(body, replacements)
        meta = {"version": 1, "source": origin, "body_sha256": digest(changed.encode()), "icons": records}
        encoded = base64.b64encode(json.dumps(meta, ensure_ascii=False, sort_keys=True).encode()).decode()
        destination.write_text(MARKER + encoded + "\n" + changed, encoding="utf-8", newline="\n")
        count += 1
    # Deliberately stable permissions: no spurious backup on every refresh.
    os.chmod(apps_output, (user_input.stat().st_mode & 0o777) if user_input.exists() else 0o755)
    os.chmod(theme_output, 0o755)
    print(f"Juno: {count} lançadores com estilização local.")


def fingerprint(home):
    data = []
    for root in desktop_roots(home):
        if root.is_dir():
            for path in sorted(root.rglob("*.desktop")):
                try:
                    stat = path.stat()
                    data.append((str(path), stat.st_mtime_ns, stat.st_size))
                except FileNotFoundError:
                    pass
    return digest(json.dumps(data).encode())


def refresh(home):
    # Invoke only our trusted transaction runner; never load a login shell.
    runner = home / ".config/juno-gnome/lib/icons_runtime.sh"
    env = dict(os.environ)
    env.pop("BASH_ENV", None)
    env.pop("ENV", None)
    return subprocess.run(["/usr/bin/bash", "--noprofile", "--norc", str(runner)], env=env, check=False).returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "refresh", "watch"))
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--input", type=Path)
    parser.add_argument("--apps-output", type=Path)
    parser.add_argument("--theme-output", type=Path)
    parser.add_argument("--base", type=Path)
    args = parser.parse_args()
    if args.command == "build":
        if not all((args.input, args.apps_output, args.theme_output, args.base)):
            parser.error("build exige input, apps-output, theme-output e base")
        build(args.home, args.input, args.apps_output, args.theme_output, Renderer(args.home, args.base))
        return 0
    if args.command == "refresh":
        return refresh(args.home)
    previous = None
    while True:
        current = fingerprint(args.home)
        if current != previous:
            status = refresh(args.home)
            # Retry failures; record after success to absorb our own writes.
            if status == 0:
                previous = fingerprint(args.home)
        time.sleep(60)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, ImportError) as error:
        print(f"Juno ícones: {error}", file=sys.stderr)
        sys.exit(2)
