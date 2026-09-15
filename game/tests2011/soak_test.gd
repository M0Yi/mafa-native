extends SceneTree
var app: Node
var samples: Array=[]
var movie:=false
static func parse_rss(status: int,output: Array):
	if status!=0 or output.is_empty():return null
	var value:=str(output[0]).strip_edges()
	if not value.is_valid_int() or int(value)<=0:return null
	return int(value)
func read_rss():
	if OS.get_name() not in ["macOS","Linux","FreeBSD","NetBSD","OpenBSD"]:return null
	var output: Array=[]
	var status:=OS.execute("ps",["-o","rss=","-p",str(OS.get_process_id())],output)
	return parse_rss(status,output)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	movie=OS.get_cmdline_user_args().has("--demo-movie")
	app=load("res://edition2011.tscn").instantiate()
	app.store.path=OS.get_environment("TMPDIR")+"mafa-soak-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app)
	var profile={"id":"soak-test","name":"自动探索演示","job":"战士","gender":"男"}
	app.automation="test";app.rules.character=profile;app.rules.state=app.rules.new_world(profile,"easy")
	app.mode="game";app.world.visible=true;app.elapsed=0;app.enter_map("0");app.build_hud();app.close_panel()
	var start:=Time.get_ticks_msec();var duration:=20 if movie else 120;var seconds:=0.0;var sample_at:=0.0;var target_at:=0.0;var map_at:=30.0;var position_index:=0
	var active_seconds:=0.0;var paused_seconds:=0.0;var previous_tick:=start
	while seconds<duration:
		await process_frame
		var now:=Time.get_ticks_msec()
		var frame_seconds: float=(now-previous_tick)/1000.0;previous_tick=now
		if app.world.paused:paused_seconds+=frame_seconds
		else:active_seconds+=frame_seconds
		seconds=app.elapsed if movie else (Time.get_ticks_msec()-start)/1000.0
		if seconds>=target_at:
			var cells: Array=app.world.metadata.service_spots
			var c: Array=cells[position_index%cells.size()];position_index+=1
			app.world.player.go_to(Vector2i(c[0],c[1]));target_at=seconds+3
		if not movie and seconds>=map_at:
			app.enter_map("3" if app.world.metadata.id=="0" else "0");map_at+=30
		if seconds>=sample_at:
			samples.append({"seconds":seconds,"active_wall_seconds":active_seconds,"paused_wall_seconds":paused_seconds,"paused":app.world.paused,"game_seconds":app.elapsed,"cell":[app.world.player.cell.x,app.world.player.cell.y],"map":app.world.metadata.id,"fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"render_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"rss_kib":read_rss(),"textures_bytes":app.resources.memory_bytes})
			sample_at=seconds+5
	var report={"duration_seconds":seconds,"active_wall_seconds":active_seconds,"paused_wall_seconds":paused_seconds,"samples":samples,"resource_errors":app.resources.errors,"scope":"20 second automated source-scene recording" if movie else "120 second development smoke, two maps, not the required two-hour acceptance"}
	var output_path:="res://../artifacts/client-10th-audit/"+("demo" if movie else "soak")+".json"
	var file:=FileAccess.open(output_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));var fixture_path: String=app.store.path
	app.queue_free();await process_frame
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var fixture_file: String=fixture_path+suffix
		if FileAccess.file_exists(fixture_file) and DirAccess.remove_absolute(fixture_file)!=OK:printerr("Cannot clean test database: "+fixture_file);quit(1);return
	quit()
