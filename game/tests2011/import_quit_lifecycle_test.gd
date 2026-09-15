extends SceneTree
class Probe extends "res://scripts/edition2011/bootstrap.gd":
 func _ready():pass
func _initialize():call_deferred("run")
func run():
 if OS.get_name()!="macOS":
  print("SKIP: macOS child-process lifecycle probe");quit();return
 var boot:=Probe.new();root.add_child(boot);boot.set_process(false)
 boot.status=Label.new();boot.add_child(boot.status)
 boot.choose=Button.new();boot.add_child(boot.choose);boot.choose.disabled=true
 var path:="/tmp/mafa-quit-worker-"+Crypto.new().generate_random_bytes(8).hex_encode()
 DirAccess.make_dir_recursive_absolute(path);boot.output=path
 boot.pid=OS.create_process("/bin/sleep",PackedStringArray(["1"]))
 assert(boot.pid>0 and OS.is_process_running(boot.pid))
 boot.request_quit()
 assert(OS.is_process_running(boot.pid) and boot.status.text.contains("仍在运行"))
 var deadline:=Time.get_ticks_msec()+5000
 while OS.is_process_running(boot.pid) and Time.get_ticks_msec()<deadline:await create_timer(0.05).timeout
 assert(not OS.is_process_running(boot.pid))
 boot._process(1.1)
 assert(boot.pid==-1 and not boot.choose.disabled and boot.status.text.contains("已退出"))
 DirAccess.remove_absolute(path)
 print("PASS: running child blocks normal quit; exited child releases retry and quit; macOS real child, not GUI input")
 boot.request_quit()
