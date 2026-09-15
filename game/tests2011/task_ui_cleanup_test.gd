extends SceneTree
var app
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	if not ok:failures.append(note)
func settle() -> void:
	for i in range(8):await process_frame
func capture(file: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../artifacts/world-story/"+file)
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/task-ui-clean-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"task-ui","name":"初行者","job":"战士","gender":"男"});app.world.paused=false
	var elder: Dictionary=app.world.entities.filter(func(e):return e.id=="border:elder")[0]
	app.world.player.reset(Vector2i(elder.cell[0]+1,elder.cell[1]));app.world.update_world(0,Vector2(root.size),false)
	app.world.task_markers=EditionRules.Story.npc_markers(app.rules.state)
	check(app.world.task_markers.get("border:elder")=="可接取","elder offers task marker")
	app.windows.close_all();await settle()
	capture("task-ui-npc-marker.png")
	check(app.rules.novice_quest("nv_arrival"),"accept novice fixture")
	app.world.task_markers=EditionRules.Story.npc_markers(app.rules.state)
	check(app.world.task_markers.get("border:elder")=="可交付","marker changes to turn-in")
	app.interact(elder);await settle()
	var view=app.form.get_child(1)
	var visible_titles: Array=[]
	for b in view.entries.get_children():
		if b is Button:visible_titles.append(b.text)
	check(visible_titles.size()==1,"only available novice task shown")
	capture("task-ui-village.png")
	view.show_completed=true;view.refresh();await settle()
	check(view.entries.get_child_count()==0,"new character history is empty")
	check(view.history_button.text=="返回当前委托","history has explicit return action")
	view.show_completed=false;view.refresh()
	app.show_story(elder);await settle()
	check(not app.windows.windows.has(elder.name),"story replaces elder window")
	view=app.form.get_child(1)
	check(view.filtered_choices().is_empty(),"locked future stories hidden")
	app.game_panel("手柄人物委托",Vector2(520,430))
	var pad=load("res://scripts/edition2011/ui/controller_npc.gd").new();app.form.add_child(pad);pad.setup(app,elder);await settle()
	check(pad.rows.size()==1 and pad.rows[0].id=="nv_arrival","controller also hides future novice and story tasks")
	pad.show_completed=true;pad.refresh();await settle()
	check(pad.rows.is_empty(),"controller history starts empty")
	app.windows.close("手柄人物委托")
	var next: Dictionary=app.rules.state.duplicate(true)
	next.quests.nv_arrival="done";next.quests.nv_equip="done";next.quests.nv_hunt="done";next.quests.nv_patrol="done"
	check(app.rules.apply(next,"task_ui_progress_fixture"),"prepare later task view")
	app.show_story();await settle();view=app.form.get_child(1)
	check(not view.filtered_choices().is_empty(),"unlocked tasks remain accessible")
	for q in view.filtered_choices():check(EditionRules.Story.available(app.rules.state,q) or app.rules.state.quests.get(q.id)=="accepted","story row is actionable")
	var all_text: String=""
	for label in view.find_children("*","Label",true,false):all_text+=label.text
	check(not all_text.contains("未解锁") and not all_text.contains("单机重建故事") and not all_text.contains("基础：金币"),"development counts and duplicate reward data removed")
	capture("task-ui-story.png")
	root.size=Vector2i(800,600);await settle()
	capture("task-ui-small.png")
	next=app.rules.state.duplicate(true);next.quests.story_letter="done"
	check(app.rules.apply(next,"task_ui_history_fixture"),"prepare completed story fixture")
	view.select_status(3);await settle()
	check(view.filtered_choices().size()==1 and view.filtered_choices()[0].id=="story_letter","completed stories accessible in history")
	view.reset_filters();await settle()
	check(not view.filtered_choices().any(func(q):return q.id=="story_letter"),"completed stories do not crowd current list")
	app.show_quest_entry("story_letter");await settle();view=app.form.get_child(1)
	check(view.status_filter=="已完成" and view.selected=="story_letter","existing completed-task links still open archive")
	print(JSON.stringify({"failures":failures,"scope":"native layout and filtering; isolated progress fixtures; no physical input"}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
