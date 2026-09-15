import contextlib,io,json,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
import import_client
class FailureTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name);self.source=self.root/'原始客户端';self.source.mkdir()
  for name in ['Data','Map','Wav']:(self.source/name).mkdir()
  (self.source/'Data/Hum.wil').write_bytes(b'fixture')
  self.output=self.root/'cache'
 def run_import(self,*extra):
  with contextlib.redirect_stderr(io.StringIO()):
   return import_client.main(['--source',str(self.source),'--output',str(self.output),*extra])
 def test_reject_output_inside_original(self):
  self.output=self.source/'cache';self.assertEqual(self.run_import(),1);self.assertFalse(self.output.exists())
 def test_reject_output_inside_supplement(self):
  supplement=self.root/'supplement';supplement.mkdir();self.output=supplement/'cache'
  self.assertEqual(self.run_import('--supplement',str(supplement)),1);self.assertFalse(self.output.exists())
 def test_output_is_file_does_not_raise(self):
  self.output.write_bytes(b'preserve');self.assertEqual(self.run_import(),1);self.assertEqual(self.output.read_bytes(),b'preserve')
 def test_failed_conversion_preserves_old_cache(self):
  self.output.mkdir();old=self.output/'old-generation';old.mkdir();(old/'sentinel').write_bytes(b'old-cache')
  (self.output/'import-status.json').write_text(json.dumps({'state':'ready','root':str(old)}))
  previous=sys.argv
  with patch.object(import_client.convert,'main',side_effect=OSError('disk full')):
   self.assertEqual(self.run_import(),1)
  self.assertIs(sys.argv,previous);self.assertEqual((old/'sentinel').read_bytes(),b'old-cache')
  report=json.loads((self.output/'import-status.json').read_text());self.assertEqual(report['state'],'error');self.assertIn('disk full',report['message'])
  self.assertEqual((self.source/'Data/Hum.wil').read_bytes(),b'fixture')
 def test_status_write_failure_does_not_raise(self):
  with patch.object(Path,'write_text',side_effect=PermissionError('read only')):
   self.assertEqual(self.run_import(),1)
 def test_retry_publishes_new_generation_only_after_validation(self):
  with patch.object(import_client.convert,'main',side_effect=ValueError('bad data')):self.assertEqual(self.run_import(),1)
  def fake_convert():
   out=Path(sys.argv[sys.argv.index('--output')+1]);out.mkdir(parents=True)
  def fake_validate(out):self.assertTrue(out.exists());self.assertEqual(json.loads((self.output/'import-status.json').read_text())['state'],'running')
  with patch.object(import_client.convert,'main',side_effect=fake_convert),patch.object(import_client,'validate',side_effect=fake_validate):self.assertEqual(self.run_import(),0)
  result=json.loads((self.output/'import-status.json').read_text());self.assertEqual(result['state'],'ready');self.assertTrue(Path(result['root']).is_dir())
 def test_missing_supplement_fails_before_conversion(self):
  with patch.object(import_client.convert,'main') as convert:
   self.assertEqual(self.run_import('--supplement',str(self.root/'absent')),1);convert.assert_not_called()
 def test_interrupted_generation_is_not_published_and_retry_is_independent(self):
  partial=[]
  def interrupt():
   out=Path(sys.argv[sys.argv.index('--output')+1]);out.mkdir(parents=True)
   (out/'partial').write_bytes(b'incomplete');partial.append(out)
   raise KeyboardInterrupt()
  previous=sys.argv
  with patch.object(import_client.convert,'main',side_effect=interrupt):
   with self.assertRaises(KeyboardInterrupt):self.run_import()
  self.assertIs(sys.argv,previous)
  self.assertEqual(json.loads((self.output/'import-status.json').read_text())['state'],'running')
  def retry():
   out=Path(sys.argv[sys.argv.index('--output')+1]);self.assertNotEqual(out,partial[0]);out.mkdir(parents=True)
  with patch.object(import_client.convert,'main',side_effect=retry),patch.object(import_client,'validate'):
   self.assertEqual(self.run_import(),0)
  report=json.loads((self.output/'import-status.json').read_text())
  self.assertEqual(report['state'],'ready');self.assertNotEqual(Path(report['root'])/'client2011',partial[0])
  self.assertEqual((partial[0]/'partial').read_bytes(),b'incomplete')
if __name__=='__main__':unittest.main()
