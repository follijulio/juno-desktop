#!/usr/bin/env python3
"""Decode actual curated and system icons with the distribution's GI loaders."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("icons", ROOT / "config/juno-gnome/lib/icon_theme.py")
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)
renderer = icons.Renderer(Path.home(), ROOT / "assets/icons/Juno")
from gi.repository import GdkPixbuf

for name in ("firefox", "org.gnome.Settings", "application-x-executable"):
    data = renderer.render(name, name)
    loader = GdkPixbuf.PixbufLoader.new_with_type("png")
    loader.write(data)
    loader.close()
    image = loader.get_pixbuf()
    assert image and image.get_width() <= 64 and image.get_height() <= 64, name
    assert image.get_has_alpha(), name
print("Ícones nativos: GTK, loaders SVG/PNG e composição conferidos.")
