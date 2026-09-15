extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func has_text(node: Node,value: String) -> bool:
	if node is Label and value in node.text:return true
	for child in node.get_children():
		if has_text(child,value):return true
	return false
func press(key: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=true;root.push_input(event,true);await settle()
func click(button: Button) -> void:
	var ancestor: Node=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.position=button.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func find_button(text: String) -> Button:
	for button in app.panel.navigation_buttons(app.panel.body):
		if button.text==text:return button
	return null
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/guild-supplies-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"supplies","name":"行会补给","gender":"男","job":"战士"})
	var q: Dictionary=EditionRules.Story.quest("story_guild_supplies");var npc: Dictionary=app.rules.story_npc(q.start_npc);var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i(0,1)
	app.enter_map(npc.map,at);app.rules.save_location(npc.map,at,app.elapsed);app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_traveler_guild="done";next.inventory.potion=3;next.inventory.mana=3;next.guild={};app.rules.apply(next,"supply_fixture")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept supply task")
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"no membership refuses without consuming")
	app.show_social();await settle()
	for i in range(3):await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_A)
	expect(app.rules.state.guild.get("members",[]).has("云游客"),"controller creates actual guild")
	await press(JOY_BUTTON_B)
	expect(not app.windows.windows.has("玛法旅人"),"controller closes social window")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"failed transaction keeps inventory and guild ledger")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"supply submission succeeds")
	expect(app.rules.state.inventory.get("potion",0)==0 and app.rules.state.inventory.get("mana",0)==0,"six bottles leave backpack")
	expect(app.rules.state.guild.supplies=={"potion":3,"mana":3} and app.rules.state.guild.contribution==6,"exact reserve and contribution without easy multiplier")
	expect("行会贡献 6" in app.rules.quest_receipt_text(q.id),"receipt describes contribution")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"duplicate submission changes nothing")
	var saved: Dictionary=app.store.load_world(app.rules.character.id)
	expect(JSON.parse_string(JSON.stringify(saved.guild.supplies))==JSON.parse_string(JSON.stringify(before.guild.supplies)) and saved.guild.contribution==6,"reserve persisted")
	expect(JSON.parse_string(JSON.stringify(saved.quest_receipts[q.id].guild_supplies))==JSON.parse_string(JSON.stringify(before.guild.supplies)),"receipt persisted atomically")
	expect("6" in app.rules.story_guild_reward_text(q) and "不随档位翻倍" in app.rules.story_guild_reward_text(q),"shared reward explanation states contribution rule")
	app.show_story();await settle();var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	expect(has_text(view,"行会贡献：6"),"mouse guild task detail states contribution")
	app.game_panel("手柄人物委托",Vector2(520,430));view=load("res://scripts/edition2011/ui/controller_npc.gd").new();app.form.add_child(view);view.setup(app,npc)
	for i in range(view.rows.size()):
		if view.rows[i].id==q.id:view.cursor=i
	view.open_detail();await settle()
	expect("行会贡献：6" in view.text.text,"controller task detail states contribution")
	app.show_social();await settle();expect(app.form.get_child_count()>5,"guild reserve panel populated")
	var traveler: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler" and e.name=="云游客")[0]
	traveler.cell=[app.world.player.cell.x+1,app.world.player.cell.y]
	next=app.rules.state.duplicate(true);next.traveler_health={traveler.id:{"hp":240,"generation":0,"respawn":0}};next.party=[];app.rules.apply(next,"wounded_fixture");app.gameplay.sync_travelers()
	before=app.rules.state.duplicate(true)
	expect(not app.rules.guild_aid(traveler,app.world.metadata.id,app.world.player.cell) and app.rules.state==before,"outsider party cannot consume guild medicine")
	app.rules.social("party","云游客")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	app.gameplay.guild_aid()
	expect(app.rules.state==before and traveler.hp==240,"failed aid keeps stock and live actor health")
	app.store.db.query("PRAGMA query_only=OFF;")
	app.world.paused=true;app.gameplay.guild_aid();expect(app.rules.state==before,"paused aid changes nothing");app.world.paused=false
	app.gameplay.guild_aid()
	expect(traveler.hp==250 and app.rules.state.guild.supplies.potion==2,"aid caps health and consumes one stock bottle")
	expect(not app.rules.state.guild.get("aid_log",[]).is_empty() and app.rules.state.guild.aid_log[-1].healed==10,"aid ledger records actual recovery")
	before=app.rules.state.duplicate(true);app.gameplay.guild_aid()
	expect(app.rules.state==before,"full health repeat consumes nothing")
	saved=app.store.load_world(app.rules.character.id)
	expect(saved.guild.supplies.potion==2 and saved.traveler_health[traveler.id].hp==250,"aid health and stock persisted together")
	next=app.rules.state.duplicate(true);next.mp=app.rules.max_mp();expect(app.rules.apply(next,"full_mana_fixture"),"prepare full mana")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.guild_mana() and app.rules.state==before,"full mana preserves donated stock")
	next=before.duplicate(true);next.mp=app.rules.max_mp()-20;expect(app.rules.apply(next,"mana_deficit_fixture"),"prepare mana deficit")
	app.show_social();await settle();before=app.rules.state.duplicate(true)
	app.world.paused=true;await click(find_button("用行会蓝药恢复自身法力"))
	expect(app.rules.state==before,"paused mouse mana aid preserves stock")
	app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;")
	await click(find_button("用行会蓝药恢复自身法力"));expect(app.rules.state==before,"failed mouse mana aid preserves stock and mana")
	app.store.db.query("PRAGMA query_only=OFF;");await click(find_button("用行会蓝药恢复自身法力"))
	expect(app.rules.state.mp==app.rules.max_mp() and app.rules.state.guild.supplies.mana==2,"mouse consumes donated bottle and caps actual mana recovery")
	expect(app.rules.state.guild.aid_log[-1].resource=="mp" and app.rules.state.guild.aid_log[-1].healed==20,"ledger records actual mana rather than life")
	expect(app.rules.state.inventory==before.inventory and app.rules.state.guild.contribution==before.guild.contribution,"reserve use preserves backpack and contribution")
	saved=app.store.load_world(app.rules.character.id)
	expect(saved.mp==app.rules.max_mp() and saved.guild.supplies.mana==2 and saved.guild.aid_log[-1].resource=="mp","mana stock and ledger saved together")
	app.show_guild_aid_log();await settle();expect(has_text(app.form,"20 点法力") and has_text(app.form,"10 点生命"),"mixed legacy life and new mana records render correctly")
	next=app.rules.state.duplicate(true);next.mp=0;next.hp=0;app.rules.apply(next,"dead_mana_fixture");before=app.rules.state.duplicate(true)
	expect(not app.rules.guild_mana() and app.rules.state==before,"dead member cannot use reserve")
	next=before.duplicate(true);next.hp=100;next.guild.members=[];app.rules.apply(next,"nonmember_fixture");before=app.rules.state.duplicate(true)
	expect(not app.rules.guild_mana() and app.rules.state==before,"nonmember cannot use reserve")
	next=before.duplicate(true);next.guild.members=[app.rules.character.name];next.guild.supplies.erase("mana");app.rules.apply(next,"empty_mana_fixture");before=app.rules.state.duplicate(true)
	expect(not app.rules.guild_mana() and app.rules.state==before,"empty reserve cannot grant mana")
	var report:={"checks":checks,"failures":failures,"scope":"viewport controller guild creation and close, mouse/controller reward details and actual task transactions, no-membership and write failure, repeat prevention and DB reload; prerequisites, inventory and initial position fixtures; red-potion field aid and mouse blue-potion self aid included with cap/pause/read-only/death/nonmember/empty stock/ledger persistence; combat journey and physical controller untested"}
	FileAccess.open("res://../artifacts/world-story/guild-supplies-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
