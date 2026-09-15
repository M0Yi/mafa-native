extends SceneTree
class Probe extends "res://scripts/edition2011/bootstrap.gd":
	var accepted:=""
	func _ready() -> void:build_ui()
	func save_and_launch(path: String) -> void:accepted=path
var failures: Array=[]
func _initialize():call_deferred("run")
func run() -> void:
	var path: String=ProjectSettings.globalize_path("res://../.cache/frozen-import-test/import-status.json")
	var cached=JSON.parse_string(FileAccess.get_file_as_string(path))
	var temporary:="/tmp/mafa-cache-startup-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var a:=Probe.new();var b:=Probe.new();a.cache_parent=temporary;b.cache_parent=temporary
	root.add_child(a);root.add_child(b)
	a.start_verification(cached.root);b.start_verification(temporary+"/missing")
	if a.pid<=0 or b.pid<=0:failures.append("worker did not start")
	if a.output==b.output:failures.append("attempts shared a status directory")
	var active_pid:=a.pid
	a.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if a.pid!=active_pid or a.status.text.find("等待完成")<0:failures.append("window close bypassed active worker guard")
	var deadline:=Time.get_ticks_msec()+60000
	while (a.pid>0 or b.pid>0) and Time.get_ticks_msec()<deadline:await process_frame
	if a.accepted!=cached.root:failures.append("valid external cache did not reach launch callback")
	if not b.accepted.is_empty() or b.status.text.find("导入失败")<0:failures.append("broken cache not reported")
	if a.choose.disabled or b.choose.disabled:failures.append("retry button remains disabled")
	for node in [a,b]:
		if node.pid>0:OS.kill(node.pid)
	var report:={"failures":failures,"scope":"headless startup scene launches real Python checkers concurrently; valid cache accepted, missing cache rejected, independent status and retry controls; no save/config writes or real mouse validation"}
	FileAccess.open("res://../artifacts/closeout-cache-startup.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	a.queue_free();b.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
