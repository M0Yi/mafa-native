#!/usr/bin/env python3
"""Import user-owned client data locally. Never execute client EXEs or modify input."""
import argparse, json, os, sys, multiprocessing, traceback, uuid, hashlib, struct, re
from pathlib import Path
import convert_client2011 as convert


def validate_maps(root, maps):
    seen=set()
    for m in maps:
        mid=m.get('id','')
        if not isinstance(mid,str) or not re.fullmatch(r'[a-z0-9_~.-]+',mid) or mid in {'.','..'} or mid in seen:
            raise ValueError('地图 ID 重复或无效：'+str(mid))
        seen.add(mid)
        geometry=root/'maps'/f'{mid}.mapbin'; mask=root/'maps'/f'{mid}.walk'
        if not geometry.is_file() or not mask.is_file():raise ValueError('地图转换不完整：'+mid)
        with geometry.open('rb') as f:header=f.read(12)
        if len(header)!=12 or header[:4]!=b'M211':raise ValueError('地图头损坏：'+mid)
        w,h,stride=struct.unpack('<HHI',header[4:])
        if w<=2 or h<=2 or (w,h,stride)!=(m.get('width'),m.get('height'),m.get('stride')):
            raise ValueError('地图尺寸或格式不匹配：'+mid)
        if geometry.stat().st_size!=12+w*h*stride or mask.stat().st_size!=w*h:
            raise ValueError('地图或通行文件长度错误：'+mid)
        walk=mask.read_bytes()
        if not set(walk).issubset({0,1}):raise ValueError('通行数据损坏：'+mid)
        for spot in [m.get('spawn'),*m.get('service_spots',[])]:
            if not isinstance(spot,list) or len(spot)!=2 or any(type(n)!=int for n in spot):raise ValueError('落点格式错误：'+mid)
            x,y=spot
            if not (0<x<w-1 and 0<y<h-1) or not walk[y*w+x]:raise ValueError('落点不可通行：'+mid)


def validate_library(path):
    row=json.loads(path.read_text(encoding='utf-8'));pack=path.with_suffix('.pngpack')
    if not isinstance(row,dict) or not isinstance(row.get('frames'),list):
        raise ValueError('图像库 frames 必须是数组：'+str(path))
    if row.get('errors') or not pack.is_file():raise ValueError('图像库不完整：'+path.stem)
    with pack.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
    if row.get('pack_sha256')!=digest:raise ValueError('图像包校验失败：'+path.stem)
    size=pack.stat().st_size
    for index,frame in enumerate(row['frames']):
        if isinstance(frame,list) and not frame:continue
        if not isinstance(frame,list) or len(frame)!=6 or any(type(n)!=int for n in frame) or frame[0]<0 or frame[1]<=0 or frame[2]<=0 or frame[3]<=0 or frame[0]+frame[1]>size:
            raise ValueError(f'图像帧索引越界：{path.stem}:{index}')


def validate(root):
    manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    maps=json.loads((root/'maps.json').read_text(encoding='utf-8'))['maps']
    if manifest.get('resource_version')!='2.0.1.11' or len(maps)!=707:
        raise ValueError('需要配套的 2.0.1.11 十周年客户端（707 张地图）；十六周年仅作补充，不能单独替代。')
    validate_maps(root,maps)
    for bank in ['hum','chrsel','prguse','tiles','smtiles','npc']:
        if not (root/'libraries'/f'{bank}.json').is_file():raise ValueError('缺少必需图像库：'+bank)
    for path in sorted((root/'libraries').glob('*.json')):validate_library(path)
    audio=json.loads((root/'audio.json').read_text(encoding='utf-8'))
    for row in audio['files']:
        name=row['file']
        if Path(name).name!=name or '/' in name or '\\' in name:raise ValueError('声音文件名错误：'+name)
        path=root/'audio'/name
        with path.open('rb') as f:
            header=f.read(12);f.seek(0);digest=hashlib.file_digest(f,'sha256').hexdigest()
        if header[:4]!=b'RIFF' or header[8:]!=b'WAVE' or digest!=row.get('sha256'):raise ValueError('声音文件损坏：'+name)
    for filename in ['log-in-long2.wav','sellect-loop2.wav','1.wav']:
        if not (root/'audio'/filename).exists():raise ValueError('缺少必需声音：'+filename)


