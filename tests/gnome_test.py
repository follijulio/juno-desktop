"""Portable transaction checks; real Gio/dconf still needs Arch acceptance."""

import ast
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from contextlib import redirect_stderr


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("gnome_settings", ROOT / "config/juno-gnome/lib/gnome_settings.py")
gnome = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gnome)


class Variant:
    def __init__(self, value):
        self.value = value

    def equal(self, other):
        return self.value == other.value

    def print_(self, annotate):
        if type(self.value) is bool:
            return "true" if self.value else "false"
        return gnome.string_variant(self.value)


class Backend:
    def __init__(self, values=None, locked=None):
        self.values = dict(values or {})
        self.locked = locked
        self.writes = []
        self.synced = False
        self.fail_at = None

    def parse(self, entry):
        if entry["value"] is None:
            return None
        if entry["type"] == "b":
            if entry["value"] not in ("true", "false"):
                raise gnome.SettingsError("GVariant booleano inválido")
            return Variant(entry["value"] == "true")
        try:
            value = ast.literal_eval(entry["value"])
        except (ValueError, SyntaxError) as exc:
            raise gnome.SettingsError("GVariant inválido") from exc
        if not isinstance(value, str):
            raise gnome.SettingsError("tipo inválido")
        return Variant(value)

    def validate(self, entry, writable=False):
        if writable and entry["key"] == self.locked:
            raise gnome.SettingsError("chave bloqueada")
        value = self.parse(entry)
        if entry["key"] == "picture-options" and value and value.value not in ("zoom", "none", "scaled"):
            raise gnome.SettingsError("valor fora da faixa")

    def read(self, entry):
        return self.values.get((entry["schema"], entry["key"]))

    def write(self, entry):
        if self.fail_at == len(self.writes):
            raise gnome.SettingsError("gravação interrompida")
        value = self.parse(entry)
        self.values[(entry["schema"], entry["key"])] = value
        self.writes.append(copy.deepcopy(entry))

    def sync(self):
        self.synced = True


