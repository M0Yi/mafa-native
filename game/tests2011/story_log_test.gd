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
func click(button: Control) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func button_named(box: Node,value: String):
	for child in box.get_children():
		if child is Button and child.text==value:return child
	return null
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-log-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"log","name":"日志验收","gender":"男","job":"战士"});app.world.paused=true
	app.show_story();await settle();var view=app.form.get_child(1)
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(view.entries.get_child_count()==EditionRules.Story.data().quests.size()*2,"all quests retained")
	await click(button_named(view.toolbar,"可接取"))
	expect(view.entries.get_child_count()==0,"locked stories excluded from available filter")
	await click(button_named(view.toolbar,"全部故事"))
	expect(view.entries.get_child_count()==EditionRules.Story.data().quests.size()*2,"reset restores all stories")
	view.search.grab_focus()
	for character in "火龙":
		var key:=InputEventKey.new();key.unicode=character.unicode_at(0);key.pressed=true;root.push_input(key,true);await settle()
	expect(view.search.text=="火龙","keyboard text reaches search")
	expect(view.entries.get_child_count()>0 and view.entries.get_child_count()<EditionRules.Story.data().quests.size()*2,"search narrows list")
	for child in view.entries.get_children():
		if child is Button:
			var matched: Array=EditionRules.Story.data().quests.filter(func(q):return q.title==child.text.trim_prefix("◆ "))
			expect(not matched.is_empty() and "火龙" in view.search_text(matched[0]),"matching title or location remains")
	await click(button_named(view.toolbar,"全部故事"))
	for term in ["矿物回收站","恶魔铁匠","邪恶毒蛇"]:
		view.search.text=term;view.refresh();await settle()
		expect(view.entries.get_child_count()>0,"search finds location NPC or monster "+term)
		for child in view.entries.get_children():
			if child is Button:
				var matches: Array=EditionRules.Story.data().quests.filter(func(q):return q.title==child.text.trim_prefix("◆ "))
				expect(not matches.is_empty() and term in view.search_text(matches[0]),"extended search excludes unrelated entries")
	view.reset_filters()
	view.chapter_id="valley";view.chapter_picker.select(3);view.refresh();await settle()
	for child in view.entries.get_children():
		if child is Button:
			var title: String=child.text.trim_prefix("◆ ")
			expect(EditionRules.Story.data().quests.any(func(q):return q.chapter=="valley" and q.title==title),"region filter contains only its tasks")
	view.reset_filters();view.selected="story_field_book";view.refresh();await settle()
	var prerequisite=button_named(view.details,"查看前置：自己的生存方法")
	expect(prerequisite!=null,"missing prerequisite exposes navigation")
	if prerequisite!=null:
		view.details.get_parent().ensure_control_visible(prerequisite);await settle();await click(prerequisite)
		expect(view.selected=="story_book","mouse opens correct prerequisite")
		expect(view.details.get_parent().scroll_vertical==0,"new prerequisite starts at its title")
	view.selected="story_mine";view.refresh();await settle()
	var follow=button_named(view.details,"后续：矿道里的旧工装 · 前置未完成")
	expect(follow!=null,"direct successor visible with locked state")
	if follow!=null:
		view.details.get_parent().ensure_control_visible(follow);await settle();await click(follow)
		expect(view.selected=="story_mine_workers" and view.npc.is_empty(),"mouse opens successor globally without accepting")
		expect(view.details.get_parent().scroll_vertical==0,"successor opens at title")
	expect(app.rules.state==before,"browsing never mutates gameplay state")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"window fits 800x600")
	expect(view.toolbar.get_global_rect().end.x<=app.panel.get_global_rect().end.x,"toolbar stays within panel")
	var fixture: Dictionary=app.rules.state.duplicate(true)
	fixture.quests.story_pig="accepted";fixture.quests.story_moon_report="accepted";fixture.quests.story_woma="done"
	expect(app.rules.apply(fixture,"status_filter_fixture"),"seed ongoing ready and completed states")
	before=app.rules.state.duplicate(true);view.reset_filters()
	for pair in [[1,"story_pig"],[2,"story_moon_report"],[3,"story_woma"]]:
		view.status_picker.select(pair[0]);view.select_status(pair[0]);await settle()
		expect(view.entries.get_child_count()==2 and view.selected==pair[1],"status separates ongoing ready completed "+str(pair[0]))
	view.chapter_id="moon";view.refresh();await settle()
	expect(view.entries.get_child_count()==0,"status and region combine")
	await click(button_named(view.toolbar,"当前委托"))
	expect(view.status_filter.is_empty() and view.selected=="story_moon_report","current button clears conflicting status but retains region")
	await click(button_named(view.toolbar,"全部故事"))
	expect(view.status_filter.is_empty() and view.chapter_id.is_empty() and view.entries.get_child_count()==EditionRules.Story.data().quests.size()*2,"all stories resets every filter")
	expect(app.rules.state==before,"status browsing does not change tasks or rewards")
	expect(view.status_picker.get_global_rect().end.x<=app.panel.get_global_rect().end.x,"status filter fits minimum width")
	await click(view.status_picker)
	var popup: PopupMenu=view.status_picker.get_popup()
	var choice:=InputEventMouseButton.new();choice.button_index=MOUSE_BUTTON_LEFT
	choice.position=Vector2(popup.position)+Vector2(popup.size)/2.0;choice.global_position=choice.position;choice.pressed=true;root.push_input(choice,true)
	choice=choice.duplicate();choice.pressed=false;root.push_input(choice,true);await settle()
	expect(view.status_filter=="待交付" and view.selected=="story_moon_report" and view.entries.get_child_count()==2,"real dropdown mouse selects ready tasks")
	view.npc={"id":"server:merchant:4"};view.selected="";view.reset_filters();await settle()
	expect(view.selected=="story_moon_report","NPC default selection prioritizes ready delivery")
	var priorities: Array=[]
	for child in view.entries.get_children():
		if child is Button:
			for q in EditionRules.Story.data().quests:
				if q.title==child.text.trim_prefix("◆ "):priorities.append(EditionRules.Story.npc_task_priority(app.rules.state,q,view.npc.id));break
	for i in range(1,priorities.size()):expect(priorities[i-1]<=priorities[i],"mouse NPC list priority order")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/story-log.png")
	var report:={"checks":checks,"failures":failures,"scope":"mouse filters and prerequisite navigation, Unicode keyboard search, region/status fixtures and minimum layout; not an IME or hardware controller test"}
	FileAccess.open("res://../artifacts/world-story/log-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
