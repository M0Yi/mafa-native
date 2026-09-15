extends SceneTree
var app
var checks:=0
var failures: Array=[]
var frames:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func clear_encounters() -> void:
	app.world.entities=app.world.entities.filter(func(e):return e.kind!="monster")
func walk() -> void:
	for i in range(18000):
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		app.world.player.update(1.0/60,Vector2i.ZERO,false);frames+=1
		var gate: Dictionary=app.resources.connections.poll(app.world.player)
		if not gate.is_empty():app.cross_passage(gate);clear_encounters();break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/peach-story-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"peach","name":"桃源见闻","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=app.rules.story_npc("server:merchant:80");var q: Dictionary=EditionRules.Story.quest("story_peach_witnesses")
	expect(app.enter_map(elder.map,Vector2i(elder.cell[0]+1,elder.cell[1])),"prepare giver position");app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_pig_report="done";expect(app.rules.apply(next,"prior_pig_report_fixture"),"prepare completed stone tomb report")
	expect(app.rules.story_action(q.id,"accept",elder.id,elder.map,app.world.player.cell),"accept peach inquiry")
	expect(app.enter_map("d717",Vector2i(82,25)),"prepare near peach entrance");app.world.paused=false;clear_encounters()
	expect(app.world.approach(Vector2i(83,25)),"approach reference peach entrance");walk()
	expect(app.world.metadata.id=="r001","walking crosses reference entrance")
	expect(not EditionRules.Story.ready(app.rules.state,q),"arrival alone cannot finish task")
	for id in ["server:merchant:126","server:merchant:127"]:
		var npc: Dictionary=app.rules.story_npc(id)
		expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"approach named witness "+id);walk()
		expect(app.near_reference_npc(npc),"continuous movement reaches witness")
		var before: Dictionary={"gold":app.rules.state.gold,"items":app.rules.state.items.duplicate(true)}
		app.interact(npc);app.windows.close_all()
		expect(app.rules.state.gold==before.gold and app.rules.state.items==before.items,"inquiry consumes no possessions")
		expect(EditionRules.Story.progress(app.rules.state,q,1 if id.ends_with("126") else 2)==1,"named conversation counted")
		if id.ends_with("126"):expect(not EditionRules.Story.ready(app.rules.state,q),"second witness still required")
	expect(EditionRules.Story.ready(app.rules.state,q),"both witnesses and visit complete")
	var old: Dictionary=app.rules.story_npc("server:merchant:127");var routes: Array=EditionRegion.teleports(old.id)
	expect(routes.size()==1 and app.teleport_with_npc(old,routes[0]),"elder returns player through actual service");clear_encounters()
	expect(app.world.approach(Vector2i(elder.cell[0],elder.cell[1])),"approach Mongchon giver from return landing");walk()
	expect(app.near_reference_npc(elder),"return walk reaches giver")
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before,"failed delivery preserves progress and possessions")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell),"deliver peach report")
	expect(app.rules.state.gold==before.gold+360,"configured easy-world reward")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",elder.id,elder.map,app.world.player.cell) and app.rules.state==before,"duplicate delivery refused")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.rules.state.quests[q.id]=="done" and app.rules.state.gold==before.gold,"reload preserves completed journey")
	var report:={"checks":checks,"failures":failures,"simulated_walk_seconds":frames/60.0,"scope":"continuous geometry walking from stone tomb entrance through both NPCs, actual elder teleport and walking to giver; initial positions and prerequisites fixtures, monsters removed and combat not advanced; not natural populated expedition or physical input"}
	FileAccess.open("res://../artifacts/world-story/peach-story-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
