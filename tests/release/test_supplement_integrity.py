import contextlib,io,json,sys,tempfile,unittest,hashlib
from pathlib import Path
from unittest.mock import patch
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
import import_client as importer
class SupplementTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
  buffer=io.BytesIO();Image.new('RGBA',(2,2),'red').save(buffer,format='PNG');self.raw=buffer.getvalue()
  (self.root/'frames.pngpack').write_bytes(self.raw)
  self.data={'format_version':1,'base_resource_version':'2.0.1.11','pack_sha256':hashlib.sha256(self.raw).hexdigest(),'frames':{'smtiles':{'1':[0,len(self.raw),2,2,0,0]}},'audio':{}}
  self.save()
 def save(self):(self.root/'manifest.json').write_text(json.dumps(self.data))
 def test_valid(self):importer.validate_supplement(self.root,True)
 def test_missing_and_malformed_catalogs(self):
  original=json.loads(json.dumps(self.data))
  for field in ('frames','audio'):
   for value in (None,[],False,'bad'):
    with self.subTest(field=field,value=value):
     self.data=json.loads(json.dumps(original));self.data[field]=value;self.save()
     with self.assertRaisesRegex(ValueError,field+'.*manifest.json'):importer.validate_supplement(self.root,True)
   self.data=json.loads(json.dumps(original));del self.data[field];self.save()
   with self.assertRaisesRegex(ValueError,field):importer.validate_supplement(self.root,True)
 def test_invalid_nested_records_are_located(self):
  self.data['frames']['smtiles']=None;self.save()
  with self.assertRaisesRegex(ValueError,'smtiles'):importer.validate_supplement(self.root,True)
  self.data['frames']['smtiles']={'1':None};self.save()
  with self.assertRaisesRegex(ValueError,'smtiles:1'):importer.validate_supplement(self.root,True)
  self.data['frames']={};self.data['audio']={'test.wav':None};self.save()
  with self.assertRaisesRegex(ValueError,'test.wav'):importer.validate_supplement(self.root,True)
 def test_missing_required(self):
  with self.assertRaises(ValueError):importer.validate_supplement(self.root/'absent',True)
 def test_optional_absent(self):importer.validate_supplement(self.root/'absent')
 def test_damaged_pack(self):
  (self.root/'frames.pngpack').write_bytes(b'bad')
  with self.assertRaisesRegex(ValueError,'校验'):importer.validate_supplement(self.root,True)
 def test_wrong_dimensions(self):
  self.data['frames']['smtiles']['1'][2]=3;self.save()
  with self.assertRaisesRegex(ValueError,'无法解码'):importer.validate_supplement(self.root,True)
 def test_out_of_bounds(self):
  self.data['frames']['smtiles']['1'][0]=999;self.save()
  with self.assertRaisesRegex(ValueError,'索引'):importer.validate_supplement(self.root,True)
 def test_verify_failure_does_not_touch_cache(self):
  status=self.root/'reports';cache=self.root/'existing';cache.mkdir();(cache/'preserve').write_bytes(b'original')
  with patch.object(importer,'validate',side_effect=ValueError('broken cache')),contextlib.redirect_stderr(io.StringIO()):self.assertEqual(importer.verify_cached(cache,status),1)
  self.assertEqual((cache/'preserve').read_bytes(),b'original');self.assertEqual(json.loads((status/'import-status.json').read_text())['state'],'error')
 def test_verify_retry_replaces_stale_error_status(self):
  status=self.root/'status';cache=self.root/'existing';base=cache/'client2011';base.mkdir(parents=True)
  (base/'manifest.json').write_text(json.dumps({'supplements':[]}))
  sentinel=cache/'preserve';sentinel.write_bytes(b'original')
  with patch.object(importer,'validate',side_effect=ValueError('broken cache')),contextlib.redirect_stderr(io.StringIO()):
   self.assertEqual(importer.verify_cached(cache,status),1)
  self.assertEqual(json.loads((status/'import-status.json').read_text())['state'],'error')
  with patch.object(importer,'validate'):
   self.assertEqual(importer.verify_cached(cache,status),0)
  report=json.loads((status/'import-status.json').read_text())
  self.assertEqual(report,{'state':'ready','root':str(cache.resolve())})
  self.assertFalse((status/'import-status.tmp').exists())
  self.assertEqual(sentinel.read_bytes(),b'original')
if __name__=='__main__':unittest.main()
