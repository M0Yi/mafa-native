extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/pig-entry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"pig_entry","name":"石墓入口","gender":"男","job":"战士"});app.world.hide()
	expect(app.enter_map("d710",Vector2i(27,22)),"load original blocked entry neighborhood")
	app.world.paused=false
	var travelers: Array=app.world.entities.filter(func(e):return e.kind=="traveler")
	var monsters: Array=app.world.entities.filter(func(e):return e.kind=="monster")
	expect(not travelers.is_empty(),"ambient traveler remains in entry")
	for traveler in travelers:
		var at:=Vector2i(traveler.cell[0],traveler.cell[1])
		expect(at!=Vector2i(25,20),"traveler no longer occupies narrow blocking cell")
		expect(at not in app.world.player.path_avoid and at!=app.world.player.cell,"traveler avoids arrival and gate cells")
	expect(app.world.approach(Vector2i(25,21)),"populated entry permits approaching stone tomb door")
	var crossed:=false
	for frame in range(1200):
		app.world.player.update(1.0/60,Vector2i.ZERO,false)
		var reached: Dictionary=app.resources.connections.poll(app.world.player)
		if not reached.is_empty():
			expect(reached.target_map=="d711","correct destination reached")
			app.cross_passage(reached);crossed=true;break
	expect(crossed and app.world.metadata.id=="d711","continuous movement crosses entry with all generated occupants retained")
	# Exercise actual ambient wandering and a stale route aimed at a door.
	expect(app.enter_map("d710",Vector2i(27,22)),"reload entry for live traveler movement")
	app.world.paused=false
	var traveler: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler")[0]
	var motion: ClassicPlayer=app.world.actors.mover(traveler)
	var started:=motion.completed_steps
	var touched_door:=false
	for frame in range(1800):
		app.world.elapsed+=1.0/60
		app.world.actors.update(1.0/60,[])
		if motion.cell in app.world.player.path_avoid or motion.destination in app.world.player.path_avoid:touched_door=true
	expect(motion.completed_steps>started,"ambient traveler still walks")
	expect(not touched_door,"live wander never occupies a passage cell")
	# A queued route must also be stopped by the step filter, not just pathfinding.
	motion.reset(Vector2i(25,20));motion.route.assign([Vector2i(25,21)])
	app.world.actors.update(1.0/60,[])
	expect(motion.destination!=Vector2i(25,21),"stale door-directed step rejected")
	var report:={"checks":checks,"failures":failures,"entry_travelers":travelers.size(),"entry_monsters":monsters.size(),"scope":"d710 arrival position fixture; real generated occupants retained but stationary; continuous player updates and passage crossing, also 30 simulated seconds of ambient movement and stale gate route fixture; not combat or full maze travel"}
	FileAccess.open("res://../artifacts/world-story/pig-entry-occupancy-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
