#!/bin/zsh
set -e
PROJECT_DIR="${0:A:h}"
export MAFA_PYTHON="$PROJECT_DIR/.cache/venv/bin/python"
exec "$PROJECT_DIR/.cache/godot/Godot.app/Contents/MacOS/Godot" --path "$PROJECT_DIR/game" "$@"
