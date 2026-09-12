"""Read-only WZL/WZX decoder. Format: Crystal WeMadeLibrary (16-byte header).
Only verified 8-bit palette and RGB565 records are decoded; other tags are errors.
"""
import mmap,struct,zlib
from pathlib import Path
from PIL import Image
import numpy as np
class WzlLibrary:
 def __init__(self,path,palette):
  self.path=Path(path);siblings={p.name.lower():p for p in self.path.parent.iterdir()}
  self.index=siblings[self.path.with_suffix('.wzx').name.lower()];idx=self.index.read_bytes()
  if len(idx)<48 or (len(idx)-48)%4:raise ValueError('Invalid WZX extent')
  self.declared=struct.unpack_from('<I',idx,44)[0]
  self.offsets=struct.unpack_from('<'+'I'*((len(idx)-48)//4),idx,48)
  self.file=self.path.open('rb');self.data=mmap.mmap(self.file.fileno(),0,access=mmap.ACCESS_READ);self.palette=palette
  self.ends={a:b for a,b in zip(sorted(set(o for o in self.offsets if o)),sorted(set(o for o in self.offsets if o))[1:]+[len(self.data)])}
 def close(self):self.data.close();self.file.close()
 def image(self,index):
  if not 0<=index<len(self.offsets):raise IndexError(index)
  off=self.offsets[index]
  if off==0:return None
  if off<48 or off+16>len(self.data):raise ValueError('WZL offset out of bounds')
  tag,compressed=struct.unpack_from('<BB',self.data,off);w,h,x,y,size=struct.unpack_from('<hhhhI',self.data,off+4)
  if w==0 or h==0:return None
  if not 0<w<=4096 or not 0<h<=4096:raise ValueError('Invalid dimensions')
  if tag not in (3,5) or compressed not in (0,1):raise ValueError(f'Unsupported WZL format {tag}/{compressed}')
  bpp=1 if tag==3 else 2;stride=(w*bpp+3)//4*4;expected=stride*h
  n=size if compressed else expected
  if off+16+n>self.ends[off]:raise ValueError('Truncated WZL payload')
  raw=self.data[off+16:off+16+n]
  if compressed:
   stream=zlib.decompressobj();raw=stream.decompress(raw,expected+1)
   if not stream.eof or stream.unused_data or stream.unconsumed_tail:raise ValueError('Invalid or oversized zlib stream')
  if len(raw)!=expected:raise ValueError(f'Pixel extent mismatch: {len(raw)} != {expected}')
  if tag==3:
   im=Image.frombytes('P',(w,h),raw,'raw','P',stride,-1);im.putpalette(self.palette);im.info['transparency']=0;im=im.convert('RGBA')
  else:
   im=Image.frombytes('RGB',(w,h),raw,'raw','BGR;16',stride,-1).convert('RGBA');pixels=np.asarray(im).copy();pixels[:,:,3]=np.any(pixels[:,:,:3]!=0,axis=2)*255;im=Image.fromarray(pixels)
  return im,(x,y)
