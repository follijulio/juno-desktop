#!/usr/bin/env python3
"""Organiza os wallpapers fornecidos sem alterar seus pixels e gera o catálogo."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "wallpapers"
FORMATS = {".png", ".jpg", ".jpeg", ".webp", ".avif"}
RENAMES = {
    "1198712-3840x2160-desktop-4k-studio-ghibli-wallpaper.jpg": "ghibli-ilha.jpg",
    "1365276.jpeg": "ghibli-pintora.jpeg", "1374980.jpg": "ghibli-jardim.jpg",
    "1581970671ee0b86d2e127f776eaaa97d77e078e41.jpg": "socrates-vitoria.jpg",
    "1850570_7.jpg": "armadura-em-combate.jpg",
    "black-hole-event-7680x4320-10324.jpg": "buraco-negro-orbita.jpg",
    "blackhole-7680x4320-ai-upscaled-to-8k-v0-y4s1t6uphg991.webp": "buraco-negro-roxo.webp",
    "Captura de tela 2026-03-18 101150.png": "rdr-acampamento.png",
    "Captura de tela 2026-07-26 144532.png": "rdr-cavaleiro.png",
    "Captura de tela 2026-07-26 144816.png": "rdr-retrato.png",
    "Captura de tela 2026-07-26 144833.png": "rdr-montanhas.png",
    "cat.png": "gato-vermelho.png",
    "d715048e77b4511d958feb2dc754a39ce07fef0f.jpg": "mecha-no-horizonte.jpg",
    "desing(1).png": "lenin.png", "desing.png": "che-guevara.png",
    "Ghibli inspiration by Camile Sule.jpg": "ghibli-ruinas.jpg",
    "ghibli-peaceful-valley-landscape-desktop-wallpaper-4k.jpg": "ghibli-vale.jpg",
    "ImmyjIH.jpeg": "ghibli-lago.jpeg",
    "Instagram halloween icon pink practical icon ideas.jpg": "gato-espiral.jpg",
    "j7stVW.jpg": "buraco-negro-luz.jpg",
    "socrates-comemorando-gol-pelo-corinthians-1613756247465_v2_4x3.jpg": "socrates-campo.jpg",
    "Spirited-Away-1242023.png": "chihiro-na-chuva.png",
    "studio-ghibli-3840x2160-18315.jpg": "ghibli-reflexo.jpg",
    "UmZUS1k.png": "castelo-ambulante.png", "wallpaper.avif": "abstrato-azul.avif",
    "wallpaper.jpg": "ghibli-vale-copia.jpg", "wallpaper1.jpg": "ondas-azuis.jpg",
    "wallpaper2.avif": "folhas-azuis.avif",
    "wallpaperflare.com_wallpaper.jpg": "frieren-editorial.jpg",
    "wp7147395.png": "ghibli-girassois.png", "y4s1t6uphg991.jpg": "buraco-negro-roxo.jpg",
}
LABELS = {
    "ghibli-vale": "Ghibli · Vale tranquilo", "ghibli-ilha": "Ghibli · Ilha ao vento",
    "ghibli-pintora": "Ghibli · Pintora", "ghibli-jardim": "Ghibli · Jardim",
    "ghibli-lago": "Ghibli · Lago", "ghibli-ruinas": "Ghibli · Ruínas",
    "ghibli-reflexo": "Ghibli · Reflexo", "ghibli-girassois": "Ghibli · Girassóis",
    "chihiro-na-chuva": "Chihiro · Chuva", "castelo-ambulante": "Castelo ambulante",
    "juno-paper": "Juno · Papel editorial",
}


def slug(name: str) -> str:
    plain = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", plain).strip("-") or "wallpaper"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rename", action="store_true", help="Aplica nomes legíveis aos arquivos originais.")
    parser.add_argument("--check", action="store_true", help="Confere catálogo/checksums sem escrever.")
    args = parser.parse_args()
    if args.rename and args.check:
        parser.error("--rename e --check não podem ser combinados")
    if DIRECTORY.is_symlink() or not DIRECTORY.is_dir():
        raise ValueError("A pasta wallpapers deve ser um diretório real.")
    if args.rename:
        for original, renamed in RENAMES.items():
            path, target = DIRECTORY / original, DIRECTORY / renamed
            if not path.exists():
                continue
            if path.is_symlink() or target.exists() or target.is_symlink():
                raise ValueError(f"Renomeação insegura ou destino existente: {original}")
            path.rename(target)
    images = sorted((p for p in DIRECTORY.iterdir() if p.suffix.lower() in FORMATS),
                    key=lambda p: (p.stem.endswith("-copia"), p.name))
    catalog, seen, ids, hashes = [], set(), set(), []
    for path in images:
        if path.is_symlink() or not path.is_file() or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*\.(png|jpg|jpeg|webp|avif)", path.name):
            raise ValueError(f"Nome inválido ou link: {path.name}. Use nomes minúsculos sem espaços.")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes.append(f"{digest}  {path.name}\n")
        if digest in seen:
            continue  # Preserve o arquivo duplicado; mostre a imagem uma vez no seletor.
        seen.add(digest)
        identifier = slug(path.stem)
        if identifier in ids:
            identifier += "-" + path.suffix[1:]
        if identifier in ids:
            raise ValueError(f"ID repetido: {identifier}")
        ids.add(identifier)
        catalog.append({"id": identifier, "name": LABELS.get(identifier, path.stem.replace("-", " ").capitalize()), "file": path.name})
    payload = json.dumps({"version": 1, "default": "ghibli-vale", "wallpapers": catalog}, ensure_ascii=False, indent=2) + "\n"
    if not any(entry["id"] == "ghibli-vale" for entry in catalog):
        raise ValueError("O wallpaper padrão ghibli-vale.jpg está ausente.")
    sums = "".join(hashes) + hashlib.sha256(payload.encode()).hexdigest() + "  catalog.json\n"
    if args.check:
        if (DIRECTORY / "catalog.json").read_text(encoding="utf-8") != payload or (DIRECTORY / "SHA256SUMS").read_text(encoding="utf-8") != sums:
            raise ValueError("Catálogo/checksums desatualizados. Execute tools/catalog_wallpapers.py.")
    else:
        (DIRECTORY / "catalog.json").write_text(payload, encoding="utf-8", newline="\n")
        (DIRECTORY / "SHA256SUMS").write_text(sums, encoding="utf-8", newline="\n")
    print(f"Galeria: {len(images)} arquivos, {len(catalog)} imagens únicas; pixels originais preservados.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from None
