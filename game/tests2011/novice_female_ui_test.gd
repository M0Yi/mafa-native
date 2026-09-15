extends SceneTree
var app
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	if not ok:failures.append(note);printerr(note)
func settle() -> void:
	for i in range(8):await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/novice-female-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"female-ui","name":"女侠新手","job":"战士","gender":"女"});app.world.paused=false
	var elder: Dictionary=app.world.entities.filter(func(e):return e.id=="border:elder")[0]
	app.world.player.reset(Vector2i(elder.cell[0]+1,elder.cell[1]));app.interact(elder);await settle()
	var view=app.form.get_child(1)
	var preview: String=""
	for label in view.find_children("*","Label",true,false):preview+=label.text
	check(preview.contains("布衣(女)") or preview.contains("布衣（女）"),"mouse reward preview shows female robe")
	check(app.rules.novice_quest("nv_arrival") and app.rules.novice_quest("nv_arrival") and app.rules.novice_quest("nv_equip"),"receive first reward and accept second task")
	app.windows.close_all();app.show_bag();await settle()
	for type in ["wood_sword","ref:5"]:
		var grid=app.windows.windows["冒险面板"].body.get_child(1).content[0].get_child(0)
		var found:=false
		for slot in grid.cells.get_children():
			if slot.item.is_empty() or slot.item.type!=type:continue
			found=true
			var point: Vector2=slot.get_global_rect().get_center()
			for pressed in [true,false]:
				var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.double_click=pressed;root.push_input(event,true)
			break
		check(found,"reward appears in inventory: "+type);await settle()
	check(app.rules.state.equipment.get("armor")=="ref:5" and app.rules.state.equipment.get("weapon")=="wood_sword","viewport double clicks equip both starter items")
	app.windows.close_all();app.interact(elder);await settle();view=app.form.get_child(1)
	check(view.submit_control!=null and not view.submit_control.disabled and view.submit_control.text=="交付任务","second task turn-in enabled")
	check(app.rules.novice_quest("nv_equip"),"female character finishes second task")
	app.show_controller_story(elder);await settle();view=app.form.get_child(1);view.show_completed=true;view.refresh()
	for i in range(view.rows.size()):
		if view.rows[i].id=="nv_arrival":view.cursor=i;view.open_detail();break
	check(view.text.text.contains(EditionRules.ITEMS["ref:5"].name) and not view.text.text.contains(EditionRules.ITEMS["robe"].name),"controller reward detail also female")
	print(JSON.stringify({"failures":failures,"scope":"native task preview, viewport mouse double-click equipment, enabled second-task turn-in and controller reward detail; isolated save, no hardware input"}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
