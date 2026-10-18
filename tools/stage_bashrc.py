#!/usr/bin/env python3
"""Add exactly one Juno source block without evaluating or rewriting user code."""

from pathlib import Path
import sys

BEGIN = b"# >>> Juno Desktop: Oh My Posh >>>"
END = b"# <<< Juno Desktop: Oh My Posh <<<"
BLOCK = b'''# >>> Juno Desktop: Oh My Posh >>>
if [[ $- == *i* && ${TERM:-dumb} != dumb && ${TERM:-dumb} != linux ]]; then
    if [[ -r "$HOME/.config/juno-gnome/shell/bash.sh" ]]; then
        source "$HOME/.config/juno-gnome/shell/bash.sh"
    fi
fi
# <<< Juno Desktop: Oh My Posh <<<
'''


def stage(content: bytes) -> bytes:
    """Preserve bytes outside the one delimited, whole-line block."""
    if b"\0" in content:
        raise ValueError("rc contém byte NUL")
    lines = content.splitlines(keepends=True)
    begins = [i for i, line in enumerate(lines) if line.rstrip(b"\r\n") == BEGIN]
    ends = [i for i, line in enumerate(lines) if line.rstrip(b"\r\n") == END]
    # Also reject misspelled/incomplete delimiters instead of appending another block.
    if content.count(BEGIN) != len(begins) or content.count(END) != len(ends):
        raise ValueError("marcador Juno não ocupa uma linha completa")
    if not begins and not ends:
        return content + (b"\n" if content and not content.endswith(b"\n") else b"") + BLOCK
    if len(begins) != 1 or len(ends) != 1 or begins[0] >= ends[0]:
        raise ValueError("marcadores Juno incompletos, repetidos ou fora de ordem")
    return b"".join(lines[:begins[0]]) + BLOCK + b"".join(lines[ends[0] + 1:])


def main() -> int:
    if len(sys.argv) != 3:
        print("Uso: stage_bashrc.py ENTRADA SAÍDA", file=sys.stderr)
        return 2
    source, output = map(Path, sys.argv[1:])
    try:
        content = source.read_bytes() if source.exists() else b""
        output.write_bytes(stage(content))
    except (OSError, ValueError) as exc:
        print(f"Bash rc recusado: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
