import sys,tempfile,unittest,json,struct,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
from import_client import validate_maps,validate_library
class IntegrityTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
  (self.root/'maps').mkdir();self.geo=self.root/'maps/0.mapbin';self.mask=self.root/'maps/0.walk'
  self.geo.write_bytes(b'M211'+struct.pack('<HHI',3,3,12)+bytes(108));self.mask.write_bytes(bytes([0,0,0,0,1,0,0,0,0]))
  self.maps=[dict(id='0',width=3,height=3,stride=12,spawn=[1,1],service_spots=[[1,1]])]
 def test_valid_map(self):validate_maps(self.root,self.maps)
 def test_original_dos_short_filename(self):
  self.geo.rename(self.root/'maps/3~1.mapbin');self.mask.rename(self.root/'maps/3~1.walk');self.maps[0]['id']='3~1'
  validate_maps(self.root,self.maps)
 def test_duplicate_id(self):
  with self.assertRaisesRegex(ValueError,'重复'):validate_maps(self.root,self.maps*2)
 def test_truncated_geometry(self):
  self.geo.write_bytes(self.geo.read_bytes()[:-1])
  with self.assertRaisesRegex(ValueError,'长度'):validate_maps(self.root,self.maps)
 def test_blocked_spawn(self):
  self.mask.write_bytes(bytes(9))
  with self.assertRaisesRegex(ValueError,'不可通行'):validate_maps(self.root,self.maps)
 def test_dimension_mismatch(self):
  self.maps[0]['width']=4
  with self.assertRaisesRegex(ValueError,'不匹配'):validate_maps(self.root,self.maps)
 def test_invalid_walk_byte(self):
  self.mask.write_bytes(bytes([0,0,0,0,2,0,0,0,0]))
  with self.assertRaisesRegex(ValueError,'损坏'):validate_maps(self.root,self.maps)
 def library(self,frame):
  pack=self.root/'tiles.pngpack';pack.write_bytes(b'abc')
  path=self.root/'tiles.json';path.write_text(json.dumps({'frames':[frame],'errors':[],'pack_sha256':hashlib.sha256(b'abc').hexdigest()}));return path
 def test_changed_pack(self):
  path=self.library([0,3,1,1,0,0]);path.with_suffix('.pngpack').write_bytes(b'abd')
  with self.assertRaisesRegex(ValueError,'校验'):validate_library(path)
 def test_out_of_range_frame(self):
  with self.assertRaisesRegex(ValueError,'越界'):validate_library(self.library([1,3,1,1,0,0]))
 def test_invalid_library_container(self):
  path=self.library([])
  for value in [None,[],{}, {'frames':None},{'frames':{}},{'frames':'broken'}]:
   with self.subTest(value=value):
    path.write_text(json.dumps(value))
    with self.assertRaisesRegex(ValueError,'frames.*tiles.json'):validate_library(path)
 def test_invalid_empty_frame_is_not_silently_skipped(self):
  for value in [None,False,0,'',{},'broken',4]:
   with self.subTest(value=value):
    with self.assertRaisesRegex(ValueError,'越界.*tiles:0'):validate_library(self.library(value))
 def test_empty_frame_and_negative_sprite_offset_are_valid(self):
  validate_library(self.library([]))
  validate_library(self.library([0,3,1,1,-24,-32]))
if __name__=='__main__':unittest.main()
