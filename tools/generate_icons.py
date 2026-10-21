#!/usr/bin/env python3
"""Build Juno's original application icons using only Python's standard library."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets" / "icons" / "Juno"
INK = "#24343a"
PAPER = "#fff4d7"
WHITE = "#fffdf5"
BLUE = "#4269ce"
GREEN = "#279963"
TEAL = "#319e9a"
ORANGE = "#e78b45"
RED = "#db6261"
PURPLE = "#8a6bb6"
NAVY = "#3c5e80"


def path(d: str, fill: str = "none", **attributes: str) -> str:
    extras = "".join(f' {key.replace("_", "-")}="{value}"' for key, value in attributes.items())
    return f'<path d="{d}" fill="{fill}"{extras}/>'


def rect(x: float, y: float, w: float, h: float, fill: str = PAPER,
         radius: float = 2, **attributes: str) -> str:
    extras = "".join(f' {key.replace("_", "-")}="{value}"' for key, value in attributes.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}"{extras}/>'


def circle(x: float, y: float, r: float, fill: str = PAPER,
           **attributes: str) -> str:
    extras = "".join(f' {key.replace("_", "-")}="{value}"' for key, value in attributes.items())
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"{extras}/>'


def group(*parts: str, transform: str = "") -> str:
    attr = f' transform="{transform}"' if transform else ""
    return f'<g{attr}>{"".join(parts)}</g>'


def paper() -> str:
    return (path("M20 12h21l9 9v32H20z", INK, stroke="none", transform="translate(2 2)")
            + path("M18 10h21l9 9v32H18z", PAPER)
            + path("M39 10v10h9", "#e4d4b2"))


def lines(*ys: int, x: int = 24, end: int = 41) -> str:
    return "".join(path(f"M{x} {y}h{end-x}") for y in ys)


def monitor(x: int = 14, y: int = 16, w: int = 36, h: int = 27) -> str:
    return (rect(x + 2, y + 3, w, h, INK, stroke="none")
            + rect(x, y, w, h) + path(f"M{x+w/2} {y+h}v7m-8 0h16"))


def notebook() -> str:
    return (rect(18, 13, 30, 40, INK, stroke="none")
            + rect(15, 10, 30, 40) + path("M22 10v40m-10-33h6m-6 8h6m-6 8h6m-6 8h6"))


@dataclass(frozen=True)
class Icon:
    name: str
    label: str
    color: str
    drawing: str
    aliases: tuple[str, ...]
    tilt: int = -6


def icons() -> tuple[Icon, ...]:
    return (
        Icon("firefox", "Firefox", TEAL,
             circle(32, 32, 17, PAPER) + path("M21 20c7-6 18-2 21 5M17 32h29M22 44c7 5 17 1 21-5M32 15c-8 10-8 24 0 34m0-34c8 10 8 24 0 34")
             + path("M18 16l5 9-5 6c-2 13 11 19 21 12-2 10-19 12-25 1-6-10 0-18 4-20z", ORANGE)
             + path("M14 25l-1-12 10 7", ORANGE),
             ("org.mozilla.firefox", "firefox-esr"), -4),
        Icon("org.gnome.Nautilus", "Arquivos", BLUE,
             path("M13 23h17l5 6h20v22H13z", INK, stroke="none")
             + path("M10 20h17l5 6h20v23H10z", "#e8d7ad")
             + path("M10 27h42l-5 22H10z", PAPER)
             + rect(24, 32, 13, 9, BLUE, 1) + path("M28 36h5", PAPER, stroke=PAPER),
             ("system-file-manager", "nautilus")),
        Icon("kitty", "Kitty", PURPLE,
             rect(13, 18, 41, 31, INK, stroke="none") + rect(10, 15, 41, 31)
             + path("M10 23h41m-35-4h1m4 0h1m4 0h1")
             + path("M18 30l6 5-6 5m12 0h10")
             + path("M36 17v-6l5 5 5-5v6", PAPER),
             ("net.kovidgoyal.kitty",)),
        Icon("mpv", "MPV", PURPLE,
             rect(16, 14, 35, 39, INK, stroke="none") + rect(13, 11, 35, 39)
             + path("M21 12v37m20-37v37m-24-30h-3m3 9h-3m3 9h-3m33-18h-3m3 9h-3m3 9h-3")
             + path("M27 23l10 8-10 8z", PURPLE),
             ("io.mpv.Mpv",)),
        Icon("pavucontrol", "Volume", TEAL,
             rect(14, 14, 39, 39, INK, stroke="none") + rect(11, 11, 39, 39)
             + path("M21 19v23m10-23v23m10-23v23")
             + rect(17, 24, 8, 6, ORANGE, 1) + rect(27, 34, 8, 6, TEAL, 1)
             + rect(37, 20, 8, 6, BLUE, 1),
             ("org.pulseaudio.pavucontrol", "multimedia-volume-control")),
        Icon("steam", "Steam", NAVY,
             circle(39, 25, 12, INK, stroke="none", transform="translate(2 3)")
             + path("M14 37l12 6 15-12-8-10-12 13z", PAPER)
             + circle(39, 23, 12) + circle(39, 23, 7, NAVY)
             + circle(23, 39, 8) + circle(23, 39, 4, NAVY)
             + path("M11 32l12 6", "none", stroke_width="6", stroke=PAPER)
             + path("M11 29l15 7-3 7-14-7z", PAPER),
             ("com.valvesoftware.Steam",)),
        Icon("discord", "Discord", BLUE,
             path("M18 19l8-3 3 4h7l3-4 8 3 7 24-8 6-6-5H26l-6 5-8-6z", INK, stroke="none", transform="translate(1 2)")
             + path("M17 17l8-3 3 4h7l3-4 8 3 7 24-8 6-6-5H25l-6 5-8-6z", PAPER)
             + circle(25, 31, 3, INK, stroke="none") + circle(39, 31, 3, INK, stroke="none")
             + path("M24 38q8 4 16 0"),
             ("com.discordapp.Discord",)),
        Icon("spotify", "Spotify", GREEN,
             circle(34, 34, 21, INK, stroke="none") + circle(31, 31, 21)
             + path("M17 25q15-6 29 1m-26 6q13-5 24 1m-21 6q10-3 18 1", stroke_width="3"),
             ("com.spotify.Client",)),
        Icon("visual-studio-code", "VS Code", BLUE,
             paper() + path("M29 25l-6 6 6 6m8-12 6 6-6 6m-2-16-4 20", stroke_width="2.4"),
             ("code", "code-oss", "com.visualstudio.code", "vscode")),
        Icon("org.gnome.Settings", "Configurações", TEAL,
             path("M27 10h10l2 7 6 3 7-1 5 9-5 6v6l3 6-8 6-6-4-7 2-4 6-10-3v-7l-5-5-7-1V30l7-3 3-6z", INK, stroke="none", transform="translate(0 2)")
             + path("M26 8h10l2 7 6 3 7-1 5 9-5 6v6l3 6-8 6-6-4-7 2-4 6-10-3v-7l-5-5-7-1V28l7-3 3-6z", PAPER)
             + circle(31, 31, 9, TEAL) + circle(31, 31, 4),
             ("gnome-control-center", "preferences-system"), -3),
        Icon("org.gnome.Contacts", "Contatos", ORANGE,
             notebook() + circle(32, 25, 5, ORANGE)
             + path("M25 41v-3a7 7 0 0114 0v3z", ORANGE),
             ("gnome-contacts", "address-book")),
        Icon("org.gnome.Calendar", "Calendário", RED,
             rect(15, 16, 37, 37, INK, stroke="none") + rect(12, 13, 37, 37)
             + path("M12 24h37V13H12z", RED) + path("M21 9v8m19-8v8")
             + path("M20 31h3m8 0h3m8 0h1M20 38h3m8 0h3m8 0h1m-23 7h3m8 0h3", stroke_width="2.7"),
             ("gnome-calendar", "office-calendar"), -4),
        Icon("org.gnome.clocks", "Relógios", ORANGE,
             circle(33, 35, 18, INK, stroke="none") + circle(30, 32, 18)
             + path("M30 20v13l9 5m-24 9-4 5m34-5 4 5")
             + path("M11 20q3-13 14-10z", PAPER) + path("M36 10q11-3 15 10z", PAPER)
             + circle(30, 32, 2, INK, stroke="none"),
             ("gnome-clocks",)),
        Icon("org.gnome.Weather", "Tempo", BLUE,
             path("M24 9v5m-12 1 4 4m-9 8h6m33-12-4 4m-7-10v5")
             + circle(27, 26, 13, "#f8c852")
             + path("M18 49a9 9 0 010-18 13 13 0 0124-2 10 10 0 117 20z", INK, stroke="none", transform="translate(1 2)")
             + path("M16 46a9 9 0 010-18 13 13 0 0124-2 10 10 0 117 20z", PAPER),
             ("gnome-weather",), 0),
        Icon("org.gnome.Maps", "Mapas", GREEN,
             path("M11 20l14-5 14 5 14-5v35l-14 5-14-5-14 5z", INK, stroke="none", transform="translate(1 1)")
             + path("M9 17l14-5 14 5 14-5v35l-14 5-14-5-14 5z", PAPER)
             + path("M23 12v35m14-30v35M9 34l14-5 14 5 14-5", stroke="#839f7a")
             + path("M44 23c0 7-9 14-9 14s-9-7-9-14a9 9 0 1118 0z", RED) + circle(35, 23, 3, PAPER),
             ("gnome-maps",)),
        Icon("org.gnome.Music", "Música", RED,
             paper() + path("M29 37V24l13-3v14m-13-7 13-3")
             + path("M29 36c-10-3-11 7-4 7 4 0 4-3 4-7zm13-2c-10-3-11 7-4 7 4 0 4-3 4-7z", INK),
             ("gnome-music", "multimedia-player")),
        Icon("org.gnome.Totem", "Vídeos", BLUE,
             rect(12, 24, 43, 27, INK, stroke="none") + rect(9, 21, 43, 27)
             + path("M9 21l41-9 2 10-41 9z", PAPER)
             + path("M16 20l5 8m6-10 5 8m6-10 5 8M10 31h41")
             + path("M27 35l9 5-9 5z", BLUE),
             ("totem", "org.gnome.Showtime")),
        Icon("org.gnome.Photos", "Fotos", PURPLE,
             rect(12, 15, 40, 37, INK, stroke="none") + rect(9, 12, 40, 37)
             + rect(14, 17, 30, 24, "#b6d9cd", 0)
             + circle(36, 24, 4, "#f6cc61")
             + path("M14 40l10-13 8 9 5-7 7 11z", "#8da679")
             + path("M23 45h12"),
             ("gnome-photos", "org.gnome.Loupe", "org.gnome.eog", "eog")),
        Icon("org.gnome.Snapshot", "Câmera", TEAL,
             path("M14 23h9l4-7h15l4 7h9v27H14z", INK, stroke="none")
             + path("M11 20h9l4-7h15l4 7h9v27H11z", PAPER)
             + circle(32, 33, 10, TEAL) + circle(32, 33, 6, "#d4e8dd")
             + path("M43 25h4m-25-8h12"),
             ("org.gnome.Cheese", "cheese", "qv4l2", "qvidcap")),
        Icon("org.gnome.SimpleScan", "Digitalizador", GREEN,
             path("M16 29l7-15h22l7 15v21H16z", INK, stroke="none")
             + path("M13 26l7-15h22l7 15v21H13z", PAPER)
             + path("M13 26h36m-30-4h25l-5-8H23z", "#c7dfcf")
             + path("M20 34h22m-22 5h14") + circle(43, 40, 2, GREEN, stroke="none"),
             ("simple-scan",)),
        Icon("org.gnome.Calculator", "Calculadora", ORANGE,
             rect(19, 12, 31, 43, INK, stroke="none") + rect(16, 9, 31, 43)
             + rect(21, 14, 21, 10, "#c7dfcf", 1)
             + path("M22 31h3m7 0h3m7 0h1m-21 8h3m7 0h3m7 0h1m-21 8h3m7 0h3m6-10v10", stroke_width="3"),
             ("gnome-calculator", "accessories-calculator")),
        Icon("org.gnome.TextEditor", "Editor de texto", BLUE,
             paper() + lines(26, 33, 40) + path("M35 44l10-20 6 3-10 20-7 4z", "#edbd61")
             + path("M45 24l2-4 6 3-2 4z", RED) + path("M34 51l1-7 6 3z", PAPER),
             ("org.gnome.gedit", "gedit", "accessories-text-editor", "gvim")),
        Icon("org.gnome.Terminal", "Terminal", NAVY,
             rect(13, 18, 42, 32, INK, stroke="none") + rect(10, 15, 42, 32)
             + path("M10 23h42m-35-4h1m4 0h1m4 0h1M19 30l7 5-7 5m14 0h9", stroke_width="2"),
             ("org.gnome.Console", "org.gnome.Ptyxis", "utilities-terminal", "gnome-terminal")),
        Icon("org.gnome.SystemMonitor", "Monitor do sistema", GREEN,
             monitor() + path("M18 31h7l4-10 6 17 5-9h6", stroke=GREEN, stroke_width="2.3"),
             ("gnome-system-monitor", "utilities-system-monitor", "htop"), -3),
        Icon("org.gnome.DiskUtility", "Discos", NAVY,
             rect(16, 12, 35, 43, INK, stroke="none") + rect(13, 9, 35, 43)
             + circle(30, 29, 12, "#e3ddc5") + circle(30, 29, 4, PAPER)
             + path("M30 29l10 13h5", "none", stroke_width="3")
             + circle(19, 46, 1, INK, stroke="none") + circle(42, 15, 1, INK, stroke="none"),
             ("gnome-disks", "palimpsest")),
        Icon("org.gnome.FileRoller", "Compactador", ORANGE,
             rect(15, 22, 36, 31, INK, stroke="none") + rect(12, 19, 36, 31)
             + rect(9, 13, 42, 10) + path("M25 14h11v35H25z", "#e6bf75")
             + path("M25 19h6m-1 6h6m-11 6h6m-1 6h6") + rect(27, 40, 7, 6, PAPER, 1),
             ("file-roller", "utilities-file-archiver")),
        Icon("org.gnome.Characters", "Caracteres", PURPLE,
             notebook() + path("M25 39l7-18 7 18m-11-6h9", stroke_width="2.5"),
             ("gnome-characters", "accessories-character-map", "gucharmap")),
        Icon("org.gnome.Yelp", "Ajuda", BLUE,
             circle(34, 34, 21, INK, stroke="none") + circle(31, 31, 21)
             + path("M25 24c0-9 16-9 16 0 0 6-9 6-9 13", stroke_width="3")
             + circle(32, 43, 1.6, INK, stroke="none"),
             ("yelp", "help-browser")),
        Icon("org.gnome.Software", "Programas", TEAL,
             path("M18 21h29l5 30H13z", INK, stroke="none", transform="translate(1 2)")
             + path("M16 18h29l5 30H11z", PAPER) + path("M23 22v-7a8 8 0 0116 0v7")
             + path("M27 29l-5 5 5 5m10-10 5 5-5 5m-3-12-3 14", stroke_width="2"),
             ("gnome-software", "system-software-install")),
        Icon("org.gnome.Connections", "Conexões", NAVY,
             rect(11, 13, 29, 22, INK, stroke="none") + rect(8, 10, 29, 22)
             + path("M22 32v5m-7 0h14")
             + rect(30, 29, 29, 22, INK, stroke="none") + rect(27, 26, 29, 22)
             + path("M41 48v5m-7 0h14M16 20h12m-4-4 4 4-4 4m10 13h12m-8-4-4 4 4 4"),
             ("gnome-connections", "org.gnome.Boxes", "gnome-boxes"), -3),
        Icon("libreoffice-writer", "Documentos", BLUE,
             paper() + lines(28, 34, 40, 46) + path("M24 23h11", stroke_width="3"),
             ("libreoffice-startcenter", "libreoffice", "org.libreoffice.LibreOffice.writer")),
        Icon("libreoffice-calc", "Planilhas", GREEN,
             paper() + rect(23, 24, 20, 22, WHITE, 0)
             + path("M23 31h20m-20 7h20m-20 8h20M30 24v22m7-22v22")
             + path("M23 24h20v7H23z", "#b7d8b4"),
             ("org.libreoffice.LibreOffice.calc",)),
        Icon("org.gnome.Evince", "Documentos PDF", RED,
             paper() + path("M26 39c7-6 13-19 9-21-6-2-2 15 8 20 8 5 7-6-4-3-8 2-17 4-17 8 0 3 4 1 7-4z", "none", stroke=RED, stroke_width="2")
             + path("M25 47h15"),
             ("evince", "org.gnome.Papers", "xreader")),
        Icon("cmake", "CMake", GREEN,
             path("M33 11l22 39H11z", INK, stroke="none", transform="translate(0 2)")
             + path("M31 8l22 39H9z", PAPER)
             + path("M31 8v26L9 47z", "#e97b6b") + path("M31 34l22 13H9z", "#79aec8")
             + path("M31 8l22 39-22-13z", "#a5c581"),
             ("CMakeSetup", "cmake-gui"), -3),
        Icon("QtProject-qtcreator", "Qt Creator", GREEN,
             rect(13, 14, 42, 37, INK, stroke="none") + rect(10, 11, 42, 37)
             + path("M34 22c-3-6-14-5-14 7v6c0 12 15 12 15 0v-6c0-3 0-5-1-7zm-5 15 11 10M43 20v17m-4-12h9"),
             ("org.qt-project.qtcreator", "qtcreator")),
        Icon("org.gnome.Screenshot", "Captura de tela", PURPLE,
             rect(14, 14, 38, 38, INK, stroke="none") + rect(11, 11, 38, 38)
             + path("M19 25v-6h6m10 0h6v6m0 10v6h-6m-10 0h-6v-6", stroke_width="2.5")
             + path("M22 34l7-8 7 8z", "#adc6ac") + circle(36, 24, 3, "#f2c969"),
             ("gnome-screenshot", "applets-screenshooter")),
        Icon("org.gnome.Extensions", "Extensions", ORANGE,
             path("M13 15h12c-3-11 15-11 12 0h12v12c11-3 11 15 0 12v12H37c3-11-15-11-12 0H13V39c11 3 11-15 0-12z", INK, stroke="none", transform="translate(2 2)")
             + path("M11 13h12c-3-11 15-11 12 0h12v12c11-3 11 15 0 12v12H35c3-11-15-11-12 0H11V37c11 3 11-15 0-12z", PAPER),
             ("org.gnome.Shell.Extensions",), -4),
        Icon("org.gnome.Decibels", "Reprodutor de áudio", TEAL,
             rect(14, 14, 39, 39, INK, stroke="none") + rect(11, 11, 39, 39)
             + path("M18 29v5m6-14v24m7-28v32m7-25v18m6-12v6", stroke=TEAL, stroke_width="2.5")
             + path("M18 46h26", stroke="#c3b79c"),
             ("decibels",)),
        Icon("org.gnome.Epiphany", "Navegador Web", BLUE,
             circle(34, 34, 21, INK, stroke="none") + circle(31, 31, 21)
             + path("M12 24h38M11 36h40M18 45h27M31 10c-13 10-13 32 0 42m0-42c13 10 13 32 0 42M31 10v42")
             + path("M39 15l11 4-11 4 2-4z", RED),
             ("epiphany", "web-browser"), -3),
        Icon("org.gnome.Logs", "Registros", ORANGE,
             notebook() + circle(28, 21, 1.1, INK, stroke="none")
             + circle(28, 29, 1.1, INK, stroke="none") + circle(28, 37, 1.1, INK, stroke="none")
             + lines(21, 29, 37, x=33, end=40)
             + path("M34 44l8-13 8 13z", "#f4c963")
             + path("M42 36v3m0 2v.2", stroke_width="1.9"),
             ("gnome-logs",)),
        Icon("org.gnome.Tour", "Boas-vindas", BLUE,
             circle(34, 34, 20, INK, stroke="none") + circle(31, 31, 20)
             + path("M17 17l9 9m10 10 9 9m-28 0 9-9m10-10 9-9", stroke=RED, stroke_width="9", stroke_linecap="butt")
             + circle(31, 31, 11, BLUE)
             + path("M19 15q12-6 24 1m-28 26q-6-12 1-24m3 29q12 6 24-1m4-27q6 12-1 24", stroke_width="1"),
             ("gnome-tour",), -5),
        Icon("org.gnome.baobab", "Uso do disco", GREEN,
             rect(13, 13, 42, 42, INK, stroke="none") + rect(10, 10, 42, 42)
             + circle(31, 31, 16, "#d6e1be")
             + path("M31 31V15a16 16 0 0116 16z", ORANGE)
             + path("M31 31h16a16 16 0 01-24 14z", TEAL)
             + circle(31, 31, 7),
             ("baobab",)),
        Icon("org.gnome.font-viewer", "Fontes", PURPLE,
             paper() + path("M23 36l6-15 6 15m-10-5h8", stroke_width="2")
             + path("M38 32c7-4 9 1 9 4v6m0-5c-9-5-10 6-4 5l4-2M24 46h12"),
             ("gnome-font-viewer",)),
        Icon("org.gnome.tweaks", "Ajustes", PURPLE,
             rect(14, 14, 39, 39, INK, stroke="none") + rect(11, 11, 39, 39)
             + rect(18, 19, 25, 5, "#c8bdde", 2.5)
             + rect(18, 28, 25, 5, "#c8bdde", 2.5)
             + rect(18, 37, 25, 5, "#c8bdde", 2.5)
             + circle(25, 21.5, 4) + circle(36, 30.5, 4) + circle(28, 39.5, 4),
             ("gnome-tweaks", "gnome-tweak-tool")),
        Icon("gnome-color-manager", "Perfis de cor", TEAL,
             rect(14, 14, 39, 39, INK, stroke="none") + rect(11, 11, 39, 39)
             + circle(25, 26, 9, RED) + circle(36, 26, 9, "#88ae6d")
             + circle(31, 36, 9, "#7099cc") + circle(31, 29.5, 3, PAPER)
             + path("M20 46h22", stroke="#c3b79c"),
             ("org.gnome.ColorProfileViewer",)),
        Icon("preferences-system-network", "Rede", BLUE,
             path("M31 24v9H16v7m15-7h15v7", stroke=INK, stroke_width="3")
             + rect(24, 11, 18, 15, INK, stroke="none") + rect(21, 8, 18, 15)
             + rect(10, 42, 18, 15, INK, stroke="none") + rect(7, 39, 18, 15)
             + rect(40, 42, 18, 15, INK, stroke="none") + rect(37, 39, 18, 15)
             + path("M25 17h10M11 48h10m20 0h10", stroke=BLUE, stroke_width="2"),
             ("rygel", "nm-connection-editor"), -3),
        Icon("ibus-setup", "Métodos de entrada", TEAL,
             rect(10, 20, 46, 29, INK, stroke="none") + rect(7, 17, 46, 29)
             + path("M14 25h2m6 0h2m6 0h2m6 0h2m6 0h1M14 32h2m6 0h2m6 0h2m6 0h2m6 0h1M14 39h2m6 0h18m6 0h1", stroke_width="2.6"),
             ("org.freedesktop.IBus.Setup",)),
        Icon("org.freedesktop.MalcontentControl", "Controles parentais", BLUE,
             path("M33 11l20 8v16c0 13-20 23-20 23S13 48 13 35V19z", INK, stroke="none")
             + path("M30 8l20 8v16c0 13-20 23-20 23S10 45 10 32V16z", PAPER)
             + path("M24 29v-6a6 6 0 0112 0v6")
             + rect(21, 28, 18, 16, "#c4d8d4")
             + circle(30, 34, 2, INK, stroke="none") + path("M30 35v4"),
             ("malcontent-control",), -4),
        Icon("hwloc", "Topologia do hardware", GREEN,
             path("M22 10v6m10-6v6m10-6v6M22 48v6m10-6v6m10-6v6M10 22h6m-6 10h6m-6 10h6m32-20h6m-6 10h6m-6 10h6", stroke_width="2.6")
             + rect(18, 18, 34, 34, INK, stroke="none") + rect(15, 15, 34, 34)
             + path("M32 25v8H24v5m8-5h8v5")
             + rect(28, 21, 8, 7, "#a5c581", 1)
             + rect(20, 36, 8, 7, "#a5c581", 1) + rect(36, 36, 8, 7, "#a5c581", 1),
             ("lstopo",), -3),
    )


def svg(icon: Icon) -> str:
    return ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
            f"  <title>{escape(icon.label)} — Juno</title>\n"
            '  <desc>Original application icon: a cream illustration on a colored rounded tile.</desc>\n'
            f'  <rect x="4" y="6" width="56" height="56" rx="12" fill="{INK}" opacity=".2"/>\n'
            f'  <rect x="4" y="3" width="56" height="56" rx="12" fill="{icon.color}"/>\n'
            f'  <g transform="rotate({icon.tilt} 32 32)" stroke="{INK}" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round">\n'
            f"    {icon.drawing}\n"
            "  </g>\n</svg>\n")


INDEX = """[Icon Theme]
Name=Juno
Comment=Original cream illustrations on colorful rounded tiles
Inherits=Adwaita,hicolor
Directories=scalable/apps

