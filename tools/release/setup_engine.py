"""Download the fixed official engine and export templates for CI."""
import hashlib,json,os,platform,shutil,stat,urllib.request,zipfile
from pathlib import Path
VERSION='4.7.2-stable';BASE=f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}/'
root=Path('.cache/ci-godot').resolve();root.mkdir(parents=True,exist_ok=True)
system=platform.system();suffix={'Windows':'win64.exe.zip','Darwin':'macos.universal.zip','Linux':'linux.x86_64.zip'}[system]
name=f'Godot_v{VERSION}_{suffix}'
for filename in [name,f'Godot_v{VERSION}_export_templates.tpz']:
 path=root/filename
 if not path.exists():urllib.request.urlretrieve(BASE+filename,path)
 print(filename,hashlib.file_digest(path.open('rb'),'sha256').hexdigest())
 with zipfile.ZipFile(path) as archive:archive.extractall(root)
for p in root.rglob('*'):
 if p.is_file() and (p.name.startswith('Godot') or p.name in ['Godot','godot']):p.chmod(p.stat().st_mode|0o111)
exe=root/'Godot.app/Contents/MacOS/Godot' if system=='Darwin' else next(root.glob('Godot*.exe' if system=='Windows' else 'Godot*.x86_64'))
base=Path(os.environ['APPDATA']) if system=='Windows' else Path.home()/'Library/Application Support' if system=='Darwin' else Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))
templates=base/'Godot/export_templates/4.7.2.stable';shutil.copytree(root/'templates',templates,dirs_exist_ok=True)
with open(os.environ['GITHUB_ENV'],'a',encoding='utf-8') as f:f.write(f'GODOT={exe}\n')
