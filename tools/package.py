#!/usr/bin/env python3
"""Empacota a distribuição com LF e permissões POSIX, também a partir do Windows."""
from __future__ import annotations

import gzip
import hashlib
import io
import os
from pathlib import Path
import shutil
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist"
EXCLUDED = {".git", ".cache", "dist", "__pycache__"}
BINARY = {".ttf", ".png", ".jpg", ".jpeg", ".webp", ".avif", ".gif", ".ico"}


def package(root: Path, out: Path) -> tuple[Path, str]:
    """Prepare o pacote inteiro antes de substituir uma distribuição existente."""
    archive = out / "juno-desktop.tar.gz"
    checksums = out / "SHA256SUMS"
    for destination in (out, archive, checksums):
        if destination.is_symlink():
            raise ValueError(f"Destino não pode ser link simbólico: {destination}")
    for destination in (archive, checksums):
        if destination.exists() and not destination.is_file():
            raise ValueError(f"Destino precisa ser arquivo regular: {destination}")
    paths = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        # Diretórios e links quebrados também precisam ser recusados.
        if path.is_symlink():
            raise ValueError(f"Link simbólico inesperado: {relative}")
        if any(part in EXCLUDED for part in relative.parts):
            continue
        if path.is_file():
            paths.append((path, relative))
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".juno-package-", dir=out) as directory:
        prepared = Path(directory)
        staged_archive = prepared / archive.name
        staged_checksums = prepared / checksums.name
        with staged_archive.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as bundle:
                for path, relative in paths:
                    data = path.read_bytes()
                    if path.suffix.lower() not in BINARY:
                        data = data.replace(b"\r\n", b"\n")
                    entry = tarfile.TarInfo(f"juno-desktop/{relative.as_posix()}")
                    entry.size = len(data)
                    executable = path.suffix.lower() in {".sh", ".py"} or (
                        len(relative.parts) >= 4 and relative.parts[0] == "config" and
                        relative.parts[1] in {"juno", "juno-gnome"} and relative.parts[2] == "bin")
                    entry.mode = 0o755 if executable else 0o644
                    entry.mtime = 0
                    entry.uid = entry.gid = 0
                    entry.uname = entry.gname = ""
                    bundle.addfile(entry, io.BytesIO(data))
        digest = hashlib.sha256(staged_archive.read_bytes()).hexdigest()
        staged_checksums.write_text(f"{digest}  {archive.name}\n", encoding="utf-8", newline="\n")
        # Reabrir e ler todos os membros detecta erros antes da publicação.
        with tarfile.open(staged_archive, "r:gz") as bundle:
            members = bundle.getmembers()
            expected = [f"juno-desktop/{relative.as_posix()}" for _, relative in paths]
            if [member.name for member in members] != expected:
                raise ValueError("Conteúdo do pacote preparado não corresponde às entradas")
            for member in members:
                stream = bundle.extractfile(member)
                if not member.isfile() or stream is None or len(stream.read()) != member.size:
                    raise ValueError(f"Membro inválido no pacote preparado: {member.name}")
        if staged_checksums.read_text(encoding="utf-8") != f"{digest}  {archive.name}\n":
            raise ValueError("Checksum preparado inválido")
        previous_archive = prepared / "previous.tar.gz"
        had_archive = archive.exists()
        if had_archive:
            shutil.copyfile(archive, previous_archive)
        os.replace(staged_archive, archive)
        try:
            os.replace(staged_checksums, checksums)
        except OSError:
            if had_archive:
                os.replace(previous_archive, archive)
            else:
                archive.unlink()
            raise
    return archive, digest


def main() -> None:
    archive, digest = package(ROOT, OUT)
    print(f"Distribuição: {archive}")
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    main()
