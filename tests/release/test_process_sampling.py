import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sample_process', Path(__file__).resolve().parents[2] / 'tools/sample_process.py')
sampler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sampler)

class ProcessSamplingTests(unittest.TestCase):
    def sample(self, code, output='', error=''):
        with patch.object(sampler.subprocess, 'run', return_value=subprocess.CompletedProcess([], code, output, error)):
            return sampler.read_sample(123)

    def test_live_and_terminal_process(self):
        self.assertEqual(self.sample(0, ' 1024 1.5 S\n'), ['1024', '1.5', 'S'])
        self.assertIsNone(self.sample(1))
        self.assertIsNone(self.sample(0, '0 0.0 Z'))

    def test_permission_failure_is_not_completion(self):
        with self.assertRaisesRegex(RuntimeError, 'Operation not permitted'):
            self.sample(1, error='ps: Operation not permitted')
        with self.assertRaises(RuntimeError):
            self.sample(2)

    def test_unexpected_output_is_not_completion(self):
        with self.assertRaises(RuntimeError):
            self.sample(0, '')
        with self.assertRaises(RuntimeError):
            self.sample(0, '1024 1.0')
