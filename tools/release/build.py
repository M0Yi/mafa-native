#!/usr/bin/env python3
"""Export code-only desktop packages; requires explicit --release."""
import argparse,hashlib,json,os,platform,shutil,subprocess,sys,tempfile,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
VERSION='0.14.0-preview.1'

def run(args):subprocess.run([str(x) for x in args],check=True)
def main():
 p=argparse.ArgumentParser();p.add_argument('--release',action='store_true');p.add_argument('--platform',choices=['macOS','Windows','Linux'],default={'Darwin':'macOS','Windows':'Windows'}.get(platform.system(),'Linux'));p.add_argument('--godot',default=os.environ.get('GODOT','godot'));p.add_argument('--importer',type=Path);a=p.parse_args()
 if not a.release:p.error('Explicit --release is required')
 if not a.importer or not a.importer.is_file():p.error('Provide the native mafa-importer executable with --importer')
 out=ROOT/'dist'/VERSION;out.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='mafa-export-') as raw:
  work=Path(raw);project=work/'game';project.mkdir()
  # Stage only game code and licensed fonts/extensions. No client data crosses this boundary.
  for folder in ['scripts','content','addons','fonts']:
   shutil.copytree(ROOT/'game'/folder,project/folder,ignore=shutil.ignore_patterns('__pycache__','*.import','.DS_Store'))
  for path in (project/'content').rglob('*.json'):
   if path.name.startswith('source-') or path.name=='skills.json':path.unlink()
  for path in (ROOT/'game').glob('*.tscn'):shutil.copy2(path,project/path.name)
  for name in ['project.godot','export_presets.cfg']:shutil.copy2(ROOT/'game'/name,project/name)
  run([a.godot,'--headless','--path',project,'--editor','--import'])
  pkg=work/'package';pkg.mkdir()
  target=pkg/('MafaNative.app' if a.platform=='macOS' else 'MafaNative.exe' if a.platform=='Windows' else 'MafaNative.x86_64')
  run([a.godot,'--headless','--path',project,'--export-release',a.platform,target])
  binarydir=target/'Contents/MacOS' if a.platform=='macOS' else pkg
  dest=binarydir/('mafa-importer.exe' if a.platform=='Windows' else 'mafa-importer');shutil.copy2(a.importer,dest);dest.chmod(0o755)
  shutil.copy2(ROOT/'release/README.zh-CN.md',pkg/'README.zh-CN.md')
  shutil.copy2(ROOT/'release/THIRD_PARTY_NOTICES.md',pkg/'THIRD_PARTY_NOTICES.md')
  for src in [ROOT/'docs/GODOT_LICENSE.txt',ROOT/'docs/MIRGO_LICENSE.txt',ROOT/'game/fonts/OFL.txt',ROOT/'game/addons/godot-sqlite/LICENSE.md']:shutil.copy2(src,pkg/('SQLite-LICENSE.md' if src.name=='LICENSE.md' else src.name))
  import importlib.metadata
  for dependency in ['numpy','pillow','pyinstaller']:
   dist=importlib.metadata.distribution(dependency)
   for entry in dist.files or []:
    if 'license' in str(entry).lower() or 'copying' in str(entry).lower():
     original=Path(dist.locate_file(entry))
     if original.is_file():
      notice=pkg/'dependency-licenses'/dependency/str(entry);notice.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,notice)
  forbidden={'.wil','.wix','.wis','.wzl','.wzx','.uib','.wav','.pngpack','.mapbin','.walk','.map','.sqlite','.login'}
  for f in pkg.rglob('*'):
   if f.is_file() and f.suffix.lower() in forbidden:raise RuntimeError('Forbidden payload: '+str(f))
  # Read the exported pack using Godot itself; reject embedded client resources too.
  pack=next(target.rglob('*.pck')) if a.platform=='macOS' else target.with_suffix('.pck')
  audit=work/'audit.json'
  native=next(p for p in binarydir.iterdir() if p.name!='mafa-importer') if a.platform=='macOS' else target
  run([native,'--headless','--','--audit-output='+str(audit)])
  run([native,'--headless','--quit-after','3','--','--asset-setup'])
  if a.platform=='macOS':
   executable=next(p for p in binarydir.iterdir() if p.name!='mafa-importer')
   thin=executable.with_suffix('.arm64');run(['lipo',executable,'-thin','arm64','-output',thin]);thin.replace(executable);executable.chmod(0o755)
  if a.platform=='macOS':run(['codesign','--force','--deep','--sign','-',target]);run(['codesign','--verify','--deep','--strict',target])
  filename=f'MafaNative-{VERSION}-{a.platform}-{ "arm64" if a.platform=="macOS" else "x86_64"}.zip'
  archive=out/filename
  if a.platform=='macOS':run(['ditto','-c','-k','--norsrc',pkg,archive])
  else:
   with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for f in pkg.rglob('*'):
     if f.is_file():z.write(f,f.relative_to(pkg))
  report={'version':VERSION,'platform':a.platform,'archive':filename,'bytes':archive.stat().st_size,'sha256':hashlib.file_digest(archive.open('rb'),'sha256').hexdigest(),'asset_audit':json.loads(audit.read_text()),'native_setup_smoke_test':True,'full_gameplay_tested':False,'unsigned_or_adhoc':True}
  (out/(filename+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report))
if __name__=='__main__':main()
