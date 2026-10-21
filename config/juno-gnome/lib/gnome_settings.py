#!/usr/bin/env python3
"""Small, allowlisted GNOME settings profile and per-key transaction snapshots.

Snapshots store the explicit user value, not the effective schema default.
Only the keys below are writable; no dconf database is copied or loaded.
Version 1 snapshots retain their original six-key scope when restored.
The desired command and static validation do not require PyGObject.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path


INTERFACE = "org.gnome.desktop.interface"
BACKGROUND = "org.gnome.desktop.background"
LEGACY_PROFILE = (
    (INTERFACE, "font-name", "s", "Roboto 11"),
    (INTERFACE, "document-font-name", "s", "Roboto 11"),
    (INTERFACE, "monospace-font-name", "s", "Space Mono 11"),
    (BACKGROUND, "picture-uri", "s", None),
    (BACKGROUND, "picture-uri-dark", "s", None),
    (BACKGROUND, "picture-options", "s", "zoom"),
)
PROFILE = LEGACY_PROFILE + ((INTERFACE, "icon-theme", "s", "Juno"),)
SNAPSHOT_VERSION = 2
ALLOWED = {(schema, None, key): kind for schema, key, kind, _ in PROFILE}
ALLOWED_BY_VERSION = {
    1: {(schema, None, key): kind for schema, key, kind, _ in LEGACY_PROFILE},
    2: ALLOWED,
}


class SettingsError(Exception):
    """An invalid snapshot, missing schema, or failed backend operation."""


class Difference(Exception):
    """A valid comparison whose current values do not match expectations."""


def string_variant(value: str) -> str:
    # GVariant string escaping, independent of gi for dependency-free planning.
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + "'"


def desired_document(home: Path) -> dict:
    if not home.is_absolute():
        raise SettingsError("HOME precisa ser absoluto")
    wallpaper = (home / ".local/share/juno-desktop/wallpapers/gallery/ghibli-vale.jpg").as_uri()
    entries = []
    for schema, key, kind, value in PROFILE:
        entries.append({"schema": schema, "path": None, "key": key, "type": kind,
                        "value": string_variant(wallpaper if value is None else value)})
    return {"version": SNAPSHOT_VERSION, "entries": entries}


def validate_shape(document: object) -> dict:
    if not isinstance(document, dict) or set(document) != {"version", "entries"}:
        raise SettingsError("formato de snapshot inválido")
    if type(document["version"]) is not int or document["version"] not in ALLOWED_BY_VERSION:
        raise SettingsError("versão de snapshot não suportada")
    allowed = ALLOWED_BY_VERSION[document["version"]]
    entries = document["entries"]
    if not isinstance(entries, list) or len(entries) != len(allowed):
        raise SettingsError("snapshot precisa conter todas as chaves gerenciadas")
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"schema", "path", "key", "type", "value"}:
            raise SettingsError("entrada de snapshot inválida")
        if not isinstance(entry["schema"], str) or not isinstance(entry["key"], str) or entry["path"] is not None:
            raise SettingsError("schema, chave ou caminho não autorizado")
        identity = (entry["schema"], entry["path"], entry["key"])
        if identity not in allowed or identity in seen:
            raise SettingsError("chave não autorizada ou repetida")
        if entry["type"] != allowed[identity]:
            raise SettingsError("tipo de chave inesperado")
        if entry["value"] is not None and not isinstance(entry["value"], str):
            raise SettingsError("valor deve ser texto GVariant ou null")
        seen.add(identity)
    return document


def read_document(path: Path) -> dict:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise SettingsError("arquivo de snapshot inválido")
    return validate_shape(json.loads(path.read_text(encoding="utf-8")))


def write_document(path: Path, document: dict) -> None:
    validate_shape(document)
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise SettingsError("destino de snapshot inválido")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", prefix=".juno-settings.",
                                         dir=path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(document, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


class GioBackend:
    def __init__(self):
        try:
            import gi
            gi.require_version("Gio", "2.0")
            from gi.repository import Gio, GLib
        except (ImportError, ValueError) as exc:
            raise SettingsError("PyGObject/Gio ausente; instale python-gobject") from exc
        self.Gio, self.GLib = Gio, GLib
        self.errors = []
        # dconf reports some read/write failures as GLib warnings instead of
        # exceptions. A failed read must never become a null backup value.
        levels = GLib.LogLevelFlags.LEVEL_WARNING | GLib.LogLevelFlags.LEVEL_CRITICAL
        self.log_handlers = [GLib.log_set_handler(domain, levels, self._backend_log, None)
                             for domain in ("dconf", "GLib-GIO", "GLib")]
        self.backend = Gio.SettingsBackend.get_default()
        if self.backend.__gtype__.name != "DConfSettingsBackend":
            raise SettingsError("backend dconf indisponível; snapshot não pode usar valores em memória")
        self.check_health()
        self.source = Gio.SettingsSchemaSource.get_default()
        self.settings = {}
        self.schemas = {}

    def _backend_log(self, domain, level, message, user_data):
        self.errors.append(str(message))

    def check_health(self):
        if self.errors:
            raise SettingsError("falha no backend dconf: " + "; ".join(self.errors))

    def setting(self, entry):
        identity = (entry["schema"], entry["path"])
        if identity not in self.settings:
            schema = self.source.lookup(entry["schema"], True) if self.source else None
            if schema is None:
                raise SettingsError("schema GNOME ausente: " + entry["schema"])
            self.schemas[identity] = schema
            self.settings[identity] = self.Gio.Settings.new_full(schema, self.backend, entry["path"])
        schema = self.schemas[identity]
        if not schema.has_key(entry["key"]):
            raise SettingsError("chave GNOME ausente: " + entry["key"])
        return self.settings[identity], schema.get_key(entry["key"])

    def parse(self, entry):
        if entry["value"] is None:
            return None
        try:
            return self.GLib.Variant.parse(self.GLib.VariantType.new(entry["type"]), entry["value"], None, None)
        except self.GLib.Error as exc:
            raise SettingsError("GVariant inválido para " + entry["key"]) from exc

    def validate(self, entry, writable=False):
        settings, schema_key = self.setting(entry)
        if schema_key.get_value_type().dup_string() != entry["type"]:
            raise SettingsError("tipo do schema diverge do snapshot: " + entry["key"])
        value = self.parse(entry)
        if value is not None and not schema_key.range_check(value):
            raise SettingsError("valor fora da faixa permitida: " + entry["key"])
        if writable and not settings.is_writable(entry["key"]):
            raise SettingsError("chave bloqueada pelo sistema: " + entry["key"])
        self.check_health()

    def read(self, entry):
        settings, _ = self.setting(entry)
        value = settings.get_user_value(entry["key"])
        self.check_health()
        return value

    def write(self, entry):
        settings, _ = self.setting(entry)
        value = self.parse(entry)
        if value is None:
            settings.reset(entry["key"])
        elif not settings.set_value(entry["key"], value):
            raise SettingsError("falha ao gravar chave: " + entry["key"])
        self.check_health()

    def sync(self):
        self.Gio.Settings.sync()
        self.check_health()


def validate_document(document: dict, backend, writable=False) -> None:
    validate_shape(document)
    for entry in document["entries"]:
        backend.validate(entry, writable=writable)


def snapshot(document: dict, backend) -> dict:
    validate_document(document, backend)
    entries = []
    for original in document["entries"]:
        entry = dict(original)
        value = backend.read(entry)
        entry["value"] = None if value is None else value.print_(True)
        entries.append(entry)
    return {"version": document["version"], "entries": entries}


def equal_value(first, second) -> bool:
    return first is None and second is None or first is not None and second is not None and first.equal(second)


def verify(document: dict, backend) -> None:
    validate_document(document, backend)
    for entry in document["entries"]:
        if not equal_value(backend.read(entry), backend.parse(entry)):
            raise Difference("valor diferente: " + entry["schema"] + "." + entry["key"])


def recovery_check(before: dict, desired: dict, backend) -> None:
    validate_shape(before)
    validate_shape(desired)
    before_keys = {(entry["schema"], entry["path"], entry["key"]) for entry in before["entries"]}
    desired_keys = {(entry["schema"], entry["path"], entry["key"]) for entry in desired["entries"]}
    if before_keys != desired_keys:
        raise SettingsError("snapshots de recuperação têm conjuntos de chaves diferentes")
    validate_document(before, backend, writable=True)
    validate_document(desired, backend, writable=True)
    desired_entries = {(entry["schema"], entry["path"], entry["key"]): entry for entry in desired["entries"]}
    for entry in before["entries"]:
        wanted = desired_entries[(entry["schema"], entry["path"], entry["key"])]
        current = backend.read(entry)
        if not equal_value(current, backend.parse(entry)) and not equal_value(current, backend.parse(wanted)):
            raise Difference("recuperação ambígua; preserve a edição em " + entry["schema"] + "." + entry["key"])


def apply_document(document: dict, backend) -> None:
    # Validate EVERY entry before making even one write.
    validate_document(document, backend, writable=True)
    try:
        for entry in document["entries"]:
            backend.write(entry)
    finally:
        backend.sync()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("desired", "validate", "snapshot", "apply", "restore", "verify", "recovery-check"):
        sub = subparsers.add_parser(command)
        sub.add_argument("--home", type=Path, required=True)
        if command in ("desired", "snapshot"):
            sub.add_argument("--output", type=Path, required=True)
        if command in ("snapshot", "validate", "restore", "verify"):
            sub.add_argument("--input", type=Path, required=command == "restore")
        if command == "validate":
            sub.add_argument("--static", action="store_true", help="valida somente formato, sem importar Gio")
        if command == "recovery-check":
            sub.add_argument("--before", type=Path, required=True)
            sub.add_argument("--desired", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        profile = desired_document(args.home)
        if args.command == "desired":
            write_document(args.output, profile)
            return 0
        document = read_document(args.input) if getattr(args, "input", None) else profile
        if args.command == "validate" and args.static:
            validate_shape(document)
            return 0
        backend = GioBackend()
        if args.command == "validate":
            validate_document(document, backend, writable=True)
        elif args.command == "snapshot":
            write_document(args.output, snapshot(document, backend))
        elif args.command in ("apply", "restore"):
            apply_document(document, backend)
        elif args.command == "verify":
            verify(document, backend)
        elif args.command == "recovery-check":
            recovery_check(read_document(args.before), read_document(args.desired), backend)
    except Difference as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except (SettingsError, OSError, ValueError, TypeError) as exc:
        print("GNOME: " + str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
