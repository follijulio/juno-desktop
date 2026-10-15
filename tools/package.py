#!/usr/bin/env python3
"""Empacota a distribuição com LF e permissões POSIX, também a partir do Windows."""
from __future__ import annotations

import gzip
import hashlib
import io
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "dist"
EXCLUDED = {".git", ".cache", "dist", "__pycache__"}


def main() -> None:
    OUT.mkdir(exist_ok=True)
    archive = OUT / "juno-desktop.tar.gz"
    with archive.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as bundle:
            for path in sorted(ROOT.rglob("*")):
                relative = path.relative_to(ROOT)
                if any(part in EXCLUDED for part in relative.parts) or not path.is_file():
                    continue
                if path.is_symlink():
                    raise ValueError(f"Link simbólico inesperado: {relative}")
                data = path.read_bytes()
                if path.suffix not in {".ttf", ".png"}:
                    data = data.replace(b"\r\n", b"\n")
                entry = tarfile.TarInfo(f"juno-desktop/{relative.as_posix()}")
                entry.size = len(data)
                entry.mode = 0o755 if path.suffix in {".sh", ".py"} or "config/juno/bin" in relative.as_posix() else 0o644
                entry.mtime = 0
                entry.uid = entry.gid = 0
                entry.uname = entry.gname = ""
                bundle.addfile(entry, io.BytesIO(data))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (OUT / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n", encoding="utf-8", newline="\n")
    print(f"Distribuição: {archive}")
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    main()