[scalable/apps]
Size=64
Type=Scalable
MinSize=16
MaxSize=512
Context=Applications
"""

LICENSE = """Juno application icon artwork
SPDX-License-Identifier: CC0-1.0

To the extent possible under law, the Juno Desktop contributors have waived
all copyright and related or neighboring rights to this original icon artwork.
This work is published from Brazil.

This artwork is provided under the Creative Commons CC0 1.0 Universal
Public Domain Dedication, without warranty.
https://creativecommons.org/publicdomain/zero/1.0/legalcode

Application names identify the applications represented. Their names and
trademarks remain the property of their respective owners; no endorsement
is claimed. The SVG drawings are original artwork, not copied brand assets.
"""


def expected_files() -> dict[str, bytes]:
    designs = icons()
    files = {"index.theme": INDEX.encode(), "LICENSE.txt": LICENSE.encode()}
    metadata = {
        "name": "Juno application icons",
        "version": 1,
        "license": "CC0-1.0",
        "generator": "tools/generate_icons.py",
        "artwork": "Original vector drawings by Juno Desktop contributors",
        "design": "Colorful rounded tiles, cream illustrations, dark outlines and hard shadows",
        "fallback": ["Adwaita", "hicolor"],
        "icons": [],
    }
    names: set[str] = set()
    for icon in designs:
        content = svg(icon).encode("utf-8")
        icon_names = (icon.name, *icon.aliases)
        for name in icon_names:
            if name.casefold() in names or "/" in name or "\\" in name:
                raise ValueError(f"Duplicate or invalid icon name: {name}")
            names.add(name.casefold())
            files[f"scalable/apps/{name}.svg"] = content
        metadata["icons"].append({"name": icon.name, "aliases": list(icon.aliases)})
    files["source.json"] = (json.dumps(metadata, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    files["SHA256SUMS"] = "".join(
        f"{hashlib.sha256(content).hexdigest()}  {name}\n"
        for name, content in sorted(files.items())
    ).encode("utf-8")
    return files


def preview(destination: Path) -> None:
    designs = icons()
    columns, cell_w, cell_h = 6, 174, 128
    rows = (len(designs) + columns - 1) // columns
    width, height = columns * cell_w + 32, rows * cell_h + 82
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#24282a"/>',
        '<text x="24" y="33" fill="#fff4d7" font-family="sans-serif" font-size="23">Juno · application icons</text>',
        '<text x="24" y="56" fill="#bdc6c7" font-family="sans-serif" font-size="13">Original SVG artwork · previews at 64 px and 32 px</text>',
    ]
    for index, icon in enumerate(designs):
        x = 16 + (index % columns) * cell_w
        y = 76 + (index // columns) * cell_h
        body = svg(icon).split('viewBox="0 0 64 64">', 1)[1].rsplit("</svg>", 1)[0]
        parts += [
            f'<rect x="{x+2}" y="{y}" width="{cell_w-8}" height="{cell_h-8}" rx="8" fill="#2e3436"/>',
            f'<svg x="{x+15}" y="{y+10}" width="64" height="64" viewBox="0 0 64 64">{body}</svg>',
            f'<svg x="{x+104}" y="{y+26}" width="32" height="32" viewBox="0 0 64 64">{body}</svg>',
            f'<text x="{x+15}" y="{y+96}" fill="#fff4d7" font-family="sans-serif" font-size="12">{escape(icon.label)}</text>',
        ]
    parts.append("</svg>\n")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes("\n".join(parts).encode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify generated files without writing anything")
    parser.add_argument("--preview", type=Path, help="also write a visual SVG contact sheet")
    args = parser.parse_args()
    if args.check and args.preview:
        parser.error("--check cannot write a preview")
    expected = expected_files()
    if args.check:
        actual = {str(p.relative_to(DESTINATION)).replace("\\", "/")
                  for p in DESTINATION.rglob("*") if p.is_file() or p.is_symlink()}
        errors = []
        for name, content in expected.items():
            location = DESTINATION / name
            if location.is_symlink() or not location.is_file() or location.read_bytes() != content:
                errors.append(f"Missing, modified or non-regular icon resource: {name}")
        errors.extend(f"Unexpected icon resource: {name}" for name in sorted(actual - expected.keys()))
        if errors:
            print("\n".join(errors))
            return 1
        print(f"Juno icons verified: {len(icons())} designs, {len(expected)-4} SVG files")
        return 0
    for name, content in expected.items():
        location = DESTINATION / name
        if location.is_symlink():
            raise ValueError(f"Refusing to replace symbolic link: {location}")
        location.parent.mkdir(parents=True, exist_ok=True)
        location.write_bytes(content)
    if args.preview:
        preview(args.preview)
    print(f"Juno icons generated: {len(icons())} designs, {len(expected)-4} SVG files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
