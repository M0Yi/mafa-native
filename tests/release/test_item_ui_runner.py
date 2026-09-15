import importlib.util
from pathlib import Path
import unittest
import tempfile
import json
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('item_ui_runner', Path(__file__).resolve().parents[2] / 'tools/check_item_ui_closeout.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class ItemUIRunnerTests(unittest.TestCase):
    def test_logs_use_utf8_independent_of_host_locale(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); engine = root / 'godot'; engine.write_text('placeholder')
            def process(command, **kwargs):
                self.assertEqual(kwargs['encoding'], 'utf-8')
                self.assertEqual(kwargs['errors'], 'replace')
                return runner.subprocess.CompletedProcess(command, 0, 'PASS: 中文提示\n', '')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'CASES', {'sample': ['PASS: 中文提示']}), patch.object(runner, 'source_fingerprint', return_value='fixture'), patch('sys.argv', ['check', '--godot', str(engine)]), patch.object(runner.subprocess, 'run', side_effect=process):
                self.assertEqual(runner.main(), 0)
            output = root / 'artifacts/item-ui-closeout'
            self.assertEqual((output / 'sample.log').read_bytes(), 'PASS: 中文提示\n'.encode('utf-8'))
            self.assertTrue(json.loads((output / 'report.json').read_text(encoding='utf-8'))['results'][0]['functional_pass'])

    def test_launch_failure_replaces_previous_success_report(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            engine = root / 'godot'
            engine.write_text('placeholder')
            output = root / 'artifacts/item-ui-closeout'
            output.mkdir(parents=True)
            (output / 'report.json').write_text('{"results": [{"functional_pass": true}]}')
            with patch.object(runner, 'ROOT', root), patch.object(runner, 'CASES', {'sample': ['PASS']}), patch.object(runner, 'source_fingerprint', return_value='fixture'), patch('sys.argv', ['check', '--godot', str(engine)]), patch.object(runner.subprocess, 'run', side_effect=PermissionError('permission denied')):
                self.assertEqual(runner.main(), 1)
            report = json.loads((output / 'report.json').read_text())
            self.assertEqual(report['results'][0]['exit'], 'launch_error')
            self.assertFalse(report['results'][0]['functional_pass'])
            self.assertIn('permission denied', (output / 'sample.log').read_text())

    def test_fingerprint_detects_script_edits_and_removal(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            script = root / 'game/scripts/sample.gd'
            script.parent.mkdir(parents=True)
            script.write_text('extends Node')
            initial = runner.source_fingerprint(root)
            self.assertEqual(initial, runner.source_fingerprint(root))
            script.write_text('extends Control')
            changed = runner.source_fingerprint(root)
            self.assertNotEqual(initial, changed)
            script.unlink()
            self.assertNotEqual(changed, runner.source_fingerprint(root))

    def test_pass_marker_does_not_hide_engine_error(self):
        log = 'PASS: selected stack\nERROR: Failed to load resource\nSCRIPT ERROR: Invalid call'
        self.assertEqual(len(runner.unexpected_errors('split_selection_closeout_test', log)), 2)

    def test_readonly_is_only_expected_in_fault_cases(self):
        log = 'ERROR:  --> SQL error: attempt to write a readonly database'
        self.assertEqual(runner.unexpected_errors('split_selection_closeout_test', log), [])
        self.assertEqual(runner.unexpected_errors('item_use_feedback_closeout_test', log), [log])

    def test_page_fault_injection_allowlist(self):
        log = 'ERROR:  --> SQL error: attempt to write a readonly database'
        self.assertEqual(runner.unexpected_errors('skill_bind_failure_test', log), [])
        self.assertEqual(runner.unexpected_errors('warehouse_distance_closeout_test', log), [log])

    def test_startup_faults_require_clean_teardown(self):
        for case, message in [('store_open_failure_closeout_test', 'injected initialization failure'), ('store_entry_failure_closeout_test', 'injected entry failure')]:
            log = 'ERROR:  --> SQL error: ' + message
            self.assertEqual(runner.unexpected_errors(case, log), [])
            self.assertEqual(runner.unexpected_errors('warehouse_distance_closeout_test', log), [log])
            for leaked in ['WARNING: 2 ObjectDB instances were leaked at exit', 'WARNING: 1 RID of type "CanvasItem" was leaked.', 'ERROR: 2 resources still in use at exit (run with --verbose for details).']:
                self.assertEqual(runner.unexpected_errors(case, 'PASS: startup\n' + leaked), [leaked])

    def test_registered_page_scripts_exist(self):
        root = Path(__file__).resolve().parents[2]
        for name, markers in {**runner.CASES, **runner.PAGE_CASES, **runner.RESOURCE_CASES}.items():
            source = (root / 'game/tests2011' / (name + '.gd')).read_text()
            for marker in markers:
                self.assertIn(marker, source)

    def test_other_sql_failure_is_not_allowed(self):
        log = 'ERROR:  --> SQL error: database disk image is malformed'
        self.assertEqual(runner.unexpected_errors('split_selection_closeout_test', log), [log])

    def test_resource_diagnostic_is_not_confused_with_load_failure(self):
        self.assertEqual(runner.unexpected_errors('split_selection_closeout_test', 'ERROR: 2 resources still in use at exit (run with --verbose for details).'), [])
        self.assertTrue(runner.unexpected_errors('split_selection_closeout_test', 'ERROR: resources unavailable'))

if __name__ == '__main__':
    unittest.main()
