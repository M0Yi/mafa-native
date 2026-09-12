"""Supplement only known missing references; never replace an existing base frame."""
import json,hashlib,io,shutil,struct,collections
from pathlib import Path
from client2011_formats import WilLibrary
from client16_formats import WzlLibrary
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('.');BASE=ROOT/'game/assets/client2011';OUT=ROOT/'game/assets/supplement16';AUDIT=ROOT/'artifacts/client16'
def digest(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,obj):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main(source=None,base=None,out=None,audit=None,palette_source=None,content=None):
 global SOURCE,BASE,OUT,AUDIT
 if source is not None:SOURCE=Path(source)
 if base is not None:BASE=Path(base)
 if out is not None:OUT=Path(out)
 if audit is not None:AUDIT=Path(audit)
 from convert_client2011 import child

 OUT.mkdir(parents=True,exist_ok=True);AUDIT.mkdir(parents=True,exist_ok=True)
 sources=[]
 for p in sorted(SOURCE.rglob('*')):
  if p.is_file():sources.append({'path':str(p.relative_to(SOURCE)),'bytes':p.stat().st_size,'sha256':digest(p)})
 save(AUDIT/'source-files.json',{'source':str(SOURCE),'label':'user-supplied 16th anniversary client; exact executable version absent','files':sources})
 banks={p.stem.lower():p for p in (p for p in child(SOURCE,'data').iterdir() if p.suffix.lower()=='.wzl')};inventory=[]
 for name,p in sorted(banks.items()):
  idx=next(x for x in p.parent.iterdir() if x.name.lower()==p.with_suffix('.wzx').name.lower()).read_bytes();offsets=struct.unpack_from('<'+'I'*((len(idx)-48)//4),idx,48)
  inventory.append({'bank':name,'declared':struct.unpack_from('<I',idx,44)[0],'index_entries':len(offsets),'nonzero_offsets':sum(o>0 for o in offsets),'out_of_bounds':sum(o!=0 and not(48<=o<=p.stat().st_size-16) for o in offsets)})
 save(AUDIT/'libraries.json',inventory)
 report={'maps':json.loads(Path(content or ROOT/'game/content/2011/maps.json').read_text(encoding='utf-8'))['entries'],'missing_sound_references':json.loads((BASE/'audio.json').read_text(encoding='utf-8'))['missing_references']};requests=collections.defaultdict(set)
 for m in report['maps']:
  for gap in m['missing_references']:requests[gap['library']].update(gap['indexes'])
 palette_source=Path(palette_source);palette_lib=WilLibrary(palette_source);palette=palette_lib.palette;palette_lib.close()
 manifest={'format_version':1,'base_resource_version':'2.0.1.11','source_label':'用户提供的16周年客户端','exact_client_version':'not supplied','palette_source_sha256':digest(palette_source),'frames':{},'audio':{},'sources':{},'decoder_sha256':'client16-decoder-v1-external'}
 unresolved=[];comparisons=[]
 with (OUT/'frames.pngpack.tmp').open('wb') as pack:
  for bank,indexes in requests.items():
   if bank not in banks:
    unresolved.append({'bank':bank,'indexes':sorted(indexes),'reason':'bank_absent_in_new_client'});continue
   lib=WzlLibrary(banks[bank],palette);manifest['sources'][bank]={'wzl':str(lib.path.relative_to(SOURCE)),'wzl_sha256':digest(lib.path),'wzx':str(lib.index.relative_to(SOURCE)),'wzx_sha256':digest(lib.index)}
   # Compare the complete overlapping nonblank base bank, not merely its filename.
   old_path=BASE/'libraries'/f'{bank}.json'
   if old_path.exists():
    old=json.loads(old_path.read_text(encoding='utf-8'))['frames'];checked=0;identical=0;different=0;errors=0
    with (BASE/'libraries'/f'{bank}.pngpack').open('rb') as old_pack:
     for i,f in enumerate(old):
      if not f or i>=len(lib.offsets) or not lib.offsets[i]:continue
      try:
       result=lib.image(i)
       if result is None:continue
       old_pack.seek(f[0]);from PIL import Image
       before=Image.open(io.BytesIO(old_pack.read(f[1]))).convert('RGBA');checked+=1
       if before.size==result[0].size and before.tobytes()==result[0].tobytes():identical+=1
       else:different+=1
      except Exception:errors+=1
    comparisons.append({'bank':bank,'checked':checked,'identical_pixels':identical,'different_pixels':different,'decode_errors':errors})
   for i in sorted(indexes):
    try:
     decoded=lib.image(i)
     if decoded is None:raise ValueError('empty_index_or_frame')
     im,(x,y)=decoded;buf=io.BytesIO();im.save(buf,format='PNG',compress_level=1);raw=buf.getvalue();manifest['frames'].setdefault(bank,{})[str(i)]=[pack.tell(),len(raw),im.width,im.height,x,y];pack.write(raw)
    except Exception as e:unresolved.append({'bank':bank,'index':i,'reason':str(e) if not isinstance(e,IndexError) else 'index_absent_in_new_client'})
   lib.close()
 (OUT/'frames.pngpack.tmp').replace(OUT/'frames.pngpack');manifest['pack_sha256']=digest(OUT/'frames.pngpack')
 wavs={p.name.lower():p for p in (p for p in child(SOURCE,'wav').iterdir() if p.suffix.lower()=='.wav')};missing_audio=[]
 for row in report['missing_sound_references']:
  name=row['file'].lower()
  if name in wavs:
   (OUT/'audio').mkdir(exist_ok=True);shutil.copyfile(wavs[name],OUT/'audio'/name);manifest['audio'][name]={'source':'wav/'+wavs[name].name,'sha256':digest(wavs[name])}
  else:missing_audio.append(row)
 save(OUT/'manifest.json',manifest);save(AUDIT/'compatibility.json',comparisons);save(AUDIT/'remaining.json',{'images':unresolved,'sounds':missing_audio})
 save(AUDIT/'summary.json',{'source_files':len(sources),'libraries':len(banks),'image_index_entries':sum(r['index_entries'] for r in inventory),'added_frames':sum(len(v) for v in manifest['frames'].values()),'added_wav_files':len(manifest['audio']),'unresolved_image_records':len(unresolved),'unresolved_sound_references':len(missing_audio),'status':'supplements converted; visual/runtime verification required'})
 print(json.loads((AUDIT/'summary.json').read_text(encoding='utf-8')))
if __name__=='__main__':raise SystemExit('Use import_client.py --supplement DIRECTORY')
