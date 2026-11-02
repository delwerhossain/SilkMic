#!/bin/bash
# Retakes the README screenshots (notch panel, menu-bar popup, Settings) from the running SilkMic.
# Opens each view through silkmic:// URLs (one click on Settings is needed); only the app's own windows
# are captured, never the desktop behind them. Needs Screen Recording permission for the terminal.
set -euo pipefail
cd "$(dirname "$0")/.."
swift scripts/capture-screenshots.swift docs/screenshots dark
for f in docs/screenshots/*-dark.png; do mv "$f" "${f/-dark/}"; done
ls -la docs/screenshots
