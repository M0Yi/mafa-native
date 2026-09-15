import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('run_dev', Path(__file__).resolve().parents[2] / 'tools/run_dev.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

class DevLauncherTests(unittest.TestCase):
    def test_each_platform_cache(self):
        for system, relative in [('Darwin', 'Godot.app/Contents/MacOS/Godot'), ('Windows', 'Godot_v4.7.2-stable_win64.exe'), ('Linux', 'Godot_v4.7.2-stable_linux.x86_64')]:
            with self.subTest(system=system), tempfile.TemporaryDirectory(prefix='mafa launcher ') as folder, patch.dict(os.environ, {}, clear=True):
                root = Path(folder)
                expected = root / '.cache/ci-godot' / relative
                expected.parent.mkdir(parents=True)
                expected.touch()
                self.assertEqual(launcher.find_engine(root, system), str(expected))
    def test_explicit_missing_override_is_not_silently_ignored(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'GODOT': folder + '/missing'}):
            with self.assertRaises(SystemExit):
                launcher.find_engine(Path(folder))

    def test_launches_source_with_arguments_and_preserves_exit_code(self):
        root = Path(launcher.__file__).resolve().parents[1]
        with patch.object(launcher, 'find_engine', return_value='/tmp/引擎 folder/Godot'), patch.object(launcher.subprocess, 'call', return_value=7) as call, patch.object(launcher.sys, 'argv', ['run_dev.py', '--headless', '--log-file', '/tmp/log folder/run.log']), patch.dict(os.environ, {'MAFA_PYTHON': '/tmp/python folder/python'}, clear=True):
            self.assertEqual(launcher.main(), 7)
        command = call.call_args.args[0]
        self.assertEqual(command, ['/tmp/引擎 folder/Godot', '--path', str(root / 'game'), '--headless', '--log-file', '/tmp/log folder/run.log'])
        self.assertEqual(call.call_args.kwargs['env']['MAFA_PYTHON'], '/tmp/python folder/python')
        self.assertNotIn('shell', call.call_args.kwargs)

    def test_missing_local_python_uses_current_interpreter(self):
        with patch.object(launcher, 'find_engine', return_value='/tmp/Godot'), patch.object(launcher.subprocess, 'call', return_value=0) as call, patch.object(launcher.sys, 'argv', ['run_dev.py']), patch.object(launcher.Path, 'exists', return_value=False), patch.dict(os.environ, {}, clear=True):
            self.assertEqual(launcher.main(), 0)
        self.assertEqual(call.call_args.kwargs['env']['MAFA_PYTHON'], launcher.sys.executable)

    def test_unlaunchable_engine_reports_path_without_traceback(self):
        import io
        for failure in [PermissionError('permission denied'), FileNotFoundError('engine disappeared')]:
            with self.subTest(failure=type(failure).__name__), patch.object(launcher, 'find_engine', return_value='/tmp/引擎 folder/Godot'), patch.object(launcher.subprocess, 'call', side_effect=failure), patch.object(launcher.sys, 'stderr', new_callable=io.StringIO) as output:
                self.assertEqual(launcher.main(), 1)
                self.assertIn('/tmp/引擎 folder/Godot', output.getvalue())
                self.assertIn(str(failure), output.getvalue())
                self.assertNotIn('Traceback', output.getvalue())
