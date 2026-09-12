#!/usr/bin/env python3
"""Import user-owned client data locally. Never execute client EXEs or modify input."""
import argparse, json, os, sys, multiprocessing, traceback, uuid
from pathlib import Path
import convert_client2011 as convert


def validate(root):
    manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    maps=json.loads((root/'maps.json').read_text(encoding='utf-8'))['maps']
    if manifest.get('resource_version')!='2.0.1.11' or len(maps)!=707:
        raise ValueError('需要配套的 2.0.1.11 十周年客户端（707 张地图）；十六周年仅作补充，不能单独替代。')
    for m in maps:
        if not (root/'maps'/f"{m['id']}.mapbin").is_file() or not (root/'maps'/f"{m['id']}.walk").is_file():
            raise ValueError('地图转换不完整：'+m['id'])
    for bank in ['hum','chrsel','prguse','tiles','smtiles','npc']:
        p=root/'libraries'/f'{bank}.json'
        if not p.exists() or not (root/'libraries'/f'{bank}.pngpack').is_file():raise ValueError('缺少必需图像库：'+bank)
        row=json.loads(p.read_text(encoding='utf-8'))
        if row.get('errors'):raise ValueError('必需图像库解码失败：'+bank)
    for filename in ['log-in-long2.wav','sellect-loop2.wav','1.wav']:
        if not (root/'audio'/filename).exists():raise ValueError('缺少必需声音：'+filename)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--supplement',type=Path)
    parser.add_argument('--jobs',type=int,default=2)
    args=parser.parse_args()
    source=args.source.resolve(); output=args.output.resolve()
    if source==output or source in output.parents:raise ValueError('缓存目录必须在原始客户端目录之外')
    output.mkdir(parents=True,exist_ok=True)
    status=output/'import-status.json'
    def report(state, **kw):
        temporary=status.with_suffix('.tmp');temporary.write_text(json.dumps({'state':state,**kw},ensure_ascii=False),encoding='utf-8');temporary.replace(status)
    generation=output/('generation-'+uuid.uuid4().hex)
    try:
        # Reject incompatible sources before any lengthy conversion.
        for part in ['Data','Map','Wav']:convert.child(source,part)
        convert.child(convert.child(source,'Data'),'Hum.wil')
        report('running',message='正在本机转换客户端，请勿关闭。原始目录保持只读。')
        sys.argv=['convert_client2011','--source',str(source),'--output',str(generation/'client2011'),'--jobs',str(max(1,min(4,args.jobs)))]
        convert.main();validate(generation/'client2011')
        if args.supplement:
            import supplement_client16
            content=Path(getattr(sys,'_MEIPASS',Path(__file__).resolve().parents[1]))/'game/content/2011/maps.json'
            supplement_client16.main(args.supplement,generation/'client2011',generation/'supplement16',generation/'audit16',convert.child(convert.child(source,'Data'),'Hum.wil'),content)
            manifest_path=generation/'client2011/manifest.json'
            manifest=json.loads(manifest_path.read_text(encoding='utf-8'));manifest['supplements']=['supplement16']
            manifest_path.write_text(json.dumps(manifest,ensure_ascii=False),encoding='utf-8')
        report('ready',root=str(generation),message='本机资源缓存已准备完成')
        return 0
    except Exception as error:
        report('error',message=str(error));traceback.print_exc();return 1

if __name__=='__main__':
    multiprocessing.freeze_support()
    raise SystemExit(main())
