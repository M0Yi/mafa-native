#!/usr/bin/env python3
"""Cross-platform source launcher; never exports or installs."""
import os,shutil,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
candidates=[os.environ.get('GODOT'),root/'.cache/godot/Godot.app/Contents/MacOS/Godot',shutil.which('godot'),shutil.which('godot4')]
engine=next((str(p) for p in candidates if p and Path(p).is_file()),None)
if not engine:raise SystemExit('Install Godot 4.7.2 and set GODOT to its executable path.')
env=os.environ.copy()
python=root/('.cache/venv/Scripts/python.exe' if os.name=='nt' else '.cache/venv/bin/python')
env.setdefault('MAFA_PYTHON',str(python) if python.exists() else sys.executable)
raise SystemExit(subprocess.call([engine,'--path',str(root/'game'),*sys.argv[1:]],env=env))
