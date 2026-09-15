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
	app.store.path="/tmp/dark-entry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var character:={"id":"dark-entry","name":"暗殿访客","job":"战士","gender":"男"}
	app.start_character(character);app.world.hide()
	expect(not app.dark_temple.enter(),"remote entry refused")
	var npc: Dictionary=app.rules.story_npc(app.dark_temple.NPC)
	app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_dark_rumor="done";prepared.tracked_story="story_dark_entry"
	expect(app.rules.apply(prepared,"prior_story_fixture"),"prepare prior rumor task")
	expect(app.rules.story_action("story_dark_entry","accept",npc.id,npc.map,app.world.player.cell),"accept actual exploration task beside elder")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.dark_temple.enter() and app.world.metadata.id==npc.map and app.rules.state==before,"entry write failure rolls back map and state")
	app.store.db.query("PRAGMA query_only=OFF;")
	app.navigate_tracked_quest();await settle()
	expect(app.windows.windows.has("未知暗殿入口") and app.rules.state==before,"tracking opens elder entry guidance without teleport")
	await click_named("前往暗殿老人")
	for i in range(240):
		app.world.player.update(1.0/60,Vector2i.ZERO,false)
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
	expect(app.near_reference_npc(npc),"tracking approaches elder")
	app.show_reference_npc(npc);await settle()
	await click_named("未知暗殿 · 限时进入")
	expect(app.windows.windows.has("未知暗殿 · 老人的指引") and app.rules.state==before,"elder menu opens timed service without state mutation")
	var enter_button: Button=find_button("进入未知暗殿 · 免费 · 180 分钟")
	expect(enter_button!=null,"timed service has entry action")
	if enter_button!=null:
		for i in range(12):
			if root.gui_get_focus_owner()==enter_button:break
			await joy(JOY_BUTTON_DPAD_DOWN)
		expect(root.gui_get_focus_owner()==enter_button,"controller navigation reaches entry button")
		await joy(JOY_BUTTON_A)
	expect(app.world.metadata.id=="m001","A enters via service button")
	expect(app.world.metadata.id=="m001" and app.world.navigation.mobile(app.world.player.cell),"implicit destination resolves to mobile cell")
	expect(app.rules.state.gold==before.gold and app.rules.state.inventory==before.inventory,"entry does not invent fee or item consumption")
	expect(EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_dark_entry")),"entry records exploration objective")
	expect(app.dark_temple.time_text()=="暗殿剩余 03:00:00","three-hour timer visible")
	app.world.paused=true;var now: float=app.elapsed;app._process(120)
	expect(app.elapsed==now and app.dark_temple.state().active,"pause freezes timer")
	app.world.paused=false;app.elapsed+=10;app.save_world()
	var remaining: float=app.dark_temple.state().deadline-app.elapsed
	app.start_character(character);app.world.hide()
	expect(app.world.metadata.id=="m001" and app.dark_temple.state().deadline-app.elapsed==remaining,"reload retains remaining running time")
	var state_before_warning: Dictionary=app.rules.state.duplicate(true)
	app.elapsed=float(app.dark_temple.state().deadline)-300
	app.world.paused=true;var chats: int=app.chat_history.size();app.dark_temple.update()
	expect(app.chat_history.size()==chats,"paused expedition does not issue warning")
	app.world.paused=false;app.dark_temple.update()
	expect(app.chat_history.size()==chats+1 and "不足五分钟" in app.pending_message,"five-minute warning reaches chat")
	app.dark_temple.update()
	expect(app.chat_history.size()==chats+1,"five-minute warning not repeated every update")
	app.elapsed=float(app.dark_temple.state().deadline)-60;app.dark_temple.update()
	expect(app.chat_history.size()==chats+2 and "不足一分钟" in app.pending_message,"one-minute warning reaches chat")
	app.dark_temple.update()
	expect(app.chat_history.size()==chats+2 and app.rules.state==state_before_warning,"warning repetition changes no persistent rewards or progress")
	app.world.paused=false;app.elapsed=app.dark_temple.state().deadline
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.dark_temple.expire() and app.world.metadata.id=="m001" and app.rules.state==before,"return failure retains active session and location")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.dark_temple.expire() and app.world.metadata.id==npc.map and app.near_reference_npc(npc),"expired session returns to departure neighborhood")
	expect(not app.store.load_world(character.id).dark_temple.active and app.dark_temple.time_text().is_empty(),"ended session persists and timer clears")
	expect(not app.dark_temple.expire(),"return cannot repeat")
	app.show_story(npc);await settle()
	var story_view=app.form.get_child(1);story_view.selected="story_dark_entry";story_view.refresh();await settle()
	expect(story_view.submit_control!=null and not story_view.submit_control.disabled,"returned explorer has enabled submission control")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	await click_control(story_view.submit_control)
	expect(app.rules.state==before,"failed UI delivery preserves visit and rewards")
	expect(not "新委托：" in app.rules.message,"failed delivery never announces an unlock")
	app.store.db.query("PRAGMA query_only=OFF;")
	await click_control(story_view.submit_control)
	expect(app.rules.state.quests.story_dark_entry=="done" and app.rules.state.gold==before.gold+360,"UI delivery pays easy-mode reward exactly once")
	expect(app.store.load_world(character.id).quests.story_dark_entry=="done","UI delivery persists completion")
	expect("新委托：外表之外的记录（找老人）" in app.rules.message,"successful delivery announces eligible next quest and giver")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action("story_dark_entry","submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==before,"repeat delivery rejected")
	expect(app.rules.story_action("story_dark_records","accept",npc.id,npc.map,app.world.player.cell),"delivery unlocks and accepts follow-up battle commission")
	expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_dark_records")),"visit alone does not satisfy battle commission")
	app.windows.close_all()
	for malformed in [{"active":true},{"active":true,"deadline":0,"return_map":"3","return_cell":[1,1]},{"active":true,"deadline":0,"return_map":"e603","return_cell":[-1,1]}]:
		var damaged: Dictionary=app.rules.state.duplicate(true);damaged.dark_temple=malformed
		expect(not app.rules.valid(damaged),"invalid timed return data rejected")
	expect(app.dark_temple.enter(),"begin second expedition")
	before=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.save_location("3",Vector2i(338,333),app.elapsed) and app.rules.state==before,"failed departure leaves session and location together")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.save_location("3",Vector2i(338,333),app.elapsed),"departure saves")
	var departed: Dictionary=app.store.load_world(character.id)
	expect(departed.map=="3" and not departed.dark_temple.active,"departure and session end persist in same transaction before update")
	app.start_character(character);app.world.hide();app.elapsed+=20000;app.dark_temple.update()
	expect(app.world.metadata.id=="3" and not app.dark_temple.state().active,"reload after early departure never recalls player")
	app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	expect(app.dark_temple.enter(),"begin expedition for death case")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.receive_damage(99999,false,app.elapsed) and app.rules.state==before,"failed lethal damage preserves alive session")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.receive_damage(99999,false,app.elapsed),"lethal damage commits")
	var dead: Dictionary=app.store.load_world(character.id)
	expect(dead.hp==0 and not dead.dark_temple.active,"death and session end persist together before next frame")
	app.elapsed+=20000;app.dark_temple.update()
	expect(app.world.metadata.id=="m001" and app.rules.state.hp==0,"old timer does not recall dead character")
	app.start_character({"id":"dark-stone","name":"暗殿返乡","job":"战士","gender":"男"});app.world.hide()
	app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	var supplies: Dictionary=app.rules.state.duplicate(true)
	expect(app.rules.count_item(supplies,"return_stone",1) and app.rules.apply(supplies,"return_supply_fixture"),"prepare one return stone")
	expect(app.dark_temple.enter(),"enter for actual return-item test")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.gameplay.use_type("return_stone") and app.world.metadata.id=="m001" and app.rules.state==before,"failed return item keeps map stone and timer")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.gameplay.use_type("return_stone"),"use actual return stone gameplay operation")
	expect(app.world.metadata.id=="0" and app.rules.state.inventory.get("return_stone",0)==0 and not app.dark_temple.state().active,"stone returns to village consumes once and ends dark timer")
	app.elapsed+=20000;app.dark_temple.update()
	expect(app.world.metadata.id=="0","return stone destination not overwritten by old recall")
	var report:={"checks":checks,"failures":failures,"scope":"actual quest acceptance, viewport mouse elder service navigation and joypad entry, recall/reload, departure and lethal damage transaction tests; initial position/prior rumor fixtures, accelerated deadline, no three-hour soak or hardware input"}
	FileAccess.open("res://../artifacts/world-story/dark-entry-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

func find_button(title: String) -> Button:
	for candidate in app.panel.navigation_buttons(app.panel.body):
		if candidate.text==title:return candidate
	return null
func click_named(title: String) -> void:
	var button:=find_button(title)
	expect(button!=null,"mouse button exists: "+title)
	if button==null:return
	app.panel.scroll.ensure_control_visible(button);await settle()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button.get_global_rect().get_center();event.global_position=event.position;root.push_input(event,true)
	await settle()
func joy(key: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=pressed;root.push_input(event,true);await settle()

func click_control(button: Button) -> void:
	var ancestor=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button.get_global_rect().get_center();event.global_position=event.position;root.push_input(event,true)
	await settle()