def validate_supplement(root, required=False):
    path=root/'manifest.json'
    if not path.is_file():
        if required:raise ValueError('缺少声明的十六周年补充包：'+str(path))
        return
    manifest=json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(manifest,dict) or manifest.get('format_version')!=1 or manifest.get('base_resource_version')!='2.0.1.11':raise ValueError('补充包版本不兼容：'+str(path))
    for field in ('frames','audio'):
        if not isinstance(manifest.get(field),dict):raise ValueError('补充包 '+field+' 必须是字典：'+str(path))
    for bank,frames in manifest['frames'].items():
        if not isinstance(frames,dict):raise ValueError('补充图像库必须是字典：'+bank+' · '+str(path))
    pack=root/'frames.pngpack'
    with pack.open('rb') as f:
        if hashlib.file_digest(f,'sha256').hexdigest()!=manifest.get('pack_sha256'):raise ValueError('补充图像包校验失败：'+str(pack))
        size=pack.stat().st_size
        from PIL import Image
        import io
        for bank,frames in manifest.get('frames',{}).items():
            for index,frame in frames.items():
                label=f'{bank}:{index}'
                if not index.isdigit() or str(int(index))!=index or not isinstance(frame,list) or len(frame)!=6 or any(type(n)!=int for n in frame) or frame[0]<0 or frame[1]<=0 or frame[0]+frame[1]>size:
                    raise ValueError('补充帧索引错误：'+label)
                f.seek(frame[0]);raw=f.read(frame[1])
                try:
                    with Image.open(io.BytesIO(raw)) as image:
                        if image.format!='PNG' or image.size!=(frame[2],frame[3]):raise ValueError('尺寸不一致')
                        image.load()
                except Exception as error:raise ValueError('补充帧无法解码：'+label) from error
    for name,row in manifest.get('audio',{}).items():
        if not isinstance(row,dict):raise ValueError('补充声音记录必须是字典：'+name)
        if Path(name).name!=name or '/' in name or '\\' in name:raise ValueError('补充声音文件名错误：'+name)
        audio=root/'audio'/name
        with audio.open('rb') as f:
            header=f.read(12);f.seek(0);digest=hashlib.file_digest(f,'sha256').hexdigest()
        if header[:4]!=b'RIFF' or header[8:]!=b'WAVE' or digest!=row.get('sha256'):raise ValueError('补充声音损坏：'+name)


def verify_cached(root, output):
    root=root.resolve();output=output.resolve()
    if root==output or root in output.parents:
        print('校验状态必须写入被检查缓存之外',file=sys.stderr);return 1
    def report(value):
        temporary=output/'import-status.tmp'
        temporary.write_text(json.dumps(value,ensure_ascii=False),encoding='utf-8');temporary.replace(output/'import-status.json')
    try:
        output.mkdir(parents=True,exist_ok=True);report({'state':'running','message':'正在校验已有素材缓存。'})
        validate(root/'client2011')
        base=json.loads((root/'client2011/manifest.json').read_text(encoding='utf-8'))
        validate_supplement(root/'supplement16','supplement16' in base.get('supplements',[]))
        report({'state':'ready','root':str(root)});return 0
    except Exception as error:
        try:report({'state':'error','message':str(error)})
        except OSError as report_error:print(str(report_error),file=sys.stderr)
        traceback.print_exc();return 1


def main(argv=None):
    parser=argparse.ArgumentParser()
    selection=parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--source',type=Path)
    selection.add_argument('--verify-cache',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--supplement',type=Path)
    parser.add_argument('--jobs',type=int,default=2)
    args=parser.parse_args(argv)
    if args.verify_cache:return verify_cached(args.verify_cache,args.output)
    source=args.source.resolve(); output=args.output.resolve()
    supplement=args.supplement.resolve() if args.supplement else None
    # Never create even a status file inside either source tree.
    for original in [source,supplement]:
        if original and (original==output or original in output.parents):
            print('缓存目录必须在所有原始客户端目录之外',file=sys.stderr)
            return 1
    status=output/'import-status.json'
    def report(state, **kw):
        temporary=status.with_suffix('.tmp')
        temporary.write_text(json.dumps({'state':state,**kw},ensure_ascii=False),encoding='utf-8')
        temporary.replace(status)
    generation=output/('generation-'+uuid.uuid4().hex)
    try:
        output.mkdir(parents=True,exist_ok=True)
        # Replace stale ready/error state before inspecting a new attempt.
        report('running',message='正在检查客户端目录。')
        for part in ['Data','Map','Wav']:convert.child(source,part)
        convert.child(convert.child(source,'Data'),'Hum.wil')
        if supplement:
            for part in ['Data','Wav']:convert.child(supplement,part)
        report('running',message='正在本机转换客户端，请勿关闭。原始目录保持只读。')
        previous_argv=sys.argv
        try:
            sys.argv=['convert_client2011','--source',str(source),'--output',str(generation/'client2011'),'--jobs',str(max(1,min(4,args.jobs)))]
            convert.main()
        finally:
            sys.argv=previous_argv
        validate(generation/'client2011')
        if supplement:
            import supplement_client16
            content=Path(getattr(sys,'_MEIPASS',Path(__file__).resolve().parents[1]))/'game/content/2011/maps.json'
            supplement_client16.main(supplement,generation/'client2011',generation/'supplement16',generation/'audit16',convert.child(convert.child(source,'Data'),'Hum.wil'),content)
            manifest_path=generation/'client2011/manifest.json'
            manifest=json.loads(manifest_path.read_text(encoding='utf-8'));manifest['supplements']=['supplement16']
            manifest_path.write_text(json.dumps(manifest,ensure_ascii=False),encoding='utf-8')
            validate_supplement(generation/'supplement16',True)
        report('ready',root=str(generation),message='本机资源缓存已准备完成')
        return 0
    except Exception as error:
        try:
            report('error',message=str(error))
        except OSError as report_error:
            print('无法写入导入状态：'+str(report_error),file=sys.stderr)
        traceback.print_exc()
        return 1

if __name__=='__main__':
    multiprocessing.freeze_support()
    raise SystemExit(main())
