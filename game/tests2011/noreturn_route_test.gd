extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/noreturn-route-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"noreturn-route","name":"不归路探查","job":"战士","gender":"男"});app.world.hide()
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_noreturn_entry="accepted"
	expect(app.rules.apply(prepared,"accepted_task_fixture"),"prepare accepted exploration")
	var routes: Array=[]
	for mid in ["d701","t1341"]:
		for route in app.resources.connections.by_map.get(mid,[]):
			if route.id in ["333dd835c3803e46","4020d6f63a6049e9"]:routes.append(route)
	expect(routes.size()==2,"adjusted entrance and reconstructed return both registered")
	for route in routes:
		var at:=Vector2i(route.cell[0],route.cell[1])
		if app.world.metadata.id!=route.map:app.enter_map(route.map,at)
		var neighbor:=Vector2i(-1,-1)
		for direction in ClassicNavigation.DIRECTIONS:
			if app.world.navigation.can_step(at,at+direction) and not app.resources.connections.current.has(at+direction):neighbor=at+direction;break
		expect(neighbor!=Vector2i(-1,-1),"door has non-trigger neighbor")
		if neighbor==Vector2i(-1,-1):continue
		# Initial doorway placement is a fixture; moving off and back uses normal steps.
		app.world.paused=false;app.world.player.go_to(neighbor)
		for i in range(300):
			app.world.player.update(1.0/60,Vector2i.ZERO,false);app.resources.connections.poll(app.world.player)
			if app.world.player.cell==neighbor and app.world.player.progress>=1:break
		expect(app.world.player.go_to(at),"walk back toward threshold")
		var crossed:=false
		for i in range(300):
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
			var passage: Dictionary=app.resources.connections.poll(app.world.player)
			if not passage.is_empty():crossed=app.cross_passage(passage);break
		expect(crossed and app.world.metadata.id==route.target_map,"normal threshold crossing reaches expected map")
		expect(app.world.navigation.mobile(app.world.player.cell),"destination is walkable")
	expect(EditionRules.Story.progress(app.rules.state,EditionRules.Story.quest("story_noreturn_entry"),0)==1,"actual crossing records first-area visit")
	expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_noreturn_entry")),"travel alone does not complete spider battle")
	var report:={"checks":checks,"failures":failures,"scope":"adjusted D701 entrance and reconstructed return via actual steps and passage polling; initial doorway/quest fixtures, actors/time not advanced, no full journey or spider combat"}
	FileAccess.open("res://../artifacts/world-story/noreturn-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
