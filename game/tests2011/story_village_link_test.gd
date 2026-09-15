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
func click(view, prefix: String) -> void:
	var button: Button=null
	for child in view.details.get_children():
		if child is Button and child.text.begins_with(prefix):button=child;break
	expect(button!=null,"link exists: "+prefix)
	if button==null:return
	view.details.get_parent().ensure_control_visible(button);await settle()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=button.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-village-link-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"links","name":"村庄口信","job":"战士","gender":"男"});app.world.hide()
	var before: Dictionary=app.rules.state.duplicate(true)
	# Exercise both a new adventure window and an existing one left on its journey tab.
	for reuse in [false,true]:
		app.windows.close_all()
		if reuse:
			app.show_adventure(4)
			var existing=app.windows.windows["冒险面板"].body.get_child(1)
			existing.content[4].tab=1;existing.content[4].refresh()
		app.show_quest_entry("story_letter");await settle()
		var story=app.form.get_child(1)
		await click(story,"查看前置：")
		expect(app.windows.order.back()=="冒险面板","prerequisite activates village panel")
		if not app.windows.windows.has("冒险面板"):continue
		var adventure=app.windows.windows["冒险面板"].body.get_child(1)
		var village=adventure.content[4]
		expect(adventure.current==4 and village.tab==0 and village.selected=="nv_patrol","exact village prerequisite selected, not default or journey tab")
		await click(village,"后续：带给城里的口信")
		expect(app.windows.order.back()=="玛法故事与委托","successor activates story window")
		story=app.form.get_child(1)
		expect(story.selected=="story_letter","successor opens exact story")
		expect(app.rules.state==before,"cross-panel browsing neither accepts nor rewards quests")
	var report:={"checks":checks,"failures":failures,"scope":"viewport mouse navigation between novice prerequisite and story successor; new/reused windows; no travel, quest completion or physical input"}
	FileAccess.open("res://../artifacts/world-story/village-link-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
