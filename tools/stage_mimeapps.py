#!/usr/bin/env python3
"""Merge browser defaults without executing or rewriting unrelated preferences."""
import configparser
from pathlib import Path
import re
import sys


def merge(text: str, desktop: str) -> str:
    if desktop not in {"firefox.desktop", "org.mozilla.firefox.desktop"}:
        raise ValueError("Navegador não autorizado")
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string(text)
    wanted = {key: desktop + ";" for key in (
        "x-scheme-handler/http", "x-scheme-handler/https", "text/html")}
    for key in wanted:
        if parser.has_option("Default Applications", key) and "\n" in parser.get("Default Applications", key):
            raise ValueError("Associação multilinha ambígua: " + key)
    result, section, seen = [], None, set()
    found = False

    def remaining():
        return [f"{key}={value}\n" for key, value in wanted.items() if key not in seen]

    for line in text.splitlines(keepends=True):
        match = re.fullmatch(r"\s*\[([^\]]+)\]\s*", line.strip())
        if match:
            if section == "Default Applications":
                result.extend(remaining())
            section = match.group(1)
            found |= section == "Default Applications"
        key = line.split("=", 1)[0].strip() if "=" in line else None
        if section == "Default Applications" and key in wanted:
            result.append(f"{key}={wanted[key]}\n")
            seen.add(key)
        else:
            result.append(line if line.endswith("\n") else line + "\n")
    if not found:
        result.append("\n[Default Applications]\n")
    if section == "Default Applications" or not found:
        result.extend(remaining())
    return "".join(result)


if __name__ == "__main__":
    source, target, desktop = sys.argv[1:]
    try:
        path = Path(source)
        text = path.read_text(encoding="utf-8") if path.exists() else ""
        Path(target).write_text(merge(text, desktop), encoding="utf-8", newline="\n")
    except (OSError, ValueError, configparser.Error) as error:
        sys.exit(f"Associações existentes preservadas: {error}")
