extends SceneTree
var app
var checks:=0
var failures: Array=[]
var frames:=0
var job:=OS.get_environment("MAFA_TEST_JOB")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func tick() -> void:
	app._process(1.0/60);frames+=1
func run() -> void:
	if job.is_empty():job="战士"
	if job not in ["战士","法师","道士"]:push_error("Unsupported test job");quit(1);return
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/novice-natural-hunt-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"natural-hunt","name":"村口试炼","job":job,"gender":"男"});app.world.hide();app.world.paused=false
	expect(app.rules.novice_quest("nv_arrival") and app.rules.novice_quest("nv_arrival"),"receive starter gear at spawn")
	expect(app.rules.use_item("wood_sword") and app.rules.use_item("robe"),"equip starter rewards")
	expect(app.rules.novice_quest("nv_equip") and app.rules.novice_quest("nv_equip") and app.rules.novice_quest("nv_hunt"),"complete equipment and accept hunt")
	var chosen: Dictionary={}
	for i in range(60*300):
		if app.rules.state.hp<=0 or int(app.rules.state.novice.chickens)>=3:break
		if chosen.is_empty() or chosen.hp<=0:
			var candidates: Array=app.world.entities.filter(func(e):return e.get("species","")=="village_chicken" and e.hp>0 and not EditionRegion.safe("0",Vector2i(e.cell[0],e.cell[1])))
			candidates.sort_custom(func(a,b):return Vector2(a.cell[0]-app.world.player.cell.x,a.cell[1]-app.world.player.cell.y).length_squared()<Vector2(b.cell[0]-app.world.player.cell.x,b.cell[1]-app.world.player.cell.y).length_squared())
			if candidates.is_empty():break
			chosen=candidates[0]
		app.selected=chosen
		var at:=Vector2i(chosen.cell[0],chosen.cell[1])
		if app.world.player.cell.distance_to(at)<1.5:app.attack_target()
		elif i%30==0:app.world.approach(at)
		tick()
	expect(app.rules.state.hp>0 and int(app.rules.state.novice.chickens)==3,"natural attacks register three chickens before timeout")
	expect(app.rules.state.inventory.get("chicken_meat",0)==0,"no auto pickup while hunting")
	for round in range(12):
		if app.rules.state.inventory.get("chicken_meat",0)>=3:break
		app.navigate_village_objective("nv_hunt")
		for i in range(60*90):
			tick()
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		app.gameplay.pickup_nearby()
	expect(app.rules.state.inventory.get("chicken_meat",0)>=3,"walk to real drops and explicitly pick up meat")
	app.navigate_village_objective("nv_hunt")
	for i in range(60*180):
		tick()
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	expect(app.rules.story_near("border:elder",app.world.metadata.id,app.world.player.cell),"walk back to elder")
	if app.rules.story_near("border:elder",app.world.metadata.id,app.world.player.cell):expect(app.rules.novice_quest("nv_hunt"),"deliver naturally earned chicken meat")
	expect(app.store.load_world("natural-hunt").quests.get("nv_hunt")=="done","completed hunt saved")
	expect(app.rules.novice_quest("nv_patrol"),"accept patrol after hunt")
	app.navigate_village_objective("nv_patrol")
	for i in range(60*180):
		tick()
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	expect(app.rules.state.novice.patrol,"walking records patrol arrival")
	app.navigate_village_objective("nv_patrol")
	for i in range(60*180):
		tick()
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	var near: bool=app.rules.story_near("border:elder",app.world.metadata.id,app.world.player.cell)
	expect(near,"walk back after patrol")
	if near:
		expect(app.rules.novice_quest("nv_patrol"),"deliver walked patrol")
		expect(app.rules.story_action("story_letter","accept","border:elder",app.world.metadata.id,app.world.player.cell),"accept Bichon letter at elder")
	expect(app.store.load_world("natural-hunt").quests.get("story_letter")=="accepted","handoff to Bichon story persists")
	app.approach_story_npc("server:merchant:4")
	for i in range(60*600):
		tick()
		if app.rules.state.hp<=0:break
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	expect(app.rules.story_near("server:merchant:4",app.world.metadata.id,app.world.player.cell),"walk entire letter route from village to Bichon elder")
	var before_letter: Dictionary=app.rules.state.duplicate(true)
	expect(app.rules.story_action("story_letter","submit","server:merchant:4",app.world.metadata.id,app.world.player.cell),"deliver letter after walking")
	expect(app.rules.state.gold==before_letter.gold+240,"letter grants exact easy-preset gold")
	expect(app.store.load_world("natural-hunt").quests.get("story_letter")=="done","Bichon delivery saved")
	expect(EditionRules.Story.available(app.rules.state,EditionRules.Story.quest("story_bichon_inn")),"arrival unlocks Bichon town errand")
	var report:={"job":job,"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"player_hp":app.rules.state.hp,"chickens":app.rules.state.novice.chickens,"scope":"fresh character, starter gear only, full main loop and unmodified world entities, walk/normal attacks/explicit pickup/return/patrol/letter acceptance/full Bichon walk/delivery; API-driven actions, no physical input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/novice-natural-hunt-"+{"战士":"warrior","法师":"mage","道士":"tao"}[job]+"-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
