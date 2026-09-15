extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-supplies-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"supplies","name":"补给检查","job":"战士","gender":"男"});app.world.hide()
	var npc: Dictionary=app.rules.story_npc("server:merchant:141")
	app.show_story(npc);await settle()
	var view=app.form.get_child(1);view.selected="story_seal_mine";view.refresh();await settle()
	var button: Button=null
	for child in view.details.get_children():
		if child is Button and child.text=="出发前查看补给":button=child
	expect(button!=null,"mouse task exposes supplies")
	var before: Dictionary=app.rules.state.duplicate(true)
	if button!=null:
		view.details.get_parent().ensure_control_visible(button);await settle()
		for pressed in [true,false]:
			var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=button.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
		await settle()
	expect(app.windows.windows.has("远行补给") and app.rules.state==before,"mouse opens read-only supplies")
	expect(not EditionRegion.material_suppliers("potion").is_empty() and not EditionRegion.material_suppliers("mana").is_empty(),"both medicine types have actual vendors")
	app.windows.close_all();app.show_controller_story(npc);await settle();view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id=="story_seal_mine":view.cursor=i;break
	view.open_detail();await settle()
	expect("L3 远行补给" in view.hint.text,"controller advertises supplies")
	for pressed in [true,false]:
		var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_LEFT_STICK;e.pressed=pressed;root.push_input(e,true);await settle()
	expect(app.windows.windows.has("远行补给") and app.rules.state==before,"L3 opens read-only supplies")
	for medicine in ["potion","mana"]:
		app.windows.close_all();app.show_story_supplies();await settle()
		var choice: Button=null
		for candidate in app.panel.navigation_buttons(app.panel.body):
			if candidate.text=="寻找售药商人 · "+str(EditionRules.ITEMS[medicine].name):choice=candidate
		expect(choice!=null,"medicine has distinct button "+medicine)
		if choice!=null:await click_button(choice)
		expect(app.windows.windows.has("寻找材料商人"),"medicine button opens actual supplier page "+medicine)
		var labels: PackedStringArray=[]
		for child in app.form.get_children():
			if child is Label:labels.append(child.text)
		expect(("购买"+str(EditionRules.ITEMS[medicine].name)) in "\n".join(labels),"callback retains selected medicine "+medicine)
		expect(app.rules.state==before,"browsing vendor does not purchase "+medicine)
	app.windows.close_all();app.show_controller_story(app.rules.story_npc("server:merchant:9"));await settle();view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id=="story_field_book":view.cursor=i;break
	view.open_detail();await settle()
	expect("L3 掉书来源" in view.hint.text and not "L3 远行补给" in view.hint.text,"skill quest retains L3 book hint")
	for pressed in [true,false]:
		var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_LEFT_STICK;e.pressed=pressed;root.push_input(e,true);await settle()
	expect(app.windows.windows.has("技能书掉落来源") and app.rules.state==before,"L3 still opens skill book sources without learning or payment")
	var report:={"checks":checks,"failures":failures,"scope":"viewport mouse/L3 entry and actual vendor catalog; no purchase, travel or physical controller"}
	FileAccess.open("res://../artifacts/world-story/supplies-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

func click_button(button: Button) -> void:
	app.panel.scroll.ensure_control_visible(button);await settle()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=button.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
	await settle()
