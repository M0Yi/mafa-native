extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
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
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/sea-travel-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"sea","name":"航线核验","gender":"男","job":"战士"});app.world.paused=false
	var sailor: Dictionary=app.rules.story_npc("server:npc:8");var sea: Dictionary=EditionRegion.teleports(sailor.id).filter(func(t):return t.target_map=="5")[0]
	app.show_story_route("6");await settle();expect(app.windows.windows.has("魔龙城传送路线"),"distant demon quest points to transport")
	await click(find_button(app.form,"前往苍月传送石"));expect(app.windows.windows.has("苍月岛交通"),"island leg points to ferry NPC")
	var before: Dictionary=app.rules.state.duplicate(true)
	await click(find_button(app.form,"前往海边老人"));expect(app.rules.state==before,"guidance never pays or teleports")
	app.windows.close_all();app.enter_map(sailor.map,Vector2i(sailor.cell[0],sailor.cell[1])+Vector2i(1,0))
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=1999;app.rules.apply(next,"low_fare_fixture")
	before=app.rules.state.duplicate(true);expect(not app.teleport_with_npc(sailor,sea) and app.rules.state==before,"insufficient fare refused")
	next=app.rules.state.duplicate(true);next.gold=3000;app.rules.apply(next,"fare_fixture")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.teleport_with_npc(sailor,sea) and app.rules.state==before and app.world.metadata.id==sailor.map,"failed ferry write rolls back money and scene")
	app.store.db.query("PRAGMA query_only=OFF;");app.show_reference_npc(sailor);await settle()
	await click(find_button(app.form,"前往 苍月岛 · 2000 金币"))
	expect(app.world.metadata.id=="5" and app.rules.state.gold==1000,"mouse ferry pays original fare once")
	expect(app.world.navigation.mobile(app.world.player.cell),"island landing movable")
	var stone: Dictionary=app.rules.story_npc("server:npc:13");var city: Dictionary=EditionRegion.teleports(stone.id).filter(func(t):return int(t.min_level)==40)[0]
	app.enter_map(stone.map,Vector2i(stone.cell[0],stone.cell[1])+Vector2i(1,0));next=app.rules.state.duplicate(true);next.level=40;app.rules.apply(next,"level_fixture")
	expect(app.teleport_with_npc(stone,city) and app.world.metadata.id=="6","island continues to demon city via original level route")
	app.show_story_route("5");await settle();expect(find_button(app.form,"前往返程传送石")!=null,"city return points to original stone")
	var back: Dictionary=app.rules.story_npc("server:npc:14");var home: Dictionary=EditionRegion.teleports(back.id).filter(func(t):return t.target_map=="5")[0]
	app.windows.close_all();app.enter_map(back.map,Vector2i(back.cell[0],back.cell[1])+Vector2i(1,0));before=app.rules.state.duplicate(true)
	expect(app.teleport_with_npc(back,home) and app.world.metadata.id=="5" and app.rules.state.gold==before.gold,"return uses free reference route")
	expect(app.world.navigation.mobile(app.world.player.cell),"return landing movable")
	expect(app.store.load_world(app.rules.character.id).map=="5","return persisted")
	var report:={"checks":checks,"failures":failures,"scope":"actual NPCs and landing tiles, mouse guidance/ferry, fare rollback, city and return rules; NPC approach, funds and level are fixtures, continuous world travel pending"}
	FileAccess.open("res://../artifacts/world-story/sea-travel-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
