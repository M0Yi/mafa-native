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
	for i in range(6):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/chapter-progress-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in ["战士","法师","道士"]:
		app.windows.close_all();app.start_character({"id":"chapter-"+job,"name":"地区进度","gender":"男","job":job});app.world.hide()
		var counts: Dictionary=Story.chapter_progress(app.rules.state,"",job)
		var expected: int=Story.data().quests.filter(func(q):return not q.has("jobs") or job in q.jobs).size()
		expect(counts.total==expected and counts.total==counts.done+counts.ready+counts.active+counts.available+counts.locked,"profession counts partition applicable quests")
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_mongchon="done";next.quests.story_mongchon_medicine_purchase="accepted"
		expect(app.rules.apply(next,"chapter_progress_fixture"),"prepare delivered main and accepted purchase task")
		app.show_story();await settle();var view=app.form.get_child(1);
		for i in range(view.chapter_picker.item_count):
			if view.chapter_picker.get_item_metadata(i)=="mongchon":view.chapter_picker.select(i);view.chapter_picker.item_selected.emit(i);break
		await settle()
		counts=Story.chapter_progress(app.rules.state,"mongchon",job)
		expect(counts.done==1 and counts.active==1 and counts.ready==0 and counts.available>0,"chapter separates delivered active and unlocked quests")
		expect(view.visible_quest_ids[0]=="story_mongchon_medicine_purchase","accepted task precedes new and completed stories")
		var sorted_choices: Array=view.filtered_choices()
		var previous_rank:=-1
		var correctly_sorted:=true
		for candidate in sorted_choices:
			var rank: int=view.journal_priority(candidate)
			if rank<previous_rank:correctly_sorted=false
			previous_rank=rank
		expect(correctly_sorted,"journal priorities monotonic across chapter")
		view.selected="story_mongchon";view.refresh()
		var summary: String=view.summary.text.get_slice("\n",1)
		view.search.text="没有这样的任务";view.search.text_changed.emit(view.search.text);await settle()
		expect(view.visible_quest_ids.is_empty() and view.summary.text.get_slice("\n",1)==summary,"search result count does not change chapter totals")
		view.search.text="";view.search.text_changed.emit(view.search.text);await settle()
		expect(app.rules.save_location("0160",Vector2i(5,9),0),"visit purchase location fixture")
		expect(app.rules.reference_trade("server:merchant:71","potion",true,0) and app.rules.reference_trade("server:merchant:71","mana",true,0),"real purchases complete target")
		await settle();counts=Story.chapter_progress(app.rules.state,"mongchon",job)
		expect(counts.active==0 and counts.ready==1 and "待交付 1" in view.summary.text,"committed progress updates summary before delivery")
		expect(view.visible_quest_ids[0]=="story_mongchon_medicine_purchase" and view.selected=="story_mongchon","ready task promoted while inspected task preserved")
		next=app.rules.state.duplicate(true);next.quests.story_mongchon_armor_repair="accepted"
		expect(app.rules.apply(next,"second_task_fixture") and app.rules.track_story("story_mongchon_armor_repair"),"track second unfinished task")
		await settle()
		expect(view.visible_quest_ids[0]=="story_mongchon_medicine_purchase" and view.visible_quest_ids[1]=="story_mongchon_armor_repair","ready task remains first and tracked unfinished task follows")
		expect(view.selected=="story_mongchon","tracking does not replace inspected task")
	app.world.show()
	var window=app.windows.windows["玛法故事与委托"]
	var final_view=window.body.get_child(1)
	for label in final_view.details.get_children():
		if label is Label and label.text.begins_with("土城的行囊"):
			var used_font: Font=label.get_theme_font("font")
			var missing: Array=[]
			for i in range(label.text.length()):
				if not used_font.has_char(label.text.unicode_at(i)):missing.append(label.text.unicode_at(i))
			expect(used_font==app.font and missing.is_empty(),"chapter uses explicit Chinese font with complete glyph coverage")
			print(JSON.stringify({"chapter_label":label.text,"font":used_font.get_class(),"missing_characters":missing,"font_names":used_font.font_names if used_font is SystemFont else []}))
	for viewport_size in [Vector2i(800,600),Vector2i(1280,800)]:
		root.size=viewport_size;await settle()
		window.scroll.scroll_vertical=0;await settle()
		expect(Rect2(Vector2.ZERO,Vector2(viewport_size)).encloses(window.get_global_rect()),"task window stays within viewport")
		expect(window.scroll.get_global_rect().encloses(final_view.summary.get_global_rect()),"chapter summary visible without scrolling")
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://../artifacts/world-story/chapter-summary-%dx%d.png"%[viewport_size.x,viewport_size.y])
	var report:={"checks":checks,"failures":failures,"scope":"three-job chapter counts and visible summary with search plus real purchases; task/location fixtures, no physical input or natural playthrough"}
	FileAccess.open("res://../artifacts/world-story/chapter-progress-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
