import importlib.util,json,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from convert_client2011 import child
from import_client import validate
class ImportTests(unittest.TestCase):
 def test_case_insensitive_directories(self):
  with tempfile.TemporaryDirectory() as raw:
   p=Path(raw);(p/'dAtA').mkdir();self.assertEqual(child(p,'Data').name,'dAtA')
 def test_missing_directory(self):
  with tempfile.TemporaryDirectory() as raw:
   with self.assertRaises(ValueError):child(Path(raw),'Map')
 def test_reject_wrong_client(self):
  with tempfile.TemporaryDirectory() as raw:
   p=Path(raw);(p/'manifest.json').write_text('{"resource_version":"wrong"}');(p/'maps.json').write_text('{"maps":[]}')
   with self.assertRaises(ValueError):validate(p)
 def test_source_free_export_presets(self):
  s=(ROOT/'game/export_presets.cfg').read_text(encoding='utf-8')
  self.assertEqual(s.count('exclude_filter="assets/*'),3)
  self.assertNotIn('*.pngpack',s)
 def test_platform_libraries(self):
  for platform,extension in [('windows','dll'),('linux','so')]:
   for mode in ['debug','release']:
    self.assertTrue((ROOT/f'game/addons/godot-sqlite/bin/libgdsqlite.{platform}.template_{mode}.x86_64.{extension}').is_file())
if __name__=='__main__':unittest.main()
