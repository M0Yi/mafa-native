#!/usr/bin/env python3
"""Legacy entry now delegates exclusively to the resource-free release builder."""
import runpy
from pathlib import Path
if __name__=='__main__':runpy.run_path(str(Path(__file__).parent/'release/build.py'),run_name='__main__')
