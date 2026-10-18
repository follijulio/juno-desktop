import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("stage_bashrc", ROOT / "tools/stage_bashrc.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BashRcTests(unittest.TestCase):
    def test_new_and_repeated_installation(self):
        result = module.stage(b"")
        self.assertEqual(result.count(module.BEGIN), 1)
        self.assertEqual(result, module.stage(result))

    def test_preserves_customizations_without_evaluation(self):
        original = b"# configuracao do usuario\nexport EDITOR=vim\nPS1='custom $ '\nprintf hostile > /never-execute"
        result = module.stage(original)
        self.assertTrue(result.startswith(original + b"\n"))
        self.assertEqual(result, module.stage(result))

    def test_preserves_bytes_before_and_after_existing_block(self):
        before, after = b"# antes \xff\r\n", b"# depois\nexport CUSTOM=yes\n"
        original = before + module.BEGIN + b"\nold hook\n" + module.END + b"\n" + after
        self.assertEqual(module.stage(original), before + module.BLOCK + after)

    def test_rejects_ambiguous_or_incomplete_markers(self):
        for content in (module.BEGIN, module.END, module.END + b"\n" + module.BEGIN,
                        module.BLOCK + module.BLOCK, b"echo " + module.BEGIN, b"a\0b"):
            with self.subTest(content=content), self.assertRaises(ValueError):
                module.stage(content)

    def test_failed_cli_does_not_replace_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, target = Path(directory) / "rc", Path(directory) / "stage"
            source.write_bytes(module.BEGIN)
            target.write_bytes(b"keep")
            result = subprocess.run([sys.executable, str(ROOT / "tools/stage_bashrc.py"),
                                     str(source), str(target)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()
