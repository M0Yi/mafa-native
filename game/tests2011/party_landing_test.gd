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
	app.store.path="/tmp/party-landing-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"landing","name":"同行落点","gender":"男","job":"战士"})
	for name in ["云游客","青禾","远山","轻舟"]:expect(app.rules.social("party",name),"invite "+name)
	for mid in ["3","2","q013","0159","0"]:
		expect(app.enter_map(mid),"load party map "+mid)
		var party: Array=app.world.entities.filter(func(e):return e.kind=="traveler" and e.name in app.rules.state.party)
		expect(party.size()==4,"all party members accompany into "+mid)
		var taken: Dictionary={app.world.player.cell:true}
		for entity in party:
			var at:=Vector2i(entity.cell[0],entity.cell[1])
			expect(not taken.has(at),"unique party arrival "+mid);taken[at]=true
			expect(not app.world.navigation.occupied.has(at) and at not in app.world.player.path_avoid,"arrival avoids NPC and gate")
			expect(at.distance_to(app.world.player.cell)<=12 and not app.world.navigation.path_avoiding(app.world.player.cell,at,app.world.player.path_avoid).is_empty(),"member reachable near actual landing")
			expect(app.world.actors.mover(entity).cell==at,"motion starts at party landing")
	var old_navigation=app.world.navigation
	var tight:=ClassicNavigation.new();tight.configure({"size":[1,1],"walkable":[[1]]});app.world.navigation=tight;app.world.player.reset(Vector2i.ZERO)
	expect(app.world.actors.party_landing()==Vector2i(-1,-1),"no-space landing refuses overlap")
	app.world.navigation=old_navigation
	var report:={"checks":checks,"failures":failures,"scope":"actual party relationships and five map loads including shop, unique reachable landing/motion/NPC/gate checks; synthetic no-space case; ongoing combat following untested"}
	FileAccess.open("res://../artifacts/world-story/party-landing-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
