extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/counter-route-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(6):await process_frame
	app.set_process(false);app.start_character({"id":"counter","name":"柜台导航","job":"战士","gender":"男"});app.world.hide()
	for row in [{"npc":"server:merchant:36","map":"0140","landing":[2,10],"component":["0140",1.0]},{"npc":"server:merchant:143","map":"g002","landing":[48,14],"component":["g002",2.0]},{"npc":"server:merchant:143","map":"g002","landing":[50,14],"component":["g002",2.0]}]:
		var npc: Dictionary=app.rules.story_npc(row.npc);var at:=Vector2i(npc.cell[0],npc.cell[1])
		expect(row.component in Planner.npc_components(app.resources,npc),"planner includes reachable counter component "+row.npc)
		expect(app.enter_map(row.map,Vector2i(row.landing[0],row.landing[1])),"load reference landing");app.world.paused=false
		var adjacent:=false
		for direction in ClassicNavigation.DIRECTIONS:
			if not app.world.navigation.path(app.world.player.cell,at+direction).is_empty():adjacent=true
		expect(not adjacent,"fixture requires counter fallback rather than adjacent tile")
		expect(app.world.approach(at),"world can approach planned NPC")
		for frame in range(18000):
			app._process(1.0/60)
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		expect(app.near_reference_npc(npc),"walk ends in actual interaction radius")
		expect(app.world.player.cell!=at and (app.world.player.cell-at).length()>1.5,"counter approach does not occupy NPC or cross counter")
		for i in range(3):await process_frame
	var report:={"checks":checks,"failures":failures,"scope":"actual map masks, occupied NPC cells and continuous movement from three prepared landings to counter-side interaction range; no natural inter-map journey, hardware input or NPC service transaction"}
	FileAccess.open("res://../artifacts/world-story/npc-counter-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
