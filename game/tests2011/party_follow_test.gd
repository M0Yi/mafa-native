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
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/party-follow-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"follow","name":"同行避让","gender":"男","job":"战士"})
	for name in ["云游客","青禾","远山","轻舟"]:app.rules.social("party",name)
	for fps in [30,60,120]:
		app.enter_map("0");app.world.paused=false
		app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
		var travelers: Array=app.world.entities.filter(func(e):return e.kind=="traveler")
		var origin: Vector2i=app.world.player.cell;var target:=origin
		for direction in ClassicNavigation.DIRECTIONS:
			var at: Vector2i=origin+direction*12
			if app.world.navigation.walkable(at) and not app.world.navigation.path(origin,at).is_empty():target=at;break
		expect(target!=origin,"distant walkable follow destination")
		app.world.player.reset(target)
		var overlaps:=false;var jumps:=false;var steps: Dictionary={}
		for entity in travelers:steps[entity.id]=app.world.actors.mover(entity).completed_steps
		for frame in range(fps*30):
			var before: Dictionary={}
			for entity in travelers:before[entity.id]=app.world.actors.mover(entity).anchor
			app.world.elapsed+=1.0/fps;app.world.actors.update(1.0/fps,app.rules.state.party)
			var reserved: Dictionary={target:"player"}
			for entity in travelers:
				var motion: ClassicPlayer=app.world.actors.mover(entity)
				if motion.anchor.distance_to(before[entity.id])>500.0/fps:jumps=true
				for at in [motion.cell,motion.destination]:
					if reserved.has(at) and reserved[at]!=entity.id:overlaps=true
					reserved[at]=entity.id
		expect(not overlaps,"no shared current/destination cells at "+str(fps))
		expect(not jumps,"movement remains interpolated at "+str(fps))
		for entity in travelers:
			var motion: ClassicPlayer=app.world.actors.mover(entity)
			expect(motion.completed_steps>steps[entity.id] and motion.anchor.distance_to(app.world.player.anchor)<200,"member actually catches up "+entity.name+" at "+str(fps))
	var report:={"checks":checks,"failures":failures,"scope":"four actual party entities following on village collision grid at 30/60/120, cell reservations and interpolation; player destination fixture and monsters excluded, not combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/party-follow-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
