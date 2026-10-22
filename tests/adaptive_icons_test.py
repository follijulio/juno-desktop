"""Portable launcher/renderer checks, with the GI decoder replaced by a fixture."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("adaptive_icons", ROOT / "config/juno-gnome/lib/icon_theme.py")
icons = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icons)


class Renderer:
    def render(self, icon, identity):
        return icons.stylize(bytes((200, 80, 20, 255)) * 16, 4, 4, identity)


class AdaptiveIconsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "Home com espaços ç"
        self.user = self.home / ".local/share/applications"
        self.system = self.root / "system"
        self.user.mkdir(parents=True)
        self.system.mkdir()
        self.roots = [self.user, self.system]
        self.original = "# keep comment\n[Desktop Entry]\nType=Application\nName=Teste\nExec=/usr/bin/teste --argument %U\nIcon=/opt/Test App/logo.png\nMimeType=text/html;\nActions=New;\n\n[Desktop Action New]\nName=Nova\nExec=/usr/bin/teste --new\nIcon=new-icon\n"
        self.app = self.system / "teste.desktop"
        self.app.write_text(self.original, encoding="utf-8")
        self.counter = 0

    def build(self):
        self.counter += 1
        output = self.root / f"output{self.counter}"
        theme = self.root / f"theme{self.counter}"
        icons.build(self.home, self.user, output, theme, Renderer(), self.roots)
        return output, theme

    def install(self, output):
        shutil.rmtree(self.user)
        shutil.copytree(output, self.user)

    def test_absolute_and_action_icons_receive_style_and_exec_is_preserved(self):
        output, theme = self.build()
        body, meta = icons.unpack((output / "teste.desktop").read_text(encoding="utf-8"))
        self.assertEqual(icons.originals(body, meta), self.original)
        self.assertEqual(len(meta["icons"]), 2)
        for item in meta["icons"]:
            self.assertIn("Juno-Auto", item[3])
            self.assertTrue((theme / "64x64/apps" / Path(item[3]).name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n"))

    def test_reinstallation_is_byte_identical(self):
        first, theme = self.build()
        self.install(first)
        second, other = self.build()
        self.assertEqual((first / "teste.desktop").read_bytes(), (second / "teste.desktop").read_bytes())
        self.assertEqual([(p.name, p.read_bytes()) for p in sorted(theme.rglob("*.png"))], [(p.name, p.read_bytes()) for p in sorted(other.rglob("*.png"))])

    def test_vendor_update_refreshes_exec_and_icon(self):
        output, _ = self.build()
        self.install(output)
        self.app.write_text(self.original.replace("--argument", "--updated").replace("logo.png", "logo2.png"), encoding="utf-8")
        output, _ = self.build()
        body, meta = icons.unpack((output / "teste.desktop").read_text(encoding="utf-8"))
        self.assertIn("--updated", body)
        self.assertIn("logo2.png", meta["icons"][0][2])

    def test_user_customization_survives_vendor_update(self):
        output, _ = self.build()
        self.install(output)
        path = self.user / "teste.desktop"
        path.write_text(path.read_text(encoding="utf-8").replace("--argument", "--my-custom-argument"), encoding="utf-8")
        self.app.write_text(self.original.replace("--argument", "--updated"), encoding="utf-8")
        output, _ = self.build()
        body, _ = icons.unpack((output / "teste.desktop").read_text(encoding="utf-8"))
        self.assertIn("--my-custom-argument", body)
        self.assertNotIn("--updated", body)

    def test_uninstall_removes_unchanged_shadow(self):
        output, _ = self.build()
        self.install(output)
        self.app.unlink()
        output, _ = self.build()
        self.assertFalse((output / "teste.desktop").exists())

    def test_user_desktop_remains_after_original_is_removed(self):
        output, _ = self.build()
        self.install(output)
        path = self.user / "teste.desktop"
        path.write_text(path.read_text(encoding="utf-8").replace("Name=Teste", "Name=Meu app"), encoding="utf-8")
        self.app.unlink()
        output, _ = self.build()
        self.assertIn("Name=Meu app", (output / "teste.desktop").read_text(encoding="utf-8"))

    def test_new_apps_and_missing_icons_are_covered(self):
        output, _ = self.build()
        self.install(output)
        (self.system / "new.desktop").write_text("[Desktop Entry]\nName=New\nType=Application\nExec=false\n", encoding="utf-8")
        output, _ = self.build()
        self.assertIn("Icon=", (output / "new.desktop").read_text(encoding="utf-8"))
        (self.system / "Meu Aplicativo ç.desktop").write_text(self.original, encoding="utf-8")
        output, _ = self.build()
        self.assertTrue((output / "Meu Aplicativo ç.desktop").read_text(encoding="utf-8").startswith(icons.MARKER))

    def test_hidden_user_launcher_masks_system_app(self):
        (self.user / "teste.desktop").write_text("[Desktop Entry]\nHidden=true\n", encoding="utf-8")
        output, theme = self.build()
        self.assertNotIn(icons.MARKER, (output / "teste.desktop").read_text(encoding="utf-8"))
        self.assertEqual(list(theme.rglob("*.png")), [])

    def test_vendor_hiding_app_does_not_leave_visible_shadow(self):
        output, _ = self.build()
        self.install(output)
        self.app.write_text(self.original.replace("Type=Application", "Type=Application\nHidden=true"), encoding="utf-8")
        output, _ = self.build()
        self.assertFalse((output / "teste.desktop").exists())

    def test_nested_user_launcher_is_not_duplicated_at_root(self):
        nested = self.user / "custom/my.desktop"
        nested.parent.mkdir()
        nested.write_text(self.original, encoding="utf-8")
        output, _ = self.build()
        self.assertTrue((output / "custom/my.desktop").read_text(encoding="utf-8").startswith(icons.MARKER))
        self.assertFalse((output / "custom-my.desktop").exists())

    def test_exec_is_never_evaluated(self):
        sentinel = self.root / "EXECUTED"
        self.app.write_text(self.original.replace("Exec=/usr/bin/teste --argument %U", f"Exec=sh -c 'touch {sentinel}'"), encoding="utf-8")
        self.build()
        self.assertFalse(sentinel.exists())

    def test_external_svg_is_rejected_before_decoder(self):
        path = self.root / "unsafe.svg"
        path.write_text('<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.org/tracker.png"/></svg>', encoding="utf-8")
        renderer = icons.Renderer.__new__(icons.Renderer)
        renderer.base = self.root / "curated"
        class Decoder:
            calls = 0
            @classmethod
            def get_file_info(cls, path):
                cls.calls += 1
                raise AssertionError("unsafe SVG reached decoder")
        renderer.Pixbuf = type("PixbufNamespace", (), {"Pixbuf": Decoder})
        result = renderer.render(str(path), "unsafe")
        self.assertTrue(result.startswith(b"\x89PNG"))
        self.assertEqual(Decoder.calls, 0)

    def test_invalid_metadata_and_duplicate_keys_fail_before_live_writes(self):
        for text in (icons.MARKER + "not-valid-base64\n" + self.original, self.original.replace("Name=Teste", "Name=Teste\nName=Duplicate")):
            with self.subTest(text=text):
                (self.user / "teste.desktop").write_text(text, encoding="utf-8")
                with self.assertRaises(ValueError):
                    self.build()
                self.assertEqual((self.user / "teste.desktop").read_text(encoding="utf-8"), text)

    def test_style_is_deterministic_with_transparent_corners(self):
        png = Renderer().render("unknown", "teste")
        self.assertEqual(png, Renderer().render("unknown", "teste"))
        import struct
        import zlib
        length = struct.unpack(">I", png[33:37])[0]
        raw = zlib.decompress(png[41:41 + length])
        self.assertEqual(raw[1:5], b"\0\0\0\0")
        self.assertNotEqual(png, Renderer().render("unknown", "another-app"))
