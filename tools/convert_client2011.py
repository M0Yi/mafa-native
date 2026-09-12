#!/usr/bin/env python3
"""Build read-only source catalogs, PNG packets and row-major map data for 2.0.1.11."""
import argparse
import concurrent.futures
import hashlib
import io
import json
import shutil
import struct
from pathlib import Path
import numpy as np
from PIL import Image
from client2011_formats import WilLibrary, WisLibrary, read_map

ROOT = Path(__file__).resolve().parents[1]
DECODER_SHA256 = 'client2011-decoder-v1-external'


def child(parent, name):
    matches=[p for p in parent.iterdir() if p.name.casefold()==name.casefold()]
    if len(matches)!=1:raise ValueError(f'Missing or ambiguous entry: {parent / name}')
    return matches[0]


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')


def library_job(args):
    source, output = map(Path, args)
    name = source.stem.lower()+('_wis' if source.suffix.lower()=='.wis' else '')
    stamp = hashlib.sha256(source.read_bytes()).hexdigest()
    dependencies = {}
    if source.suffix.lower()=='.wil':
        candidates=[p for p in source.parent.iterdir() if p.name.lower() in {source.stem.lower()+'.wix', 'deco..wix' if source.stem.lower()=='deco' else ''}]
    else:
        candidates=[p for p in source.parent.iterdir() if p.name.lower()=='hum.wil']
    for p in candidates:dependencies[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
    record = output/(name+'.json')
    if record.exists():
        old = json.loads(record.read_text(encoding='utf-8'))
        if old.get('sha256') == stamp and old.get('decoder_sha256')==DECODER_SHA256 and old.get('dependencies')==dependencies and old.get('converter') == 1 and (output/(name+'.pngpack')).exists():
            return name, old.get('decoded',0), len(old.get('errors',[])), 'cached'
    lib = WisLibrary(source) if source.suffix.lower()=='.wis' else WilLibrary(source)
    indexes = []
    errors = []
    count = 0
    with (output/(name+'.pngpack.tmp')).open('wb') as pack:
        for i in range(len(lib.offsets)):
            try:
                decoded = lib.image(i)
                if decoded is None:
                    indexes.append([])
                    continue
                im,(x,y) = decoded
                buf = io.BytesIO()
                im.save(buf, format='PNG', compress_level=1)
                raw = buf.getvalue()
                indexes.append([pack.tell(),len(raw),im.width,im.height,x,y])
                pack.write(raw)
                count += 1
            except Exception as error:
                indexes.append([])
                errors.append({'frame':i,'error':str(error)})
    (output/(name+'.pngpack.tmp')).replace(output/(name+'.pngpack'))
    save(record, {'converter':1,'source':source.name,'sha256':stamp,'frames':indexes,
                  'decoded':count,'errors':errors,'index_alias':lib.alias,'kind':lib.kind,
                  'decoder_sha256':DECODER_SHA256,'dependencies':dependencies,
                  'pack_sha256':hashlib.sha256((output/(name+'.pngpack')).read_bytes()).hexdigest()})
    lib.close()
    return name,count,len(errors),'converted'


def build_maps(source, output):
    from collections import deque
    maps=[]
    for p in sorted((p for p in child(source,'Map').iterdir() if p.suffix.lower()=='.map'), key=lambda p:p.name.lower()):
        mid=p.stem.lower()
        m=read_map(p)
        w,h=m['width'],m['height']
        walk=m['walk']
        # Boundary is never a spawn or a walk-through exit.
        walk[0,:]=False;walk[-1,:]=False;walk[:,0]=False;walk[:,-1]=False
        preferred={'0':(min(w-2,330),min(h-2,270)),'3':(min(w-2,305),min(h-2,316))}.get(mid,(w//2,h//2))
        ys,xs=np.where(walk)
        if len(xs)==0:
            maps.append({'id':mid,'source':p.name,'status':'no_walkable_cells','width':w,'height':h})
            continue
        distances=(xs-preferred[0])**2+(ys-preferred[1])**2
        first=int(np.argmin(distances));sx,sy=int(xs[first]),int(ys[first])
        # Find a reachable local service area without inventing source collisions.
        region={(sx,sy)};queue=deque([(sx,sy)])
        while queue and len(region)<1200:
            x,y=queue.popleft()
            for px,py in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
                if 0<=px<w and 0<=py<h and walk[py,px] and (px,py) not in region:
                    region.add((px,py));queue.append((px,py))
        spots=sorted(region,key=lambda xy:((xy[0]-sx)**2+(xy[1]-sy)**2,xy[1],xy[0]))
        dest=output/(mid+'.mapbin')
        dest.write_bytes(b'M211'+struct.pack('<HHI',w,h,m['stride'])+m['cells'].tobytes())
        (output/(mid+'.walk')).write_bytes(walk.astype('uint8').tobytes())
        name={'0':'比奇省','3':'盟重省'}.get(mid,'探索区域 · '+p.stem)
        maps.append({'id':mid,'name':name,'source':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                     'width':w,'height':h,'stride':m['stride'],'format':m['format'],
                     'trailing_bytes':m['trailing_bytes'],'spawn':[sx,sy],
                     'service_spots':[list(spots[min(i,len(spots)-1)]) for i in [10,25,50,80,120,200]],
                     'walkable_count':len(xs),'local_connected_count':len(region),
                     'provenance':'source_geometry_reconstructed_content','status':'geometry_converted_content_pending'})
    save(output.parent/'maps.json',{'format_version':1,'maps':maps})
    return maps


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--jobs',type=int,default=4)
    ap.add_argument('--only',choices=['all','maps','images','audio','catalog'],default='all')
    args=ap.parse_args();source=args.source;out=args.output
    if source.resolve()==out.resolve() or source.resolve() in out.resolve().parents:
        raise SystemExit('Output must not be inside source')
    for folder in ['libraries','maps','audio','ui','catalog']:(out/folder).mkdir(parents=True,exist_ok=True)
    if args.only in ['all','maps']:
        maps=build_maps(source,out/'maps');print('Map records:',len(maps),flush=True)
    if args.only in ['all','audio']:
        audio=[]
        for p in sorted(child(source,'Wav').iterdir()):
            if p.suffix.lower()!='.wav':continue
            q=out/'audio'/p.name.lower();shutil.copyfile(p,q)
            audio.append({'file':q.name,'source':'Wav/'+p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        mapping={};missing=[]
        for line in child(child(source,'Wav'),'sound.lst').read_bytes().decode('gb18030',errors='replace').splitlines():
            parts=line.split(':',1)
            if len(parts)!=2 or not parts[0].strip().isdigit():continue
            name=parts[1].strip().replace('\\','/').split('/')[-1].lower()
            mapping[parts[0].strip()]=name
            if not (out/'audio'/name).exists():missing.append({'id':parts[0].strip(),'file':name})
        save(out/'audio.json',{'files':audio,'sound_ids':mapping,'missing_references':missing})
        print('Audio:',len(audio),'missing referenced filenames:',len(missing),flush=True)
    if args.only in ['all','images']:
        paths=sorted(child(source,'Data').iterdir())
        jobs=[(str(p),str(out/'libraries')) for p in paths if p.suffix.lower() in ('.wil','.wis')]
        with concurrent.futures.ProcessPoolExecutor(max_workers=args.jobs) as pool:
            for name,count,errors,status in pool.map(library_job,jobs):
                print(name,count,'frames',errors,'errors',status,flush=True)
        ui=[]
        for p in sorted(source.rglob('*.uib')):
            uid=p.relative_to(source).with_suffix('').as_posix().lower()
            q=out/'ui'/(uid+'.png');q.parent.mkdir(parents=True,exist_ok=True)
            try:
                with Image.open(p) as im:im.convert('RGBA').save(q)
                ui.append({'id':uid,'file':q.relative_to(out).as_posix(),'source':str(p.relative_to(source)),'status':'decoded'})
            except Exception as e:ui.append({'id':uid,'source':str(p.relative_to(source)),'status':'unsupported','error':str(e)})
        save(out/'catalog/ui.json',{'entries':ui})
    if args.only in ['all','catalog']:
        for name in ['SkillDesc.dat','ItemDesc.dat','MapDesc1.dat','QuestDesc.dat']:
            text=child(child(source,'Data'),name).read_bytes().decode('gb18030',errors='replace')
            save(out/'catalog'/(name+'.json'),{'source':'Data/'+name,'text':text})
        files=[]
        for p in sorted(source.rglob('*')):
            if p.is_file():files.append({'path':p.relative_to(source).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        save(out/'catalog/source-files.json',{'files':files})
        pending=[]
        for p in source.rglob('*.wis'):
            record=out/'libraries'/(p.stem.lower()+'_wis.json')
            result=json.loads(record.read_text(encoding='utf-8')) if record.exists() else {}
            pending.append({'path':p.relative_to(source).as_posix(),'status':'decoded' if result and not result.get('errors') else 'incomplete','errors':result.get('errors',[])})
        save(out/'catalog/pending-formats.json',{'entries':pending})
    save(out/'manifest.json',{'format_version':1,'resource_version':'2.0.1.11','source':str(source),
                             'converter_version':1,'completion':'in_progress','mixed_legacy_assets':False})


if __name__=='__main__':
    import multiprocessing
    multiprocessing.freeze_support()
    main()
