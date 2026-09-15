extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("Requires graphical renderer");quit(2);return
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-render-layers-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.size=Vector2i(1280,800);root.add_child(app)
	app.start_character({"id":"layers","name":"图层诊断","job":"战士","gender":"女"})
	app.enter_map("0",Vector2i(300,614))
	await create_timer(2).timeout
	app.world.paused=true
	var report:={"scope":"stationary paused village layer ablation; diagnostic only, not playable FPS or feature removal","phases":[]}
	for phase in ["all","no_labels","no_lights","no_minimap","no_hud","no_world"]:
		app.world.labels.visible=phase!="no_labels"
		app.world.light_layer.visible=phase!="no_lights"
		app.classic_hud.visible=phase!="no_hud"
		app.classic_hud.minimap.visible=phase!="no_minimap"
		app.world.visible=phase!="no_world"
		await create_timer(1).timeout
		if phase=="all":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../artifacts/closeout-minimap-batch.png")
		var draws: Array=[];var times: Array=[]
		for i in range(120):
			await process_frame
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draws.sort();times.sort()
		report.phases.append({"phase":phase,"median_draw_calls":draws[60],"median_process_ms":times[60]})
	print(JSON.stringify(report));FileAccess.open("res://../artifacts/closeout-render-layers.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
