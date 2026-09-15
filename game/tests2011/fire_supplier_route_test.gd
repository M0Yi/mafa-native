extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func find_button(node: Node):
	if node is Button and node.text.begins_with("寻找道术补给："):return node
	for child in node.get_children():
		var result=find_button(child)
		if result!=null:return result
	return null
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/fire-supplier-route-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"supplier","name":"道术补给","gender":"男","job":"道士"})
	var entrance: Dictionary=app.rules.story_npc(EditionFireDragon.ENTRANCE)
	app.enter_map("3",Vector2i(entrance.cell[0],entrance.cell[1])+Vector2i.DOWN);app.world.paused=false
	var merchant: Dictionary=app.fire_dragon.supply_merchant()
	expect(merchant.id=="server:merchant:75" and merchant.map=="3","find actual local dual-material supplier")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.fire_dragon.panel(entrance);await settle();var button=find_button(app.panel)
	expect(button!=null,"entry has actionable supplier navigation")
	if button!=null:
		app.panel.scroll.ensure_control_visible(button);await settle()
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=button.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
		e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
		expect(not app.world.player.route.is_empty(),"mouse navigation begins real walking")
		for frame in range(1800):
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
		expect(Vector2(app.world.player.cell-Vector2i(merchant.cell[0],merchant.cell[1])).length()<=1.5,"walk ends beside supplier")
		expect(app.rules.state==before,"navigation does not buy or teleport")
	app.enter_map("0",Vector2i(325,250));app.world.paused=false
	expect(app.fire_dragon.supply_merchant().map=="0","Bichon prefers its own verified supplier")
	var report:={"checks":checks,"failures":failures,"scope":"actual shop catalog and map geometry, real mouse event plus continuous player walking; initial position fixture, actors frozen, no purchase in this test"}
	FileAccess.open("res://../artifacts/world-story/fire-supplier-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
