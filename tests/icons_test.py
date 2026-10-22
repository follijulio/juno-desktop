"""Check theme corruption and alias/fallback failures before installation."""
import hashlib
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("check_icons", ROOT / "tools/check_icons.py")
ICONS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ICONS)


class IconThemeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.theme = Path(self.directory.name) / "Juno"
        shutil.copytree(ROOT / "assets/icons/Juno", self.theme)

    def checksum(self, name):
        manifest = self.theme / "SHA256SUMS"
        lines = manifest.read_text().splitlines()
        digest = hashlib.sha256((self.theme / name).read_bytes()).hexdigest()
        manifest.write_text("\n".join(digest + "  " + name if line.endswith("  " + name) else line
                                      for line in lines) + "\n", encoding="utf-8")

    def test_distributed_theme_and_aliases_validate(self):
        designs, files = ICONS.validate_theme(self.theme)
        self.assertGreaterEqual(designs, 30)
        self.assertGreater(files, designs)

    def test_places_and_menu_have_distinct_contexts_and_symbolic_outlines(self):
        for name in ('folder', 'user-home', 'folder-documents', 'folder-download', 'folder-pictures', 'folder-music', 'folder-videos'):
            regular = self.theme / f'scalable/places/{name}.svg'
            symbolic = self.theme / f'scalable/places/{name}-symbolic.svg'
            self.assertTrue(regular.is_file())
            self.assertTrue(symbolic.is_file())
            self.assertNotEqual(regular.read_bytes(), symbolic.read_bytes())
            self.assertNotIn('width="56"', symbolic.read_text(encoding='utf-8'))
        for name in ('applications-office', 'applications-system', 'applications-internet'):
            self.assertTrue((self.theme / f'scalable/categories/{name}-symbolic.svg').is_file())
        self.assertTrue((self.theme / 'scalable/actions/system-lock-screen-symbolic.svg').is_file())

    def test_corrupt_or_missing_icon_is_refused(self):
        icon = self.theme / "scalable/apps/firefox.svg"
        icon.write_bytes(icon.read_bytes() + b"broken")
        with self.assertRaisesRegex(ValueError, "Integridade"):
            ICONS.validate_theme(self.theme)
        icon.unlink()
        with self.assertRaisesRegex(ValueError, "Integridade"):
            ICONS.validate_theme(self.theme)

    def test_active_svg_is_refused_even_with_correct_checksum(self):
        name = "scalable/apps/firefox.svg"
        path = self.theme / name
        path.write_text(path.read_text().replace("</svg>", '<script>alert(1)</script></svg>'), encoding="utf-8")
        self.checksum(name)
        with self.assertRaisesRegex(ValueError, "Elemento SVG"):
            ICONS.validate_theme(self.theme)

    def test_external_reference_is_refused_even_with_correct_checksum(self):
        name = "scalable/apps/firefox.svg"
        path = self.theme / name
        path.write_text(path.read_text().replace('<circle ', '<circle fill="url(file:///tmp/foreign)" ', 1)
                        .replace('fill="#fff4d7"', '', 1), encoding="utf-8")
        self.checksum(name)
        with self.assertRaisesRegex(ValueError, "externo"):
            ICONS.validate_theme(self.theme)

    def test_changed_alias_with_valid_checksum_is_refused(self):
        name = "scalable/apps/org.mozilla.firefox.svg"
        path = self.theme / name
        path.write_bytes(path.read_bytes().replace(b"#319e9a", b"#279963"))
        self.checksum(name)
        with self.assertRaisesRegex(ValueError, "Alias"):
            ICONS.validate_theme(self.theme)

    def test_incomplete_fallback_is_refused(self):
        name = "index.theme"
        path = self.theme / name
        path.write_text(path.read_text().replace("Adwaita,hicolor", "hicolor"), encoding="utf-8")
        self.checksum(name)
        with self.assertRaisesRegex(ValueError, "fallback"):
            ICONS.validate_theme(self.theme)

    def test_manifest_cannot_traverse_or_omit_files(self):
        manifest = self.theme / "SHA256SUMS"
        original = manifest.read_text()
        manifest.write_text(original + "0" * 64 + "  ../outside.svg\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Caminho"):
            ICONS.validate_theme(self.theme)
        manifest.write_text("\n".join(original.splitlines()[1:]) + "\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "incompleto"):
            ICONS.validate_theme(self.theme)


if __name__ == "__main__":
    unittest.main()
