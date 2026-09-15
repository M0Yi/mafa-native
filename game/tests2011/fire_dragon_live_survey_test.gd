extends SceneTree
var app
var checks:=0
var failures: Array=[]
var frames:=0
var minimum_hp:=100
var observed: Dictionary={}
var moved: Dictionary={}
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func step() -> void:
	app._process(1.0/60);frames+=1;minimum_hp=mini(minimum_hp,int(app.rules.state.hp))
	for entity in app.world.entities:
		if entity.kind not in ["monster","traveler"]:continue
		var key: String=app.world.metadata.id+":"+str(entity.id)
		if observed.has(key) and observed[key]!=entity.cell:moved[key]=true
		observed[key]=entity.cell.duplicate()
func walk_until_stopped() -> void:
	for i in range(12000):
		step()
		if app.rules.state.hp<=0 or (app.world.player.route.is_empty() and app.world.player.progress>=1.0):break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/dragon-live-survey-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"live-survey","name":"神殿见闻","job":"战士","gender":"男"});app.world.hide()
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.gold=1000;prepared.quests.story_dragon_route="done";prepared.tracked_story="story_dragon_survey"
	expect(app.rules.apply(prepared,"prior_journey_fixture"),"prepare prior journey and permit budget only")
	app.enter_map("3",Vector2i(338,333));app.world.paused=false
	var npc: Dictionary=app.rules.story_npc(EditionFireDragon.ENTRANCE)
	expect(app.rules.story_action("story_dragon_survey","accept",npc.id,npc.map,app.world.player.cell),"accept survey at entrance")
	expect(app.fire_dragon.buy_permit() and app.fire_dragon.enter(),"purchase and consume actual permit")
	var start_time: float=app.elapsed
	app.navigate_tracked_quest();walk_until_stopped()
	expect(app.rules.state.hp>0 and app.world.metadata.id==EditionFireDragon.MAP,"survive live approach in temple")
	expect(app.fire_dragon.state().get("surveyed",false),"live central approach records survey")
	expect(not moved.is_empty() and app.elapsed>start_time,"actors and expedition clock advance during approach")
	var intact: Dictionary=app.rules.state.duplicate(true)
	app.navigate_tracked_quest();await settle()
	expect(app.windows.windows.has("火龙神殿返程") and app.rules.state==intact,"completed task tracking offers guide without teleport or reward")
	var guide_button: Button=null
	for candidate in app.panel.navigation_buttons(app.panel.body):
		if candidate.text=="步行前往神殿接引员":guide_button=candidate
	expect(guide_button!=null,"return route exposes guide approach")
	if guide_button!=null:
		app.panel.scroll.ensure_control_visible(guide_button);await settle()
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=guide_button.get_global_rect().get_center();event.global_position=event.position;root.push_input(event,true)
		expect(not app.world.player.route.is_empty() and app.world.metadata.id==EditionFireDragon.MAP,"return button plans walking without remote teleport")
	walk_until_stopped()
	expect(app.rules.state.hp>0 and app.fire_dragon.near(EditionFireDragon.GUARD),"walk back to guide alive")
	expect(app.fire_dragon.leave(),"guide returns expedition to Mengzhong")
	expect(app.world.approach(Vector2i(npc.cell[0],npc.cell[1])),"approach entrance NPC after return")
	walk_until_stopped()
	expect(app.fire_dragon.near(npc.id),"reach original NPC without resetting return position")
	expect(app.rules.story_action("story_dragon_survey","submit",npc.id,npc.map,app.world.player.cell),"deliver story after live survey and return")
	expect(app.fire_dragon.claim(),"claim separate first survey service reward")
	var saved: Dictionary=app.store.load_world("live-survey")
	expect(saved.quests.story_dragon_survey=="done" and saved.fire_dragon.claimed and not saved.fire_dragon.active,"both rewards and ended expedition persist")
	app.windows.close_all()
	intact=app.rules.state.duplicate(true)
	app.approach_story_objective({"type":"collect","item":"dragon_story_scale","count":1});await settle()
	expect(app.windows.windows.has("火龙鳞片来源") and app.rules.state==intact,"missing scale opens source guidance without granting material")
	expect(app.panel.navigation_buttons(app.panel.body).any(func(b):return b.text=="前往盟重询问远征委托"),"unaccepted expedition directs to quest giver")
	expect(app.rules.story_action("story_dragon_trial","accept",npc.id,npc.map,app.world.player.cell),"survey completion unlocks actual boss commission")
	app.windows.close_all();intact=app.rules.state.duplicate(true)
	app.approach_story_objective({"type":"collect","item":"dragon_story_scale","count":1});await settle()
	expect(app.panel.navigation_buttons(app.panel.body).any(func(b):return b.text=="查看火龙教主目标") and app.rules.state==intact,"accepted expedition exposes boss source without material or kill credit")
	for material in ["dragon_story_scale","ore"]:
		var inventory_fixture: Dictionary=app.rules.state.duplicate(true)
		expect(app.rules.count_item(inventory_fixture,material,1,"warehouse") and app.rules.apply(inventory_fixture,"stored_material_fixture"),"prepare stored material "+material)
		app.windows.close_all();intact=app.rules.state.duplicate(true)
		app.approach_story_objective({"type":"collect","item":material,"count":10});await settle()
		expect(app.windows.windows.has("取回任务材料") and app.rules.state==intact,"stored material gets retrieval route without remote withdrawal "+material)
		expect(app.panel.navigation_buttons(app.panel.body).any(func(b):return b.text.begins_with("前往 ")),"warehouse route exists for "+material)
	var warehouse_button: Button=null
	for candidate in app.panel.navigation_buttons(app.panel.body):
		if candidate.text.begins_with("前往 "):warehouse_button=candidate;break
	expect(warehouse_button!=null and "悦来客栈老板" in warehouse_button.text,"same-map warehouse precedes remote alternatives")
	if warehouse_button!=null:
		app.panel.scroll.ensure_control_visible(warehouse_button);await settle()
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=warehouse_button.get_global_rect().get_center();event.global_position=event.position;root.push_input(event,true)
		walk_until_stopped()
	var keeper: Dictionary=app.rules.story_npc("server:merchant:66")
	expect(app.rules.state.hp>0 and app.near_reference_npc(keeper),"walk from returned expedition to Mengzhong warehouse keeper")
	app.show_controller_warehouse(keeper);await settle()
	expect(app.windows.windows.has("手柄仓库"),"reached keeper opens actual controller warehouse")
	if app.windows.windows.has("手柄仓库"):
		await joy(JOY_BUTTON_RIGHT_SHOULDER)
		var view=app.form.get_child(1)
		for i in range(view.rows.size()):
			if view.rows[view.cursor].type=="dragon_story_scale":break
			await joy(JOY_BUTTON_DPAD_DOWN)
		intact=app.rules.state.duplicate(true)
		app.world.paused=true;await joy(JOY_BUTTON_A)
		expect(app.rules.state==intact,"paused warehouse refuses withdrawal")
		app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;");await joy(JOY_BUTTON_A)
		expect(app.rules.state==intact,"failed warehouse write preserves scale and inventory")
		app.store.db.query("PRAGMA query_only=OFF;");await joy(JOY_BUTTON_A)
		expect(app.rules.state.inventory.get("dragon_story_scale",0)==1 and app.rules.state.warehouse.get("dragon_story_scale",0)==0,"A retrieves stored scale after retry")
		expect(app.rules.state.warehouse.get("ore",0)==1,"retrieving scale leaves other stored materials untouched")
		var restored: Dictionary=app.store.load_world("live-survey")
		expect(restored.inventory.get("dragon_story_scale",0)==1 and restored.warehouse.get("dragon_story_scale",0)==0,"retrieved material persists")
		expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_dragon_trial")),"retrieved scale does not bypass required boss kill")
	app.windows.close_all();app.show_story()
	var mouse_story=app.form.get_child(1);mouse_story.selected="story_dragon_trial";mouse_story.refresh();await settle()
	expect(mouse_story.material_lines.size()==1 and "背包 1，还差 0" in mouse_story.material_lines[0].label.text,"mouse task initially shows retrieved material")
	expect(app.rules.warehouse("dragon_story_scale",true),"deposit scale while mouse task stays open")
	await settle()
	expect("背包 0，还差 1" in mouse_story.material_lines[0].label.text and "仓库有 1，可先取回 1；取回后仍需获得 0" in mouse_story.material_lines[0].label.text,"mouse material summary refreshes after deposit")
	app.windows.close_all();app.show_controller_story(npc)
	var controller_story=app.form.get_child(1)
	for index in range(controller_story.rows.size()):
		if controller_story.rows[index].id=="story_dragon_trial":controller_story.cursor=index;break
	controller_story.open_detail();await settle()
	expect("背包 0，还差 1" in controller_story.text.text and "仓库有 1，可先取回 1" in controller_story.text.text,"controller task initially shows missing material")
	expect(app.rules.warehouse("dragon_story_scale",false),"retrieve scale while controller task stays open")
	await settle()
	expect("背包 1，还差 0" in controller_story.text.text and not "背包 0，还差 1" in controller_story.text.text and not "仓库有 1，可先取回 1" in controller_story.text.text,"controller material summary refreshes after withdrawal")
	var partial_quest: Dictionary=EditionRules.Story.quest("story_dragon_forge")
	expect("仓库有 1，可先取回 1；取回后仍需获得 9" in app.rules.story_materials_text(partial_quest),"partially stored ore reports remaining acquisition separately")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"minimum_hp":minimum_hp,"moving_entities":moved.size(),"scope":"all actors and main loop at simulated 60 Hz, live survey and return, both rewards, boss commission acceptance, material source guidance, mouse route to Mengzhong warehouse and joypad withdrawal with pause/write-failure retry; prior quest, budget, initial entrance position and stored materials fixtures, no hardware input or performance measurement"}
	FileAccess.open("res://../artifacts/world-story/dragon-live-survey-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

func joy(key: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=pressed;root.push_input(event,true);await settle()
