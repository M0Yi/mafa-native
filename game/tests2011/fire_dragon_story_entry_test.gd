extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func settle() -> void:
	for i in range(8):await process_frame
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/dragon-story-entry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"dragon-story-entry","name":"远征委托","job":"战士","gender":"男"})
	app.enter_map("3",Vector2i(338,333));app.world.paused=false
	var npc: Dictionary=app.rules.story_npc(EditionFireDragon.ENTRANCE)
	var before: Dictionary=app.rules.state.duplicate(true)
	app.fire_dragon.panel(npc);await settle()
	expect(app.form.find_child("SurveyReward",true,false).disabled,"uncompleted survey reward is disabled")
	var button: Button=null
	for candidate in app.panel.navigation_buttons(app.panel.body):
		if candidate.text=="查看勘察与远征委托":button=candidate
	expect(button!=null,"service page exposes story entry")
	if button!=null:
		app.panel.scroll.ensure_control_visible(button);await settle()
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button.get_global_rect().get_center();event.global_position=event.position;root.push_input(event,true)
		await settle()
		var view=app.form.get_child(1)
		expect(view.get_script().resource_path.ends_with("story_panel.gd"),"mouse opens actual story panel")
		if view.get_script().resource_path.ends_with("story_panel.gd"):
			expect(view.npc.id==npc.id and "story_dragon_survey" not in view.visible_quest_ids and "story_dragon_trial" not in view.visible_quest_ids,"locked survey and boss commissions hidden for new character")
	expect(app.rules.state==before,"viewing entry does not buy permit or grant either reward")
	app.windows.close_all();app.fire_dragon.panel(npc);await settle()
	var controller_button: Button=null
	for candidate in app.panel.navigation_buttons(app.panel.body):
		if candidate.text=="手柄勘察与远征委托":controller_button=candidate
	expect(controller_button!=null,"independent controller entry present")
	if controller_button!=null:
		for i in range(24):
			if root.gui_get_focus_owner()==controller_button:break
			await joy(JOY_BUTTON_DPAD_DOWN)
		expect(root.gui_get_focus_owner()==controller_button,"dpad reaches controller entry")
		await joy(JOY_BUTTON_A)
		var view=app.form.get_child(1)
		expect(view.get_script().resource_path.ends_with("controller_npc.gd"),"A opens independent controller task page")
		if view.get_script().resource_path.ends_with("controller_npc.gd"):
			expect(not view.rows.any(func(row):return row.id in ["story_dragon_survey","story_dragon_trial"]),"controller hides locked survey and boss tasks")
	expect(app.rules.state==before,"controller browsing does not advance dialogue or grant reward")
	for order in [["service","story"],["story","service"]]:
		app.windows.close_all();app.start_character({"id":"reward-order-"+order[0],"name":"勘察交付","job":"战士","gender":"男"});app.enter_map("3",Vector2i(338,333));app.world.paused=false
		var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_dragon_route="done";prepared.fire_dragon={"surveyed":true,"claimed":false}
		expect(app.rules.apply(prepared,"completed_survey_fixture"),"prepare completed survey and prior story")
		expect(app.rules.story_action("story_dragon_survey","accept",npc.id,npc.map,app.world.player.cell),"accept survey story")
		app.fire_dragon.panel(npc);await settle()
		expect(not app.form.find_child("SurveyReward",true,false).disabled,"completed unclaimed survey enables reward")
		var gold: int=app.rules.state.gold
		for kind in order:
			var intact: Dictionary=app.rules.state.duplicate(true)
			app.store.db.query("PRAGMA query_only=ON;")
			var failed: bool=app.fire_dragon.claim() if kind=="service" else app.rules.story_action("story_dragon_survey","submit",npc.id,npc.map,app.world.player.cell)
			expect(not failed and app.rules.state==intact,"failed reward preserves both claim states")
			app.store.db.query("PRAGMA query_only=OFF;")
			expect(app.fire_dragon.claim() if kind=="service" else app.rules.story_action("story_dragon_survey","submit",npc.id,npc.map,app.world.player.cell),"claim selected reward")
			if kind=="service":expect(app.rules.state.quests.story_dragon_survey==intact.quests.story_dragon_survey,"service claim does not change story lifecycle")
			else:expect(app.fire_dragon.state().claimed==intact.fire_dragon.claimed,"story claim does not change service reward flag")
		expect(app.rules.state.gold==gold+1000 and app.rules.state.quests.story_dragon_survey=="done" and app.fire_dragon.state().claimed,"both rewards pay exact current easy-mode total")
		app.fire_dragon.panel(npc);await settle()
		var reward_button: Button=app.form.find_child("SurveyReward",true,false)
		expect(reward_button.disabled and reward_button.text=="首次勘察奖励已领取","claimed reward clearly disabled")
		var claimed: Dictionary=app.rules.state.duplicate(true)
		expect(not app.fire_dragon.claim() and not app.rules.story_action("story_dragon_survey","submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==claimed,"neither reward can repeat")
	var report:={"checks":checks,"failures":failures,"scope":"native viewport mouse and joypad story entries; both service/story reward orders with read-only rollback; survey completion and location fixtures, no hardware input or natural survey travel"}
	FileAccess.open("res://../artifacts/world-story/dragon-story-entry-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

func joy(key: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=pressed;root.push_input(event,true);await settle()
