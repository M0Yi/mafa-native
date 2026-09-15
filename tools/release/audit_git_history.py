"""Read-only audit of reachable Git history for client assets and save signatures."""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FORBIDDEN = {'.wil', '.wix', '.wis', '.wzl', '.wzx', '.uib', '.wav', '.pngpack', '.mapbin', '.walk', '.map', '.sqlite', '.db', '.login'}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def audit():
    commits = git('rev-list', '--all').decode().splitlines()
    blobs = {}
    findings = []
    for commit in commits:
        for entry in git('ls-tree', '-r', '-z', commit).split(b'\0'):
            if not entry:
                continue
            meta, raw_path = entry.split(b'\t', 1)
            mode, kind, oid = meta.decode().split()
            path = raw_path.decode('utf-8', errors='replace')
            if kind != 'blob':
                findings.append({'commit': commit, 'path': path, 'reason': 'non-blob tree entry requires review'})
                continue
            blobs.setdefault(oid, set()).add(path)
            parts = Path(path).parts
            if Path(path).suffix.lower() in FORBIDDEN or any(p in {'.cache', 'assets', 'artifacts', 'mirgo'} for p in parts):
                findings.append({'commit': commit, 'path': path, 'reason': 'forbidden asset/save path'})
    for oid, paths in blobs.items():
        data = git('cat-file', 'blob', oid)
        signature = None
        if data.startswith(b'SQLite format 3\0'):
            signature = 'SQLite database'
        elif data.startswith(b'RIFF') and data[8:12] == b'WAVE':
            signature = 'WAV audio'
        elif data.startswith(b'M211'):
            signature = 'converted map'
        if signature:
            findings.append({'blob': oid, 'paths': sorted(paths), 'reason': signature})
    return {'scope': 'all locally reachable commits; paths and SQLite/WAV/M211 magic. Not remote unreachable objects, secret scan, license review or renamed proprietary image detection', 'commits': commits, 'unique_blobs': len(blobs), 'findings': findings}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'commits': len(report['commits']), 'blobs': report['unique_blobs'], 'findings': len(report['findings'])}))
    raise SystemExit(bool(report['findings']))
