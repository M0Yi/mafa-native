#!/usr/bin/env python3
"""Cross-platform source launcher; never exports or installs."""
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path


def find_engine(root, system=None):
    system = system or platform.system()
    override = os.environ.get('GODOT')
    if override:
        executable = Path(override).expanduser()
        if not executable.is_file():
            raise SystemExit('GODOT points to a missing executable: ' + str(executable))
        return str(executable)
    for cache in [root / '.cache/godot', root / '.cache/ci-godot']:
        if system == 'Darwin':
            candidates = [cache / 'Godot.app/Contents/MacOS/Godot']
        else:
            pattern = 'Godot_v4.7.2-stable_win64.exe' if system == 'Windows' else 'Godot_v4.7.2-stable_linux.x86_64'
            candidates = [cache / pattern]
        for candidate in candidates:
            if candidate.is_file():
                return str(candidate)
    for command in ['godot', 'godot4']:
        executable = shutil.which(command)
        if executable:
            return executable
    raise SystemExit('Install Godot 4.7.2 and set GODOT to its executable path.')


def main():
    root = Path(__file__).resolve().parents[1]
    engine = find_engine(root)
    env = os.environ.copy()
    python = root / ('.cache/venv/Scripts/python.exe' if os.name == 'nt' else '.cache/venv/bin/python')
    env.setdefault('MAFA_PYTHON', str(python) if python.exists() else sys.executable)
    try:
        return subprocess.call([engine, '--path', str(root / 'game'), *sys.argv[1:]], env=env)
    except OSError as error:
        print(f'Unable to start Godot at {engine}: {error}. Check the executable permissions or set GODOT to a working Godot 4.7.2 executable.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
