extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func tick(fps: int) -> Dictionary:
	app.world.player.update(1.0/fps,Vector2i.ZERO,false)
	var gate: Dictionary=app.resources.connections.poll(app.world.player)
	if not gate.is_empty():expect(app.cross_passage(gate),"polled crossing commits")
	return gate
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/trials-walk-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"walk","name":"旧址步行","gender":"男","job":"战士"});app.world.hide()
	var circuit: Array=["3","q011","q012","q013","q014","q015","3"]
	var records: Array=[]
	for fps in [30,60,120]:
		var town: Dictionary=app.rules.story_npc("server:merchant:80")
		app.enter_map("3",Vector2i(town.cell[0],town.cell[1])+Vector2i(0,1));app.world.paused=false
		for i in range(circuit.size()-1):
			var origin: String=circuit[i];var target: String=circuit[i+1]
			if app.world.metadata.id!=origin:break
			var route: Dictionary=app.resources.connections.by_map[origin].filter(func(r):return r.target_map==target and r.source.get("rule","")=="old_trials_expedition_v1")[0]
			var door:=Vector2i(route.cell[0],route.cell[1])
			expect(app.world.player.go_to(door),"walk route starts "+origin)
			for point in app.world.player.path_avoid:
				expect(app.world.navigation.grid.is_point_solid(point)==not app.world.navigation.walkable(point),"temporary door avoidance restores grid")
			var frames:=0;var crossings:=0
			while frames<fps*120 and app.world.metadata.id==origin:
				if not tick(fps).is_empty():crossings+=1
				frames+=1
			expect(app.world.metadata.id==target,"walk reaches intended map "+target+" at "+str(fps))
			expect(crossings==1,"exactly one crossing per leg")
			for frame in range(fps):expect(tick(fps).is_empty(),"idle arrival does not bounce")
			records.append({"fps":fps,"from":origin,"to":target,"seconds":float(frames)/fps})
		expect(app.world.metadata.id=="3","full circuit returns to town at "+str(fps))
	var report:={"checks":checks,"failures":failures,"legs":records,"scope":"continuous ClassicPlayer steps and connection polling at 30/60/120, no intermediate reposition; initial town position fixture, actor combat/time updates excluded; not hardware playtest"}
	FileAccess.open("res://../artifacts/world-story/trials-walk-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
