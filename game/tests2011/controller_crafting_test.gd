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
func press(key: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=key;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-craft-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"craft","name":"手柄合成","job":"战士","gender":"男"});app.world.hide()
	var npc: Dictionary=app.rules.story_npc(Craft.NPC);app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_peach_witnesses="done";next.level=60;next.gold=1000
	for id in Craft.recipes()[0].materials:app.rules.count_item(next,id,1)
	expect(app.rules.apply(next,"craft_material_fixture"),"prepare materials and prerequisite")
	app.controller_interact(npc);await settle();var task=app.form.get_child(1)
	for i in range(task.rows.size()):
		if task.rows[i].id=="story_peach_red_blade":task.cursor=i;break
	await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.get("story_peach_red_blade")=="accepted","controller accepts commission")
	await press(JOY_BUTTON_Y);var view=app.form.get_child(1)
	expect(app.windows.order.back()=="手柄桃源合成" and view.rows.size()==7,"independent seven-recipe controller panel")
	var before: Dictionary=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_DPAD_DOWN);expect(view.cursor==1,"dpad selects next recipe");await press(JOY_BUTTON_DPAD_UP)
	await press(JOY_BUTTON_A)
	expect(view.phase=="confirm" and "背包格" in view.detail.text and app.rules.state==before,"A previews exact materials without consumption")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()) and app.panel.get_global_rect().encloses(view.hint.get_global_rect()),"confirmation and hints fit minimum window")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://../artifacts/world-story/controller-crafting-800.png")
	await press(JOY_BUTTON_B);expect(view.phase=="list" and app.rules.state==before,"B cancels safely")
	await press(JOY_BUTTON_Y);expect(view.phase=="sources" and "基础" in view.detail.text and app.rules.state==before,"Y shows read-only material sources");await press(JOY_BUTTON_B)
	await press(JOY_BUTTON_A);next=app.rules.state.duplicate(true);next.gold+=1;app.rules.apply(next,"stale_quote_fixture");before=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_A);expect(app.rules.state==before and "重新查看" in view.feedback,"stale confirmation refuses consumption")
	await press(JOY_BUTTON_A);app.world.paused=true;await press(JOY_BUTTON_A)
	expect(app.rules.state==before,"pause blocks crafting");app.world.paused=false
	await press(JOY_BUTTON_A);app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A)
	expect(app.rules.state==before,"write failure preserves materials and progress")
	app.store.db.query("PRAGMA query_only=OFF;");await press(JOY_BUTTON_A);await press(JOY_BUTTON_A)
	expect(int(app.rules.state.inventory.get("ref:293",0))==1 and app.rules.state.gold==before.gold-100,"controller crafts once")
	expect(EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_peach_red_blade")),"craft makes task ready")
	await press(JOY_BUTTON_B)
	expect(app.windows.order.back()=="手柄人物委托" and not task.reading and task.rows[task.cursor].id=="story_peach_red_blade","B returns to same task")
	await press(JOY_BUTTON_A);await press(JOY_BUTTON_Y);await press(JOY_BUTTON_B)
	expect(app.windows.order.back()=="手柄人物委托" and task.reading and task.rows[task.cursor].id=="story_peach_red_blade","opening from detail restores detail")
	before=app.rules.state.duplicate(true);await press(JOY_BUTTON_A)
	expect(app.rules.state.quests.get("story_peach_red_blade")=="done" and app.rules.state.items==before.items,"controller delivers without consuming sword")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport joypad task accept, recipe navigation, preview/cancel/sources/stale/pause/write failure/retry and delivery; prerequisite/material/position fixtures, no physical controller or natural acquisition"}
	FileAccess.open("res://../artifacts/world-story/controller-crafting-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	var path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)
