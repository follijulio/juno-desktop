#!/usr/bin/env python3
"""Portabilidade do wallpaper e integridade de uma distribuição publicada."""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import struct
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zlib

ROOT = Path(__file__).resolve().parents[1]


def load_tool(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WALLPAPER = load_tool("generate_wallpaper")
PACKAGE = load_tool("package")


class WallpaperPortabilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.original = (ROOT / "assets/desktop/wallpapers/juno-paper.png").read_bytes()
        cls.content = WALLPAPER.png_content(cls.original)

    def rebuilt(self, rows: bytes, level: int = 1) -> bytes:
        header, palette, _ = self.content
        compressed = zlib.compress(rows, level)
        midpoint = len(compressed) // 2
        return (b"\x89PNG\r\n\x1a\n" + WALLPAPER.chunk(b"IHDR", header)
                + WALLPAPER.chunk(b"PLTE", palette)
                + WALLPAPER.chunk(b"IDAT", compressed[:midpoint])
                + WALLPAPER.chunk(b"IDAT", compressed[midpoint:])
                + WALLPAPER.chunk(b"IEND", b""))

    def test_other_compression_and_split_idat_preserve_content(self) -> None:
        rebuilt = self.rebuilt(self.content[2])
        self.assertNotEqual(rebuilt, self.original)
        self.assertEqual(WALLPAPER.png_content(rebuilt), self.content)

    def test_changed_pixels_are_detected(self) -> None:
        rows = bytearray(self.content[2])
        rows[1] = (rows[1] + 1) % 9
        self.assertNotEqual(WALLPAPER.png_content(self.rebuilt(bytes(rows))), self.content)

    def test_corrupt_or_incomplete_png_is_rejected(self) -> None:
        corrupt = bytearray(self.original)
        corrupt[20] ^= 1
        for data in (bytes(corrupt), self.original[:-4], self.original + b"trailing"):
            with self.subTest(size=len(data)), self.assertRaises(ValueError):
                WALLPAPER.png_content(data)


class DistributionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sandbox = tempfile.TemporaryDirectory()
        self.addCleanup(self.sandbox.cleanup)
        self.root = Path(self.sandbox.name)
        self.out = self.root / "dist"
        (self.root / "config/juno-gnome/bin").mkdir(parents=True)
        (self.root / "install.sh").write_bytes(b"#!/bin/bash\r\nprintf 'ok\\n'\r\n")
        (self.root / "config/juno-gnome/bin/juno").write_bytes(b"#!/bin/bash\r\nexit 0\r\n")
        (self.root / "image.png").write_bytes(b"binary\r\nunchanged")

    def existing_distribution(self) -> None:
        self.out.mkdir()
        (self.out / "juno-desktop.tar.gz").write_bytes(b"previous-archive")
        (self.out / "SHA256SUMS").write_bytes(b"previous-checksums")

    def assert_previous_distribution(self) -> None:
        self.assertEqual((self.out / "juno-desktop.tar.gz").read_bytes(), b"previous-archive")
        self.assertEqual((self.out / "SHA256SUMS").read_bytes(), b"previous-checksums")
        self.assertEqual(sorted(path.name for path in self.out.iterdir()),
                         ["SHA256SUMS", "juno-desktop.tar.gz"])

    def test_reproducible_bundle_has_lf_modes_and_matching_checksum(self) -> None:
        archive, digest = PACKAGE.package(self.root, self.out)
        first = archive.read_bytes()
        self.assertEqual(hashlib.sha256(first).hexdigest(), digest)
        self.assertEqual((self.out / "SHA256SUMS").read_bytes(),
                         f"{digest}  juno-desktop.tar.gz\n".encode())
        with tarfile.open(archive, "r:gz") as bundle:
            script = bundle.getmember("juno-desktop/config/juno-gnome/bin/juno")
            self.assertEqual(script.mode, 0o755)
            self.assertEqual(bundle.getmember("juno-desktop/install.sh").mode, 0o755)
            self.assertEqual(bundle.getmember("juno-desktop/image.png").mode, 0o644)
            self.assertEqual(bundle.extractfile(script).read(), b"#!/bin/bash\nexit 0\n")
            self.assertEqual(bundle.extractfile("juno-desktop/image.png").read(), b"binary\r\nunchanged")
        PACKAGE.package(self.root, self.out)
        self.assertEqual(archive.read_bytes(), first)

    def test_input_failure_preserves_existing_distribution(self) -> None:
        self.existing_distribution()
        original_read = Path.read_bytes

        def fail_read(path: Path) -> bytes:
            if path.name == "install.sh":
                raise OSError("simulated input failure")
            return original_read(path)

        with patch.object(Path, "read_bytes", fail_read), self.assertRaises(OSError):
            PACKAGE.package(self.root, self.out)
        self.assert_previous_distribution()

    def test_checksum_publication_failure_restores_previous_archive(self) -> None:
        self.existing_distribution()
        original_replace = PACKAGE.os.replace

        def fail_checksum(source, destination):
            if Path(destination).name == "SHA256SUMS":
                raise OSError("simulated checksum publication failure")
            return original_replace(source, destination)

        with patch.object(PACKAGE.os, "replace", fail_checksum), self.assertRaises(OSError):
            PACKAGE.package(self.root, self.out)
        self.assert_previous_distribution()

    def test_file_directory_and_broken_links_are_rejected(self) -> None:
        self.existing_distribution()
        for target, directory in ((self.root / "install.sh", False),
                                  (self.root / "config", True),
                                  (self.root / "missing", False)):
            link = self.root / "unexpected-link"
            try:
                link.symlink_to(target, target_is_directory=directory)
            except OSError as error:
                self.skipTest(f"Links simbólicos indisponíveis: {error}")
            try:
                with self.subTest(target=target), self.assertRaises(ValueError):
                    PACKAGE.package(self.root, self.out)
                self.assert_previous_distribution()
            finally:
                link.unlink()

    def test_excluded_metadata_is_not_published(self) -> None:
        (self.root / ".git").mkdir()
        (self.root / ".git/private").write_text("excluded", encoding="utf-8")
        archive, _ = PACKAGE.package(self.root, self.out)
        with tarfile.open(archive, "r:gz") as bundle:
            self.assertFalse(any(".git" in member.name for member in bundle.getmembers()))


if __name__ == "__main__":
    unittest.main()
