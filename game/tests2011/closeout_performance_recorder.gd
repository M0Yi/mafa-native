extends Node
# Passive development recorder. Never drives movement or advances world time.
var host
var output: FileAccess
var started:=Time.get_ticks_msec()
var previous:=Time.get_ticks_msec()
var sample_at:=0
var active_seconds:=0.0
var previous_active:=false
var frames:=0
var active_frames:=0
var maps: Dictionary={}
func setup(app,path: String) -> bool:
	host=app
	output=FileAccess.open(path,FileAccess.WRITE)
	if output==null:return false
	output.store_line(JSON.stringify({"kind":"header","architecture":Engine.get_architecture_name(),"os":OS.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"passive source development process; active time requires focused graphical game and unpaused world; static memory is not RSS; no automatic two-hour pass"}));output.flush()
	return true
func record_interval(now: int,active: bool) -> void:
	frames+=1
	# The interval ending on the first focused frame may include time spent suspended.
	if active:
		if previous_active:active_seconds+=maxf(0,float(now-previous)/1000.0)
		active_frames+=1
		maps[str(host.world.metadata.get("id",""))]=true
	previous=now;previous_active=active

func _process(_delta: float) -> void:
	if not is_instance_valid(host):previous_active=false;set_process(false);return
	var now:=Time.get_ticks_msec()
	var focused:=DisplayServer.window_is_focused()
	var active: bool=DisplayServer.get_name()!="headless" and focused and host.mode=="game" and not host.world.paused
	record_interval(now,active)
	if now-sample_at<5000:return
	sample_at=now
	output.store_line(JSON.stringify({"kind":"sample","wall_seconds":float(now-started)/1000.0,"active_seconds":active_seconds,"focused":focused,"paused":host.world.paused,"mode":host.mode,"fps":Engine.get_frames_per_second(),"static_memory_bytes":OS.get_static_memory_usage(),"texture_cache_bytes":host.resources.memory_bytes,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"frames":frames,"active_frames":active_frames,"maps":maps.keys(),"current_map":str(host.world.metadata.get("id","")),"window_size":str(get_viewport().get_visible_rect().size)}));output.flush()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:previous_active=false
	if what==NOTIFICATION_WM_CLOSE_REQUEST:record_lifecycle("window_close_request")

func record_lifecycle(event: String) -> void:
	if output==null:return
	output.store_line(JSON.stringify({"kind":"lifecycle","event":event,"active_seconds":active_seconds,"wall_seconds":float(Time.get_ticks_msec()-started)/1000.0}))
	output.flush()

func _exit_tree() -> void:
	record_lifecycle("recorder_exit_tree")
	if output!=null:output.close();output=null
