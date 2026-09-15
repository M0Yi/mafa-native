extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func find_button(node: Node):
	if node is Button and node.text.begins_with("前往 回到盟重"):return node
	for child in node.get_children():
		var found=find_button(child)
		if found!=null:return found
	return null
func click(button: Control) -> void:
	var ancestor=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=button.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/peach-return-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"peach","name":"桃源归客","job":"战士","gender":"男"});app.world.hide()
	var npc: Dictionary=app.rules.story_npc("server:merchant:127")
	expect(app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1])),"prepare elder location");app.world.paused=false
	app.show_reference_npc(npc);await settle();var button=find_button(app.form)
	expect(button!=null,"elder exposes return action")
	if button==null:quit(1);return
	var before: Dictionary=app.rules.state.duplicate(true);var origin: Vector2i=app.world.player.cell
	app.world.player.cell+=Vector2i(20,20);await click(button)
	expect(app.world.metadata.id=="r001" and app.rules.state==before,"distant elder action refused")
	app.world.player.cell=origin;app.world.paused=true;await click(button)
	expect(app.world.metadata.id=="r001" and app.rules.state==before,"paused elder action refused");app.world.paused=false
	app.store.db.query("PRAGMA query_only=ON;");await click(button)
	expect(app.world.metadata.id=="r001" and app.world.player.cell==origin and app.rules.state==before,"failed save restores origin and possessions")
	app.store.db.query("PRAGMA query_only=OFF;");await click(button)
	expect(app.world.metadata.id=="3" and app.rules.state.map=="3","mouse return changes runtime and saved map")
	expect(app.world.navigation.mobile(app.world.player.cell),"returned player can move")
	expect(EditionRegion.safe("3",app.world.player.cell),"return lands in registered safe zone")
	expect(app.rules.state.gold==before.gold and app.rules.state.items==before.items,"free return preserves gold and items")
	var saved: Dictionary=app.store.load_world("peach")
	expect(saved.map=="3" and Vector2i(saved.cell[0],saved.cell[1])==app.world.player.cell,"return position persisted")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.world.metadata.id=="3" and app.rules.state.cell==saved.cell,"restart retains return location")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport mouse elder return, distance/pause/write-failure rollback and reload; initial elder position fixture; reconstructed default landing, not original server coordinates or natural travel"}
	FileAccess.open("res://../artifacts/world-story/peach-return-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
