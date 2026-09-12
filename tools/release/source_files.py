"""Strict publication allowlist. Raw assets, saves, local logs and reference repos never included."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def files():
 exact=['game/tests2011/promo_capture.gd','tools/run_dev.py','启动最新开发版.command','.gitignore','README.md','game/project.godot','game/export_presets.cfg','game/bootstrap.tscn','game/edition2011.tscn','game/main.tscn','game/session.tscn','tools/import_client.py','tools/convert_client2011.py','tools/client2011_formats.py','tools/client16_formats.py','tools/supplement_client16.py','tools/build.py','tools/build2011.py','docs/GODOT_LICENSE.txt','docs/MIRGO_LICENSE.txt']
 selected=[ROOT/p for p in exact]
 for folder in ['game/scripts','game/content','game/fonts','game/addons','tools/release','tests/release','release','.github']:
  for p in (ROOT/folder).rglob('*'):
   if not p.is_file() or p.is_symlink() or any(x in p.parts for x in ['__pycache__','media','.DS_Store']):continue
   if p.suffix in ['.pyc','.import'] or (p.name.startswith('source-') or p.name=='skills.json'):continue
   selected.append(p)
 return sorted(set(selected))
def audit():
 forbidden={'.wil','.wix','.wis','.wzl','.wzx','.uib','.wav','.pngpack','.mapbin','.walk','.map','.sqlite','.login','.mp4','.avi'}
 for p in files():
  assert p.is_file(),p
  assert p.suffix.lower() not in forbidden,p
  assert not any(part in p.relative_to(ROOT).parts for part in ['assets','.cache','mirgo','artifacts','data']),p
 return files()
if __name__=='__main__':
 import argparse,subprocess
 parser=argparse.ArgumentParser();parser.add_argument('--stage',action='store_true');args=parser.parse_args();selected=audit()
 if args.stage:
  for i in range(0,len(selected),100):subprocess.run(['git','add','--']+[str(p.relative_to(ROOT)) for p in selected[i:i+100]],cwd=ROOT,check=True)
 print(f'{len(selected)} allowlisted files, no client assets or saves')
