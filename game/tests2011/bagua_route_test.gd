extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var checks:=0
var failures: Array=[]
var frames:=0
var crossed: Dictionary={}
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func clear_encounters() -> void:
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
func walk() -> void:
	crossed={}
	for i in range(18000):
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		app.world.player.update(1.0/60,Vector2i.ZERO,false);frames+=1
		var gate: Dictionary=app.resources.connections.poll(app.world.player)
		if not gate.is_empty():crossed=gate.duplicate(true);app.cross_passage(gate);clear_encounters();break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/bagua-route-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"bagua","name":"迷宫过门","job":"战士","gender":"男"});app.world.hide()
	expect(app.enter_map("q014",Vector2i(54,54)),"prepare source script landing");app.world.paused=false;clear_encounters()
	expect(app.world.player.cell==Vector2i(54,54),"entry preserves exact reference cell")
	var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../artifacts/world-story/bagua-route-audit.json"))
	var steps: Array=audit.reference_only.route_to_merchant
	var travelled: Array=[]
	for step in steps:
		var candidates: Array=app.resources.connections.by_map.get(app.world.metadata.id,[]).filter(func(r):return r.id==step.id)
		expect(candidates.size()==1,"planned reference gate exists in current map")
		if candidates.size()!=1:break
		var gate: Dictionary=candidates[0]
		var before_frames:=frames
		var can_walk: bool=app.world.approach(Vector2i(gate.cell[0],gate.cell[1]))
		expect(can_walk,"walk without crossing unintended doorway: "+gate.id)
		if not can_walk:break
		walk()
		expect(not crossed.is_empty() and crossed.get("kind")=="reference" and crossed.get("target_component")==gate.target_component,"actual doorway belongs to planned reference destination")
		if crossed.is_empty():break
		var expected:=Vector2i(crossed.target_cell[0],crossed.target_cell[1])
		expect(frames>before_frames,"gate reached by movement")
		expect(app.world.metadata.id==gate.target_map and app.world.player.cell==expected,"exact landing after crossing "+gate.id)
		travelled.append({"gate":crossed.id,"planned_gate":gate.id,"actual_map":app.world.metadata.id,"actual_cell":[app.world.player.cell.x,app.world.player.cell.y]})
		if app.world.metadata.id!=gate.target_map or app.world.player.cell!=expected:break
	expect(travelled.size()==steps.size() and app.world.metadata.id=="q016","complete original maze path")
	if app.world.metadata.id=="q016":
		var npc: Dictionary=app.rules.story_npc("server:merchant:109")
		expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"approach destination merchant");walk()
		expect(app.near_reference_npc(npc),"reach merchant without occupying NPC cell")
		var Clues=preload("res://scripts/edition2011/bagua_clues.gd")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not Clues.travel(app,true) and app.rules.state==before and app.world.metadata.id=="q016","failed return restores merchant scene and state")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(Clues.travel(app,true),"merchant provides free reconstructed return")
		var elder: Dictionary=app.rules.story_npc(Clues.NPC)
		expect(app.near_reference_npc(elder) and app.rules.state.gold==before.gold,"return reaches elder without charge")
		expect(not Clues.travel(app,false),"entry requires four clues")
		var next: Dictionary=app.rules.state.duplicate(true);next.bagua_clues=4
		expect(app.rules.apply(next,"four_clues_fixture"),"prepare purchased clues")
		before=app.rules.state.duplicate(true);app.world.paused=true
		expect(not Clues.travel(app,false) and app.rules.state==before,"pause blocks entry");app.world.paused=false
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not Clues.travel(app,false) and app.rules.state==before and app.world.metadata.id=="q011","failed entry restores elder scene")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(Clues.travel(app,false) and app.world.player.cell==Vector2i(54,54),"four clues unlock exact source landing")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.world.metadata.id=="q014" and app.world.player.cell==Vector2i(54,54),"entry persists after reload")
	var report:={"checks":checks,"failures":failures,"travelled":travelled,"simulated_walk_seconds":frames/60.0,"scope":"actual player movement, passage polling and SQLite scene changes along static original route; initial landing and four-clue fixtures, monsters removed; free return, paused entry, SQLite rollback and reload; no physical input or combat"}
	FileAccess.open("res://../artifacts/world-story/bagua-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
