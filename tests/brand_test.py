#!/usr/bin/env python3
"""Exercita a rejeição de desvios de marca e de recursos corrompidos."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("check_brand", ROOT / "tools/check_brand.py")
assert SPEC and SPEC.loader
BRAND = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRAND)


class BrandValidationTests(unittest.TestCase):
    def errors_for(self, content: str) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.conf"
            path.write_text(content, encoding="utf-8")
            errors: list[str] = []
            BRAND.check_text(path, errors)
            return errors

    def test_editorial_defaults_are_valid(self) -> None:
        self.assertEqual(self.errors_for(
            'font-family: "Roboto"; color: #111111; background: #FFFDF5; '
            'border-radius: 0; box-shadow: 4px 4px 0 #111111;\n'
            'rounding = 0\nblur_passes = 0\nshadow = { enabled = false }'
        ), [])

    def test_unapproved_color_is_rejected(self) -> None:
        self.assertTrue(self.errors_for("background: #123456;"))
        self.assertTrue(self.errors_for("background = rgb(123456)"))
        self.assertTrue(self.errors_for("background: rgb(1, 2, 3);"))

    def test_transparency_is_rejected(self) -> None:
        self.assertTrue(self.errors_for("background: #FFFDF580;"))
        self.assertTrue(self.errors_for("color: rgba(17, 17, 17, 0.5);"))
        self.assertTrue(self.errors_for("background_opacity 0.8"))

    def test_rounded_geometry_is_rejected(self) -> None:
        self.assertTrue(self.errors_for("border-radius: 4px;"))
        self.assertTrue(self.errors_for("rounding = -1"))
        self.assertTrue(self.errors_for("dots_rounding = 1"))

    def test_blur_and_animation_are_rejected(self) -> None:
        self.assertTrue(self.errors_for("box-shadow: 4px 4px 2px #111111;"))
        self.assertTrue(self.errors_for("blur = { enabled = true }"))
        self.assertTrue(self.errors_for("animations = { enabled = true }"))
        self.assertTrue(self.errors_for("shadow_passes = 1"))

    def test_unapproved_font_is_rejected(self) -> None:
        self.assertTrue(self.errors_for('font-family: "Inter";'))
        self.assertTrue(self.errors_for("font_family Noto Sans"))
        self.assertEqual(self.errors_for("font_family Space Mono\nfont=Roboto 12"), [])

    def test_vendored_resources_have_valid_checksums(self) -> None:
        errors: list[str] = []
        BRAND.check_manifest(ROOT / "assets/fonts/spacemono", errors)
        BRAND.check_manifest(ROOT / "assets/desktop/wallpapers", errors)
        self.assertEqual(errors, [])

    def test_changed_resource_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "resource.txt").write_text("changed", encoding="utf-8")
            (path / "SHA256SUMS").write_text("0" * 64 + "  resource.txt\n", encoding="utf-8")
            errors: list[str] = []
            BRAND.check_manifest(path, errors)
            self.assertTrue(errors)

    def test_wallpaper_is_opaque_and_uses_only_the_palette(self) -> None:
        errors: list[str] = []
        BRAND.check_png(ROOT / "assets/desktop/wallpapers/juno-paper.png", errors)
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
