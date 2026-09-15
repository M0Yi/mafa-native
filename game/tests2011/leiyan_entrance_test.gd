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
	app.store.path="/tmp/leiyan-entrance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"leiyan","name":"龙鳞入口","gender":"男","job":"战士"});app.world.paused=false
	var npc: Dictionary=app.rules.story_npc("server:npc:18");var route: Dictionary=EditionRegion.teleports(npc.id)[0]
	expect(EditionRules.ITEMS.has("ref:503") and not app.resources.frame("items",822).is_empty(),"real scale and icon supported")
	app.show_story_route("d2081");await settle();expect(app.windows.windows.has("雷炎洞穴入口"),"task directs to material NPC instead of 153-map chain")
	app.windows.close_all();app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i(1,0))
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.teleport_with_npc(npc,route) and app.rules.state==before,"no scale leaves state and map unchanged")
	var next: Dictionary=before.duplicate(true);app.rules.count_item(next,"dragon_story_scale",1);app.rules.apply(next,"wrong_scale_fixture")
	expect(not app.teleport_with_npc(npc,route),"fire quest token cannot substitute")
	next=app.rules.state.duplicate(true);app.rules.count_item(next,"ref:503",1);app.rules.apply(next,"scale_fixture")
	next=app.rules.state.duplicate(true);next.quests.story_leiyan_entry="accepted";app.rules.apply(next,"accepted_survey_fixture")
	before=app.rules.state.duplicate(true);app.store.db.query("CREATE TEMP TRIGGER fail_teleport BEFORE INSERT ON operations WHEN NEW.action='reference_teleport' BEGIN SELECT RAISE(ABORT, 'injected teleport failure'); END;")
	expect(not app.teleport_with_npc(npc,route) and app.rules.state==before and app.world.metadata.id==npc.map,"failed teleport preserves scale and position")
	app.store.db.query("DROP TRIGGER fail_teleport;");app.show_reference_npc(npc);await settle()
	var go=find_button(app.form,"前往 进入雷炎洞穴一层 · 0 金币 + 龙鳞 ×1")
	expect(go!=null,"NPC button explains material cost")
	await click(go)
	expect(app.world.metadata.id=="d2081" and int(app.rules.state.inventory.get("ref:503",0))==0,"mouse entry consumes one scale")
	expect(app.rules.state.inventory.get("dragon_story_scale")==1,"quest token remains")
	expect(app.world.navigation.mobile(app.world.player.cell),"reference arrival can move")
	expect(EditionRules.Story.progress(app.rules.state,EditionRules.Story.quest("story_leiyan_entry"),0)==1,"successful debit records visit in same transaction")
	var loaded: Dictionary=app.store.load_world(app.rules.character.id)
	expect(loaded.map=="d2081" and int(loaded.inventory.get("ref:503",0))==0,"material and location commit together")
	before=app.rules.state.duplicate(true);expect(not app.teleport_with_npc(npc,route) and app.rules.state==before,"stale click cannot teleport again")
	var stone: Dictionary=app.rules.story_npc("server:npc:13")
	var portals: Array=EditionRegion.teleports(stone.id)
	expect(portals.size()==3,"three original city entry conditions enabled")
	for threshold in [0,36,40]:
		var portal: Dictionary=portals.filter(func(t):return int(t.min_level)==threshold)[0]
		app.enter_map(stone.map,Vector2i(stone.cell[0],stone.cell[1])+Vector2i(1,0))
		next=app.rules.state.duplicate(true);next.level=maxi(1,threshold);next.gold=int(portal.cost);app.rules.apply(next,"city_entry_fixture")
		if threshold>0:
			var low: Dictionary=app.rules.state.duplicate(true);low.level=threshold-1;app.rules.apply(low,"low_level_fixture")
			before=app.rules.state.duplicate(true);expect(not app.teleport_with_npc(stone,portal) and app.rules.state==before,"level gate rejects without debit")
			next=app.rules.state.duplicate(true);next.level=threshold;app.rules.apply(next,"level_restore_fixture")
		expect(app.teleport_with_npc(stone,portal) and app.rules.state.gold==0 and app.world.metadata.id=="6","original city price and level route works")
		expect(app.world.navigation.mobile(app.world.player.cell),"city arrival movable")
	var report:={"checks":checks,"failures":failures,"scope":"actual NPC and reference landing, mouse button, material debit and SQLite failure; item grants and NPC approach are fixtures, real scale drop sampling pending"}
	FileAccess.open("res://../artifacts/world-story/leiyan-entrance-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
