"""Browser preferences are additive, deterministic and never evaluated."""
import importlib.util
from pathlib import Path
import unittest
import configparser

spec = importlib.util.spec_from_file_location("mimeapps", Path(__file__).resolve().parents[1] / "tools/stage_mimeapps.py")
mime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mime)


class MimeTests(unittest.TestCase):
    def test_merge_preserves_comments_other_apps_and_is_idempotent(self):
        source = '# keep\n[Default Applications]\ntext/plain=editor.desktop;\nx-scheme-handler/https=brave-browser.desktop;\n[Added Associations]\ntext/html=other.desktop;\n'
        merged = mime.merge(source, "org.mozilla.firefox.desktop")
        self.assertIn('# keep\n', merged)
        self.assertIn('text/plain=editor.desktop;\n', merged)
        self.assertIn('[Added Associations]\ntext/html=other.desktop;\n', merged)
        self.assertIn('x-scheme-handler/https=org.mozilla.firefox.desktop;\n', merged)
        self.assertEqual(mime.merge(merged, "org.mozilla.firefox.desktop"), merged)

    def test_missing_section_and_final_newline(self):
        for source in ('', '# comment', '[Added Associations]\ntext/plain=editor.desktop;'):
            merged = mime.merge(source, 'firefox.desktop')
            self.assertEqual(merged.count('[Default Applications]'), 1)
            self.assertIn('text/html=firefox.desktop;\n', merged)
            self.assertEqual(mime.merge(merged, 'firefox.desktop'), merged)

    def test_invalid_or_ambiguous_input_is_rejected(self):
        for source in ('invalid', '[Default Applications]\ntext/html=a\ntext/html=b\n', '[Default Applications]\n[Default Applications]\n'):
            with self.assertRaises(configparser.Error):
                mime.merge(source, 'firefox.desktop')
        with self.assertRaises(ValueError):
            mime.merge('', '../foreign.desktop')


if __name__ == '__main__':
    unittest.main()
