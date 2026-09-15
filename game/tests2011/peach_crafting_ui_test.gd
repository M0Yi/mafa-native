extends SceneTree
const Craft=preload("res://scripts/edition2011/peach_crafting.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func find_button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=find_button(child,title)
		if found!=null:return found
	return null
func click(button: Control) -> void:
	var parent=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.position+=Vector2(button.get_window().position) if button.get_window()!=root else Vector2.ZERO;e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/peach-craft-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"craft-ui","name":"桃源配方","job":"战士","gender":"男"});app.world.hide()
	var npc: Dictionary=app.rules.story_npc(Craft.NPC)
	expect(app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1])),"prepare crafter location");app.world.paused=false
	var recipe: Dictionary=Craft.recipes()[0]
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=1000;next.level=60;next.quests.story_peach_witnesses="done"
	for id in recipe.materials:app.rules.count_item(next,id,int(recipe.materials[id]))
	expect(app.rules.apply(next,"craft_ui_material_fixture"),"prepare seven materials")
	next=app.rules.state.duplicate(true);app.rules.count_item(next,"ref:284",1);expect(app.rules.apply(next,"second_weapon_fixture"),"prepare second same-name weapon")
	next=app.rules.state.duplicate(true);var weapons: Array=next.items.filter(func(i):return i.container=="inventory" and i.type=="ref:284")
	weapons[0].durability=80;weapons[1].durability=23
	var kept_uid: String=weapons[0].uid;var consumed_uid: String=weapons[1].uid
	expect(app.rules.apply(next,"distinct_weapon_wear_fixture"),"prepare distinct weapon durability")
	app.show_story(npc);await settle();var story=app.form.get_child(1)
	story.selected="story_peach_red_blade";story.refresh();await settle()
	expect(story.submit_control!=null and not story.submit_control.disabled,"crafting commission available")
	await click(story.submit_control)
	expect(app.rules.state.quests.get("story_peach_red_blade")=="accepted","mouse accepts crafting commission")
	var open_service=find_button(story,"打开合成服务")
	expect(open_service!=null,"task provides crafting service action")
	await click(open_service);await settle();var craft_form=app.form
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"recipe panel fits minimum window")
	var button=find_button(app.form,"赤血魔剑 · 100 金币")
	expect(button!=null,"recipe action exists")
	if button==null:quit(1);return
	var before: Dictionary=app.rules.state.duplicate(true)
	var source_button=find_button(app.form,"材料来源 · 赤血魔剑")
	expect(source_button!=null,"recipe source action visible")
	await click(source_button)
	expect(app.windows.order.back()=="合成材料来源" and app.rules.state==before,"source viewing is read-only")
	for type in recipe.materials:
		var sources: Array=Craft.material_sources(type)
		expect(not sources.is_empty(),"material has enabled drop source "+type)
		expect(EditionRegion.material_suppliers(type).all(func(row):return row.npc.id!=Craft.NPC),"crafting NPC is not a purchase supplier")
	expect(Craft.material_sources("ref:226")[0].exchange=="server:merchant:105","gold bar directs to actual exchange NPC")
	app.windows.close("合成材料来源");await settle()
	await click(button)
	expect(app.windows.modal.visible and app.rules.state==before,"opening confirmation consumes nothing")
	for id in recipe.materials:expect(str(EditionRules.ITEMS[id].name) in app.windows.modal.dialog_text,"confirmation identifies material")
	expect("耐久23%" in app.windows.modal.dialog_text and not "耐久80%" in app.windows.modal.dialog_text,"quote selects exact later weapon instance")
	expect("耐久" in app.windows.modal.dialog_text and "背包格" in app.windows.modal.dialog_text,"confirmation identifies equipment instance")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(Rect2(Vector2(app.windows.modal.position),Vector2(app.windows.modal.size))),"seven-material confirmation fits minimum window")
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://../artifacts/world-story/peach-crafting-confirm-800.png")
	await click(app.windows.modal.get_cancel_button())
	expect(not app.windows.modal.visible and app.rules.state==before,"mouse cancellation preserves everything")
	await click(button)
	next=app.rules.state.duplicate(true);next.gold+=1;app.rules.apply(next,"change_after_quote_fixture");before=app.rules.state.duplicate(true)
	await click(app.windows.modal.get_ok_button())
	expect(app.rules.state==before and "重新查看" in app.rules.message,"stale confirmation rejected")
	await click(button);app.world.paused=true;await click(app.windows.modal.get_ok_button())
	expect(app.rules.state==before,"pause blocks confirmation");app.world.paused=false
	await click(button);app.store.db.query("PRAGMA query_only=ON;");await click(app.windows.modal.get_ok_button())
	expect(app.rules.state==before,"mouse write failure rolls back")
	app.store.db.query("PRAGMA query_only=OFF;");await click(button);await click(app.windows.modal.get_ok_button())
	expect(int(app.rules.state.inventory.get(recipe.product,0))==1 and app.rules.state.gold==before.gold-100,"mouse confirmation crafts once")
	expect(EditionInventory.find_item(app.rules.state,consumed_uid).is_empty() and int(EditionInventory.find_item(app.rules.state,kept_uid).get("durability",-1))==80,"craft consumes quoted instance and preserves other weapon")
	before=app.rules.state.duplicate(true);await click(button)
	expect("还缺" in app.windows.modal.dialog_text,"next attempt names missing materials")
	await click(app.windows.modal.get_ok_button());expect(app.rules.state==before,"missing materials do not charge")
	expect(EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_peach_red_blade")),"successful UI craft makes commission ready")
	await click(find_button(craft_form,"故事与委托"));story=app.form.get_child(1)
	expect(story.selected=="story_peach_red_blade","return entry automatically selects ready commission")
	expect(story.submit_control!=null and story.submit_control.text=="交付委托" and not story.submit_control.disabled,"crafted commission exposes delivery")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	await click(story.submit_control)
	expect(app.rules.state==before,"failed mouse delivery preserves sword and progress")
	app.store.db.query("PRAGMA query_only=OFF;");await click(story.submit_control)
	expect(app.rules.state.quests.get("story_peach_red_blade")=="done" and app.rules.state.gold==before.gold+120,"mouse delivers commission with configured reward")
	expect(app.rules.state.items==before.items,"commission leaves crafted sword and spare weapon untouched")
	before=app.rules.state.duplicate(true);await click(story.submit_control)
	expect(app.rules.state==before,"completed commission cannot reward twice")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport mouse task accept, open service, recipe/confirmation/cancel/retry and delivery, minimum window screenshot; prerequisite/material/level/position fixtures, no physical input or natural acquisition"}
	FileAccess.open("res://../artifacts/world-story/peach-crafting-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