class GnomeSettingsTests(unittest.TestCase):
    def setUp(self):
        self.home = Path("C:/Users/Test Home ç") if os.name == "nt" else Path("/tmp/Test Home ç")
        self.desired = gnome.desired_document(self.home)
        self.performance = gnome.desired_document(self.home, performance=True)
        self.legacy = {"version": 1, "entries": copy.deepcopy(self.desired["entries"][:-1])}

    def test_profile_limits_and_wallpaper_uri_encoding(self):
        self.assertEqual(self.desired["version"], 2)
        self.assertEqual(len(self.desired["entries"]), 7)
        values = {entry["key"]: entry["value"] for entry in self.desired["entries"]}
        self.assertEqual(values["font-name"], "'Roboto 11'")
        self.assertEqual(values["monospace-font-name"], "'Space Mono 11'")
        self.assertEqual(values["icon-theme"], "'Juno'")
        self.assertIn("Test%20Home%20%C3%A7", values["picture-uri"])
        self.assertEqual(values["picture-uri"], values["picture-uri-dark"])

    def test_performance_profile_adds_only_boolean_animation_setting(self):
        self.assertEqual(self.performance["version"], 3)
        self.assertEqual(len(self.performance["entries"]), 8)
        self.assertEqual(self.performance["entries"][:-1], self.desired["entries"])
        self.assertEqual(self.performance["entries"][-1], {
            "schema": gnome.INTERFACE, "path": None, "key": "enable-animations", "type": "b", "value": "true"})
        gnome.validate_shape(self.performance)
        for document in (dict(self.desired, version=3), dict(self.performance, version=2)):
            with self.subTest(document=document), self.assertRaises(gnome.SettingsError):
                gnome.validate_shape(document)

    def test_rejects_unknown_missing_duplicate_type_and_path(self):
        for mutation in (lambda doc: doc["entries"].pop(),
                         lambda doc: doc["entries"].__setitem__(0, doc["entries"][1]),
                         lambda doc: doc["entries"][0].update(key="enable-animations"),
                         lambda doc: doc["entries"][0].update(type="b"),
                         lambda doc: doc["entries"][0].update(path="/org/gnome/desktop/"),
                         lambda doc: doc.update(version=3),
                         lambda doc: doc.update(version=True)):
            document = copy.deepcopy(self.desired)
            mutation(document)
            with self.subTest(document=document), self.assertRaises(gnome.SettingsError):
                gnome.validate_shape(document)

    def test_snapshot_preserves_explicit_value_and_absence(self):
        backend = Backend({(gnome.INTERFACE, "font-name"): Variant("Custom 12")})
        snapshot = gnome.snapshot(self.desired, backend)
        self.assertEqual(snapshot["entries"][0]["value"], "'Custom 12'")
        self.assertTrue(all(entry["value"] is None for entry in snapshot["entries"][1:]))
        self.assertEqual(backend.writes, [])
        gnome.apply_document(self.desired, backend)
        gnome.apply_document(snapshot, backend)
        gnome.verify(snapshot, backend)
        self.assertIsNone(backend.values[(gnome.INTERFACE, "document-font-name")])

    def test_validates_entire_profile_before_writing(self):
        for backend, document in ((Backend(locked="picture-options"), self.desired),
                                  (Backend(), copy.deepcopy(self.desired))):
            if backend.locked is None:
                next(entry for entry in document["entries"] if entry["key"] == "picture-options")["value"] = "'invalid-option'"
            with self.assertRaises(gnome.SettingsError):
                gnome.apply_document(document, backend)
            self.assertEqual(backend.writes, [])

    def test_interrupted_write_is_synced_and_recoverable(self):
        for fail_at in (2, 6):
            with self.subTest(fail_at=fail_at):
                backend = Backend({(gnome.INTERFACE, "icon-theme"): Variant("Previous Icons")})
                before = gnome.snapshot(self.desired, backend)
                backend.fail_at = fail_at
                with self.assertRaises(gnome.SettingsError):
                    gnome.apply_document(self.desired, backend)
                self.assertTrue(backend.synced)
                self.assertEqual(len(backend.writes), fail_at)
                gnome.recovery_check(before, self.desired, backend)
                backend.fail_at = None
                gnome.apply_document(before, backend)
                gnome.verify(before, backend)

    def test_recovery_rejects_concurrent_edit_before_writing(self):
        backend = Backend()
        before = gnome.snapshot(self.desired, backend)
        backend.values[(gnome.INTERFACE, "font-name")] = Variant("User edit 14")
        with self.assertRaises(gnome.Difference):
            gnome.recovery_check(before, self.desired, backend)
        self.assertEqual(backend.writes, [])

    def test_theme_backup_and_rollback_preserve_explicit_and_absent_values(self):
        for previous in (None, Variant("Custom Icons")):
            with self.subTest(previous=previous):
                backend = Backend({(gnome.INTERFACE, "icon-theme"): previous})
                before = gnome.snapshot(self.desired, backend)
                gnome.apply_document(self.desired, backend)
                self.assertEqual(backend.values[(gnome.INTERFACE, "icon-theme")].value, "Juno")
                gnome.apply_document(before, backend)
                gnome.verify(before, backend)
                self.assertTrue(gnome.equal_value(backend.values[(gnome.INTERFACE, "icon-theme")], previous))

    def test_animation_backup_and_rollback_preserve_explicit_and_absent_values(self):
        for previous in (None, Variant(True), Variant(False)):
            with self.subTest(previous=previous):
                backend = Backend({(gnome.INTERFACE, "enable-animations"): previous})
                before = gnome.snapshot(self.performance, backend)
                gnome.apply_document(self.performance, backend)
                self.assertIs(backend.values[(gnome.INTERFACE, "enable-animations")].value, True)
                gnome.apply_document(before, backend)
                gnome.verify(before, backend)
                self.assertTrue(gnome.equal_value(backend.values[(gnome.INTERFACE, "enable-animations")], previous))

    def test_old_six_and_seven_key_scope_preserve_concurrent_animation_changes(self):
        for document in (self.legacy, self.desired):
            with self.subTest(version=document["version"]):
                backend = Backend({(gnome.INTERFACE, "enable-animations"): Variant(True)})
                before = gnome.snapshot(document, backend)
                backend.fail_at = 2
                with self.assertRaises(gnome.SettingsError):
                    gnome.apply_document(document, backend)
                backend.values[(gnome.INTERFACE, "enable-animations")] = Variant(False)
                gnome.recovery_check(before, document, backend)
                backend.fail_at = None
                gnome.apply_document(before, backend)
                self.assertIs(backend.values[(gnome.INTERFACE, "enable-animations")].value, False)
                self.assertNotIn("enable-animations", {entry["key"] for entry in backend.writes})

    def test_performance_recovery_preserves_divergent_animation_value(self):
        backend = Backend()
        before = gnome.snapshot(self.performance, backend)
        backend.fail_at = 7
        with self.assertRaises(gnome.SettingsError):
            gnome.apply_document(self.performance, backend)
        backend.values[(gnome.INTERFACE, "enable-animations")] = Variant(False)
        with self.assertRaises(gnome.Difference):
            gnome.recovery_check(before, self.performance, backend)
        self.assertIs(backend.values[(gnome.INTERFACE, "enable-animations")].value, False)
        self.assertEqual(len(backend.writes), 7)

    def test_performance_validates_boolean_and_locked_animation_before_any_write(self):
        malformed = copy.deepcopy(self.performance)
        malformed["entries"][-1]["value"] = "'false'"
        for backend, document in ((Backend(), malformed), (Backend(locked="enable-animations"), self.performance)):
            with self.subTest(document=document), self.assertRaises(gnome.SettingsError):
                gnome.apply_document(document, backend)
            self.assertEqual(backend.writes, [])

    def test_legacy_restore_and_interruption_leave_icon_theme_untouched(self):
        backend = Backend({(gnome.INTERFACE, "icon-theme"): Variant("Custom Icons")})
        before = gnome.snapshot(self.legacy, backend)
        self.assertEqual(before["version"], 1)
        self.assertEqual(len(before["entries"]), 6)
        backend.fail_at = 2
        with self.assertRaises(gnome.SettingsError):
            gnome.apply_document(self.legacy, backend)
        # Icons are outside this transaction's scope, even if edited meanwhile.
        backend.values[(gnome.INTERFACE, "icon-theme")] = Variant("Edited Icons")
        gnome.recovery_check(before, self.legacy, backend)
        backend.fail_at = None
        gnome.apply_document(before, backend)
        gnome.verify(before, backend)
        self.assertEqual(backend.values[(gnome.INTERFACE, "icon-theme")].value, "Edited Icons")
        self.assertNotIn("icon-theme", {entry["key"] for entry in backend.writes})

    def test_legacy_scope_is_exact_and_new_snapshots_cannot_omit_icons(self):
        gnome.validate_shape(self.legacy)
        for document in (dict(self.legacy, version=2), dict(self.desired, version=1)):
            with self.subTest(document=document), self.assertRaises(gnome.SettingsError):
                gnome.validate_shape(document)
        invalid = copy.deepcopy(self.legacy)
        invalid["entries"][0] = copy.deepcopy(self.desired["entries"][-1])
        with self.assertRaises(gnome.SettingsError):
            gnome.validate_shape(invalid)

    def test_recovery_refuses_mixed_snapshot_scopes(self):
        backend = Backend()
        before = gnome.snapshot(self.legacy, backend)
        with self.assertRaisesRegex(gnome.SettingsError, "conjuntos de chaves"):
            gnome.recovery_check(before, self.desired, backend)
        self.assertEqual(backend.writes, [])

    def test_cli_snapshot_uses_legacy_template_scope(self):
        backend = Backend({(gnome.INTERFACE, "icon-theme"): Variant("Keep Icons")})
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "legacy.json"
            output = Path(directory) / "snapshot.json"
            gnome.write_document(template, self.legacy)
            arguments = ["snapshot", "--home", str(self.home), "--input", str(template), "--output", str(output)]
            with patch.object(gnome, "GioBackend", return_value=backend):
                self.assertEqual(gnome.main(arguments), 0)
            self.assertEqual(gnome.read_document(output), gnome.snapshot(self.legacy, backend))
        self.assertEqual(backend.writes, [])

    def test_cli_performance_flag_preserves_input_snapshot_scope(self):
        backend = Backend({(gnome.INTERFACE, "enable-animations"): Variant(True)})
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "desired.json"
            self.assertEqual(gnome.main(["desired", "--home", str(self.home), "--performance", "--output", str(output)]), 0)
            self.assertEqual(gnome.read_document(output), self.performance)
            with patch.object(gnome, "GioBackend", side_effect=AssertionError("static planning accessed Gio")):
                self.assertEqual(gnome.main(["validate", "--home", str(self.home), "--performance", "--static"]), 0)
            historical_performance = copy.deepcopy(self.performance)
            historical_performance["entries"][-1]["value"] = "false"
            for document in (self.legacy, self.desired, self.performance, historical_performance):
                template = Path(directory) / "template.json"
                gnome.write_document(template, document)
                arguments = ["snapshot", "--home", str(self.home), "--performance", "--input", str(template), "--output", str(output)]
                with patch.object(gnome, "GioBackend", return_value=backend):
                    self.assertEqual(gnome.main(arguments), 0)
                self.assertEqual(gnome.read_document(output), gnome.snapshot(document, backend))
            # Restoring a performance backup on the Arch/default profile must
            # still use the backup's original scope and boolean value.
            with patch.object(gnome, "GioBackend", return_value=backend):
                self.assertEqual(gnome.main(["restore", "--home", str(self.home), "--input", str(template)]), 0)
                gnome.verify(historical_performance, backend)
                self.assertIs(backend.values[(gnome.INTERFACE, "enable-animations")].value, False)

    def test_cli_recovers_historical_disabled_animation_journal_with_new_default(self):
        historical = copy.deepcopy(self.performance)
        historical["entries"][-1]["value"] = "false"
        backend = Backend({(gnome.INTERFACE, "enable-animations"): Variant(True)})
        before = gnome.snapshot(historical, backend)
        gnome.apply_document(historical, backend)
        self.assertIs(backend.values[(gnome.INTERFACE, "enable-animations")].value, False)
        with tempfile.TemporaryDirectory() as directory:
            before_path, desired_path = Path(directory) / "before.json", Path(directory) / "desired.json"
            gnome.write_document(before_path, before)
            gnome.write_document(desired_path, historical)
            with patch.object(gnome, "GioBackend", return_value=backend):
                self.assertEqual(gnome.main(["recovery-check", "--home", str(self.home), "--performance",
                                             "--before", str(before_path), "--desired", str(desired_path)]), 0)
                self.assertEqual(gnome.main(["restore", "--home", str(self.home), "--performance",
                                             "--input", str(before_path)]), 0)
        gnome.verify(before, backend)
        self.assertIs(backend.values[(gnome.INTERFACE, "enable-animations")].value, True)

    def test_comparison_uses_parsed_values(self):
        backend = Backend()
        gnome.apply_document(self.desired, backend)
        equivalent = copy.deepcopy(self.desired)
        equivalent["entries"][0]["value"] = '"Roboto 11"'
        gnome.verify(equivalent, backend)
        backend.values[(gnome.INTERFACE, "font-name")] = None
        with self.assertRaises(gnome.Difference):
            gnome.verify(equivalent, backend)

    def test_backend_warning_is_error_instead_of_absent_value(self):
        backend = gnome.GioBackend.__new__(gnome.GioBackend)
        backend.errors = []
        backend.setting = lambda entry: (type("Settings", (), {"get_user_value": lambda _, key: None})(), None)
        backend._backend_log("dconf", None, "database unreadable", None)
        with self.assertRaisesRegex(gnome.SettingsError, "database unreadable"):
            backend.read(self.desired["entries"][0])

    def test_memory_fallback_cannot_produce_valid_backup(self):
        glib = SimpleNamespace(LogLevelFlags=SimpleNamespace(LEVEL_WARNING=1, LEVEL_CRITICAL=2),
                               log_set_handler=lambda *args: 1)
        gio = SimpleNamespace(SettingsBackend=SimpleNamespace(get_default=lambda:
                              SimpleNamespace(__gtype__=SimpleNamespace(name="GMemorySettingsBackend"))))
        gi = SimpleNamespace(require_version=lambda *args: None)
        with patch.dict("sys.modules", {"gi": gi, "gi.repository": SimpleNamespace(Gio=gio, GLib=glib)}):
            with self.assertRaisesRegex(gnome.SettingsError, "dconf indisponível"):
                gnome.GioBackend()

    def test_cli_status_equal_different_and_backend_error(self):
        backend = Backend()
        arguments = ["verify", "--home", str(self.home)]
        with patch.object(gnome, "GioBackend", return_value=backend), redirect_stderr(io.StringIO()):
            self.assertEqual(gnome.main(arguments), 1)
            gnome.apply_document(self.desired, backend)
            self.assertEqual(gnome.main(arguments), 0)
        with patch.object(gnome, "GioBackend", side_effect=gnome.SettingsError("missing dconf")), redirect_stderr(io.StringIO()):
            self.assertEqual(gnome.main(arguments), 2)

    def test_invalid_input_does_not_replace_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot.json"
            gnome.write_document(path, self.desired)
            original = path.read_bytes()
            invalid = copy.deepcopy(self.desired)
            invalid["entries"].pop()
            with self.assertRaises(gnome.SettingsError):
                gnome.write_document(path, invalid)
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(gnome.read_document(path), self.desired)
            path.write_text(json.dumps(invalid), encoding="utf-8")
            with self.assertRaises(gnome.SettingsError):
                gnome.read_document(path)


if __name__ == "__main__":
    unittest.main()
