"""Decoders for the supplied 2.0.1.11 client. No source files are modified.

Format reference: Suprcode/Crystal WeMadeLibrary.cs and Crystal.MapEditor MapCode.cs.
PNG packets preserve original frame indexes/offsets, with no generated artwork.
"""
import io
import mmap
import struct
import zlib
from pathlib import Path
from PIL import Image


class WilLibrary:
    def __init__(self, path):
        self.path = Path(path)
        self.file = self.path.open('rb')
        self.data = mmap.mmap(self.file.fileno(), 0, access=mmap.ACCESS_READ)
        self.alias = None
        siblings = {p.name.lower(): p for p in self.path.parent.iterdir()}
        key = self.path.with_suffix('.wix').name.lower()
        index = siblings.get(key)
        if index is None and self.path.stem.lower() == 'deco':
            index = siblings.get('deco..wix')
            self.alias = 'Deco..wix -> Deco.wix (read-only lookup)'
        if index is None:
            raise ValueError(f'Missing index: {key}')
        idx = index.read_bytes()
        self.kind = 'raw'
        self.header_size = 8
        self.palette = None
        if self.data[:10] == b'#ILIB v1.0' or (self.data[:26] == b'\x19WEMADE Entertainment inc.' and struct.unpack_from('<I', self.data, 48)[0] == 256):
            self.palette_count = struct.unpack_from('<I', self.data, 48)[0]
            self.version = struct.unpack_from('<I', self.data, 56)[0]
            start = 48 if self.version == 0 else 52
            self.header_size = 8 if self.version == 0 else 12
            if self.palette_count == 256:
                pos = 56 if self.version == 0 else 60
                self.palette = [self.data[pos+i*4+j] for i in range(256) for j in (2, 1, 0)]
            elif self.palette_count != 65536:
                raise ValueError(f'Unsupported palette {self.palette_count}: {path}')
        elif self.data[:26] == b'\x19WEMADE Entertainment inc.':
            self.kind = 'compressed16'
            start = 52
            self.header_size = 16
        else:
            raise ValueError(f'Unsupported WIL header: {path}')
        if (len(idx)-start) % 4:
            raise ValueError(f'Invalid WIX length: {index}')
        self.offsets = struct.unpack_from('<'+'I'*((len(idx)-start)//4), idx, start)
        ordered = sorted(set(o for o in self.offsets if o)) + [len(self.data)]
        self.ends = dict(zip(ordered, ordered[1:]))

    def close(self):
        self.data.close()
        self.file.close()

    def image(self, frame):
        if frame < 0 or frame >= len(self.offsets):
            raise IndexError(frame)
        o = self.offsets[frame]
        if o == 0:
            return None
        if o + self.header_size > len(self.data):
            raise ValueError(f'Frame {frame}: address outside library')
        w, h, x, y = struct.unpack_from('<hhhh', self.data, o)
        if w == 0 or h == 0:
            return None
        if not (0 < w <= 4096 and 0 < h <= 4096):
            raise ValueError(f'Frame {frame}: invalid dimensions {w}x{h}')
        raw = self.data[o+self.header_size:self.ends[o]]
        if self.kind == 'compressed16':
            n = struct.unpack_from('<I', self.data, o+12)[0]
            if n < 6:
                return None
            if len(raw) < n:
                raise ValueError(f'Frame {frame}: truncated compressed body')
            raw = zlib.decompress(raw[6:n], -15) if raw[0] == 8 else raw[6:n]
        bpp = 1 if self.palette is not None else 2
        packed = w*bpp
        stride = ((packed+3)//4)*4
        # Old image banks may use tightly packed rows or DWORD-aligned rows.
        if len(raw) < stride*h:
            stride = packed
        if len(raw) < stride*h:
            raise ValueError(f'Frame {frame}: truncated pixels')
        if bpp == 1:
            im = Image.frombytes('P', (w,h), raw[:stride*h], 'raw', 'P', stride, -1)
            im.putpalette(self.palette)
            im.info['transparency'] = 0
            return im.convert('RGBA'), (x,y)
        # Pillow's BGR;16 decoder is RGB565 little endian.
        im = Image.frombytes('RGB', (w,h), raw[:stride*h], 'raw', 'BGR;16', stride, -1).convert('RGBA')
        import numpy as np
        pixels = np.asarray(im).copy()
        pixels[:,:,3] = ((pixels[:,:,:3] != 0).any(axis=2)*255).astype('uint8')
        return Image.fromarray(pixels), (x,y)


def read_map(path):
    import numpy as np
    data = Path(path).read_bytes()
    if len(data) < 52:
        raise ValueError('Map shorter than header')
    w,h = struct.unpack_from('<HH', data)
    if not (0 < w <= 4096 and 0 < h <= 4096):
        raise ValueError(f'Invalid map size {w}x{h}')
    extended = data[4] == 15 and data[18:20] == b'\r\n'
    stride = 14 if extended else 12
    needed = 52+w*h*stride
    if len(data) < needed:
        raise ValueError(f'Map truncated: need {needed}, got {len(data)}')
    cells = np.frombuffer(data, dtype='uint8', count=w*h*stride, offset=52).reshape(w,h,stride).transpose(1,0,2).copy()
    back = cells[:,:,0].astype('uint16') | (cells[:,:,1].astype('uint16') << 8)
    front = cells[:,:,4].astype('uint16') | (cells[:,:,5].astype('uint16') << 8)
    walk = ((back & 0x8000)==0) & ((front & 0x8000)==0)
    return {'width':w, 'height':h, 'stride':stride, 'cells':cells, 'walk':walk,
            'trailing_bytes':len(data)-needed, 'format':'mir2_14' if extended else 'mir2_12'}


class WisLibrary:
    """WISA trailing index with 8/16-bit literal/run packets.

    Layout checked against public 2009 TWis notes, plus supplied type 2/3 data.
    Type 3 has an EEFFEEFF size envelope and 16-bit run counts/values.
    """
    def __init__(self, path):
        self.path=Path(path);self.file=self.path.open('rb')
        self.data=mmap.mmap(self.file.fileno(),0,access=mmap.ACCESS_READ)
        if self.data[:4]!=b'WISA':raise ValueError('Unsupported WIS signature')
        offset,size,reserved=struct.unpack_from('<III',self.data,len(self.data)-12)
        start=offset+size
        if start<512 or start>len(self.data) or (len(self.data)-start)%12:raise ValueError('Invalid WIS index')
        self.entries=list(struct.iter_unpack('<III',self.data[start:]))
        self.offsets=[v[0] for v in self.entries]
        self.kind='wis_rle8_16';self.alias=None
        palette_source=next(p for p in self.path.parent.iterdir() if p.name.lower()=='hum.wil')
        palette=palette_source.read_bytes()[56:1080]
        self.palette=[palette[i*4+j] for i in range(256) for j in (2,1,0)]
        for off,size,_ in self.entries:
            if off<512 or size<12 or off+size>start:raise ValueError('WIS image address out of bounds')

    def close(self):
        self.data.close();self.file.close()

    def image(self, frame):
        o,n,_=self.entries[frame]
        flag=self.data[o];w,h,x,y=struct.unpack_from('<hhhh',self.data,o+4)
        if not w or not h:return None
        if not (0<w<=4096 and 0<h<=4096):raise ValueError('Invalid WIS dimensions')
        raw=self.data[o+12:o+n];bpp=2 if flag in (2,3) else 1
        if flag not in (0,1,2,3):raise ValueError(f'Unsupported WIS flag {flag}')
        if flag==3:
            if len(raw)<12 or raw[:4]!=b'\xee\xff\xee\xff':raise ValueError('Invalid WIS16 envelope')
            decoded,encoded=struct.unpack_from('<II',raw,4)
            if decoded!=w*h*2 or encoded!=len(raw):raise ValueError('WIS16 size mismatch')
            packet_count=struct.unpack_from('<I',raw,12)[0]
            raw=raw[16:]
        if flag in (1,3):
            result=bytearray();p=0;maximum=w*h*bpp
            packet=0
            while p<len(raw) and (packet<packet_count if flag==3 else len(result)<maximum):
                packet+=1
                if p+2*bpp>len(raw):raise ValueError('Truncated WIS run header')
                count=int.from_bytes(raw[p:p+bpp],'little');p+=bpp
                if count:
                    pixel=raw[p:p+bpp];p+=bpp
                    if len(result)+count*bpp>maximum and not (flag==3 and packet==packet_count):raise ValueError('WIS run overflow')
                    result.extend(pixel*count)
                else:
                    count=int.from_bytes(raw[p:p+bpp],'little');p+=bpp
                    if count==0 or p+count*bpp>len(raw) or (len(result)+count*bpp>maximum and not (flag==3 and packet==packet_count)):raise ValueError('Invalid WIS literal run')
                    result.extend(raw[p:p+count*bpp]);p+=count*bpp
            if flag==3:
                if packet!=packet_count or p!=len(raw) or len(result)<maximum:raise ValueError('WIS16 packet count mismatch')
                # The writer includes a final look-ahead packet after the pixel extent.
                result=result[:maximum]
            if len(result)!=maximum:raise ValueError('WIS decoded pixel count mismatch')
            raw=bytes(result)
        if len(raw)!=w*h*bpp:raise ValueError('WIS raw pixel count mismatch')
        if bpp==1:
            im=Image.frombytes('P',(w,h),raw)
            im.putpalette(self.palette);im.info['transparency']=0
            return im.convert('RGBA'),(x,y)
        import numpy as np
        im=Image.frombytes('RGB',(w,h),raw,'raw','BGR;16').convert('RGBA')
        a=np.asarray(im).copy();a[:,:,3]=((a[:,:,:3]!=0).any(axis=2)*255).astype('uint8')
        return Image.fromarray(a),(x,y)
