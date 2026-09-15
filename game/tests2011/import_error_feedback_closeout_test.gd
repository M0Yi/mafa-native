extends SceneTree
class Probe extends "res://scripts/edition2011/bootstrap.gd":
 func _ready() -> void:build_ui()
class StartupProbe extends "res://scripts/edition2011/bootstrap.gd":
 var accepted:=""
 func launch(path: String) -> void:accepted=path
func _initialize():call_deferred("run")
func run() -> void:
 var path:="/tmp/mafa-import-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()
 assert(DirAccess.make_dir_absolute(path)==OK)
 var view:=Probe.new();root.add_child(view);view.set_process(false);view.output=path
 for report in [{"state":"error"},{"state":"error","message":null},{"state":"error","message":"  "},{"state":"error","message":"磁盘空间不足"}]:
  var file:=FileAccess.open(path+"/import-status.json",FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
  view.pid=OS.get_process_id();view.choose.disabled=true;view._process(1.1)
  assert(view.pid==-1 and not view.choose.disabled)
  assert(view.status.text.contains("磁盘空间不足") if report.get("message")=="磁盘空间不足" else view.status.text.contains("未提供错误详情"))
 print("PASS: import error with missing, null or blank message restores retry and explicit feedback")
 # A real short-lived child, not a fabricated PID or mocked liveness response.
 for broken_status in ["", "{unfinished", "[]"]:
  var status_path:=path+"/import-status.json"
  if broken_status.is_empty():DirAccess.remove_absolute(status_path)
  else:
   var file:=FileAccess.open(status_path,FileAccess.WRITE);file.store_string(broken_status);file.close()
  var child:=OS.create_process(OS.get_executable_path(),["--headless","--version"])
  assert(child>0)
  view.pid=child;view.choose.disabled=true
  for attempt in range(100):
   if not OS.is_process_running(child):break
   await create_timer(0.05).timeout
  assert(not OS.is_process_running(child))
  view._process(1.1)
  assert(view.pid==-1 and not view.choose.disabled)
  assert(view.status.text.contains("已退出但没有完成"))
 print("PASS: real exited child with missing or malformed status restores import retry")

 for invalid in [42,[],{}]:
  var cfg:=ConfigFile.new();cfg.set_value("resources","root",invalid);cfg.set_value("future","preserved",42)
  var settings:=path+"/resources.cfg";assert(cfg.save(settings)==OK)
  var original:=FileAccess.get_file_as_bytes(settings)
  var startup:=StartupProbe.new();startup.settings_path=settings;root.add_child(startup)
  assert(startup.accepted.is_empty() and startup.pid==-1 and not startup.choose.disabled)
  assert(startup.status.text.contains("路径格式错误") and FileAccess.get_file_as_bytes(settings)==original)
  # Exercise the post-verification save step; launch is intercepted, no cache import.
  var replacement:=path+"/chosen-cache"
  startup.save_and_launch(replacement)
  var restored:=ConfigFile.new();assert(restored.load(settings)==OK)
  assert(startup.accepted==replacement and restored.get_value("resources","root")==replacement)
  assert(restored.get_value("future","preserved")==42)
  startup.free()
 print("PASS: invalid configured cache path preserves settings and opens recovery UI")
 print("PASS: replacing invalid cache path persists without losing unrelated settings")
 DirAccess.remove_absolute(path+"/resources.cfg")
 view.free();DirAccess.remove_absolute(path+"/import-status.json");DirAccess.remove_absolute(path)
 quit()
