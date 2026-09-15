extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/novice-meat-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"meat-nav","name":"寻找鸡肉","job":"战士","gender":"男"});app.world.hide();app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests={"nv_arrival":"done","nv_equip":"done","nv_hunt":"accepted"};next.novice={"chickens":3,"patrol":false}
	var target: Vector2i=EditionVillage.SPAWN
	for delta in [Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]:
		if not app.world.navigation.path(EditionVillage.SPAWN,EditionVillage.SPAWN+delta).is_empty():target=EditionVillage.SPAWN+delta;break
	expect(target!=EditionVillage.SPAWN,"reachable drop fixture")
	app.rules.add_ground(next,{"map":"0","cell":[target.x,target.y]},"chicken_meat",3)
	expect(app.rules.apply(next,"accepted_kills_drop_fixture"),"prepare hunt and dropped meat")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.navigate_village_objective("nv_hunt")
	expect("正在接近鸡肉" in app.pending_message,"hunt guide targets ground meat after required kills")
	expect(app.rules.state==before and app.rules.state.inventory.get("chicken_meat",0)==0,"guidance does not auto-pickup or grant meat")
	expect(not app.world.player.route.is_empty() and app.world.player.route.back()==target,"path ends at dropped meat")
	for i in range(600):
		app._process(1.0/60)
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	expect(app.world.player.cell==target,"main loop walks to meat")
	expect(app.rules.state.inventory.get("chicken_meat",0)==0,"arrival alone does not pick up meat")
	for pressed in [true,false]:
		var e:=InputEventKey.new();e.physical_keycode=KEY_G;e.keycode=KEY_G;e.pressed=pressed;root.push_input(e,true);await settle()
	expect(app.rules.state.inventory.get("chicken_meat",0)==3,"G picks up quest material through gameplay")
	expect(app.rules.state.ground_loot.is_empty(),"picked ground entry removed")
	app.navigate_village_objective("nv_hunt")
	for i in range(600):
		app._process(1.0/60)
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	expect(app.rules.story_near("border:elder","0",app.world.player.cell),"ready task navigation returns to elder")
	app.show_controller_story(app.rules.story_npc("border:elder"));await settle()
	var view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id=="nv_hunt":view.cursor=i;view.list.select(i);break
	for tap in range(2):
		for pressed in [true,false]:
			var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_A;e.pressed=pressed;root.push_input(e,true);await settle()
	expect(app.rules.state.quests.nv_hunt=="done" and app.rules.state.inventory.get("chicken_meat",0)==0,"A submits after return and consumes three meat")
	expect(app.store.load_world("meat-nav").quests.nv_hunt=="done","delivery persisted")
	var report:={"checks":checks,"failures":failures,"scope":"main-loop walk to nearby drop and elder, G pickup, joypad A delivery; accepted kills and drop fixture, no natural combat or physical hardware"}
	FileAccess.open("res://../artifacts/world-story/novice-meat-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
