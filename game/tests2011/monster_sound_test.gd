extends SceneTree
var app
func _initialize() -> void:call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-spawn-sound-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await process_frame;app.set_process(false)
	app.start_character({"id":"sound","name":"音效检查","gender":"男","job":"战士"})
	var data:=EditionRegion.data();var points: Array=data.populations["0"]
	var point: Array=points.filter(func(p):return data.spawns[int(p[0])].name=="食人花")[0]
	var cell:=Vector2i(point[2],point[3]);app.enter_map("0",cell+Vector2i(2,2))
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster");app.region.remembered.clear()
	data.populations["0"]=[point]
	var sounds: Array=[]
	app.world.actor_sound.connect(func(id,_at,event):if event=="appear":sounds.append(id))
	app.region.refresh_left=0;app.region.populate(app.world,app.rules,0.5,0)
	var once: bool=sounds==[300]
	app.region.refresh_left=0;app.region.populate(app.world,app.rules,0.5,0.5)
	var twice: bool=sounds==[300]
	data.populations["0"]=points
	var report:={"checks":2,"new_spawn_uses_reference_sound":once,"no_repeated_appearance_sound":twice,"sound_ids":sounds}
	FileAccess.open("res://../artifacts/monsters-0.9.6/sound-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await process_frame;quit(0 if once and twice else 1)
