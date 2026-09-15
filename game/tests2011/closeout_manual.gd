extends SceneTree
class DragProbe extends Node:
	var host
	var previous_mask:=-1
	var previous_position:=Vector2.INF
	func _process(_delta: float) -> void:
		var mask:=Input.get_mouse_button_mask()
		var at:=get_viewport().get_mouse_position()
		if mask!=previous_mask or (mask!=0 and at!=previous_position):
			print("MANUAL_POINTER_POLL ",JSON.stringify({"mask":mask,"position":str(at),"dragging":get_viewport().gui_is_dragging(),"paused":host.world.paused,"focused":DisplayServer.window_is_focused()}))
		previous_mask=mask;previous_position=at
	func _input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton or (event is InputEventMouseMotion and event.button_mask!=0)):return
		var row:={"event":event.as_text(),"position":str(event.position),"viewport":str(get_viewport().get_visible_rect()),"dragging":get_viewport().gui_is_dragging(),"paused":host.world.paused}
		var hover=get_viewport().gui_get_hovered_control()
		if hover!=null:row["hover"]={"path":str(hover.get_path()),"rect":str(hover.get_global_rect()),"type":hover.get_class()}
		print("MANUAL_POINTER ",JSON.stringify(row))
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	var app=load("res://edition2011.tscn").instantiate()
	app.configure_native_window=false
	app.store.path="/tmp/mafa-closeout-manual-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manual-save="):
			var path:=arg.trim_prefix("--manual-save=")
			if not path.begins_with("/tmp/mafa-closeout-manual-") or path.contains("..") or not path.ends_with(".sqlite"):
				printerr("Manual test requires an isolated /tmp/mafa-closeout-manual-*.sqlite path");quit(1);return
			app.store.path=path
	root.add_child(app)
	if "--trace-drag" in OS.get_cmdline_user_args():
		var probe:=DragProbe.new();probe.host=app;root.add_child(probe)
	if "--record-performance" in OS.get_cmdline_user_args():
		var recorder=load("res://tests2011/closeout_performance_recorder.gd").new()
		var log_path:="res://../artifacts/closeout-performance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".jsonl"
		if recorder.setup(app,log_path):root.add_child(recorder);print("PERFORMANCE_LOG ",log_path)
		else:recorder.free();printerr("Cannot create performance log")
	root.title="玛法收尾 · 隔离操作验收"
