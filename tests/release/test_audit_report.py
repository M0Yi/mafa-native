"""Exercise the actual Godot audit entry; skip explicitly when no engine is configured."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(os.environ.get('MAFA_GODOT', ROOT / '.cache/godot/Godot.app/Contents/MacOS/Godot'))

@unittest.skipUnless(GODOT.is_file(), 'Set MAFA_GODOT to run native audit-entry checks')
class AuditReportTests(unittest.TestCase):
    def run_audit(self, directory, output):
        return subprocess.run(
            [str(GODOT), '--headless', '--path', str(ROOT / 'game'),
             '--log-file', str(directory / 'engine.log'), '--', '--audit-output=' + str(output)],
            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=20,
        )

    def test_missing_output_parent_fails_explicitly(self):
        with tempfile.TemporaryDirectory(prefix='mafa-audit-write-') as tmp:
            directory = Path(tmp)
            result = self.run_audit(directory, directory / 'absent/report.json')
            self.assertEqual(result.returncode, 1)
            self.assertIn('无法写入发布审计报告', result.stderr)
            self.assertNotIn('SCRIPT ERROR', result.stderr)
            self.assertFalse((directory / 'absent/report.json').exists())

    def test_writable_output_and_exit_agree(self):
        with tempfile.TemporaryDirectory(prefix='mafa-audit-write-') as tmp:
            directory = Path(tmp)
            output = directory / 'report.json'
            result = self.run_audit(directory, output)
            report = json.loads(output.read_text(encoding='utf-8'))
            self.assertEqual(result.returncode, 0 if report['code_only'] else 1)
            self.assertNotIn('SCRIPT ERROR', result.stderr)
