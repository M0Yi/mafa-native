extends SceneTree
var app
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mafa-journal-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(true)
	app.start_character({"id":"journal","name":"布局验收","gender":"男","job":"法师"});app.world.paused=true
	for dimensions in [Vector2i(800,600),Vector2i(1280,800)]:
		root.size=dimensions
		for kind in ["skills","quests","npc"]:
			app.windows.close_all()
			if kind=="skills":app.show_skills()
			elif kind=="quests":app.show_quests()
			else:
				app.world.player.reset(EditionVillage.SPAWN)
				app.interact(EditionVillage.data().npcs[0].duplicate(true))
			await settle()
			expect(app.panel!=null,"window opened "+kind)
			var rect: Rect2=app.panel.get_global_rect()
			expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(rect),"window fits "+kind+str(dimensions))
			var view=app.form.get_child(app.form.get_child_count()-1)
			expect(view.details.size.x>=280,"readable detail width "+kind)
			if kind=="skills":
				expect(view.entries.get_child_count()==10,"mage list count")
				expect(not app.rules.state.skills.has("fireball"),"opening skills does not learn")
			if kind=="quests":
				view.tab=1;view.refresh();expect(view.entries.get_child_count()==7,"seven narrative stages")
				view.tab=0;view.selected="nv_hunt";view.refresh();expect(view.selected=="nv_hunt","quest selection retained")
			if kind=="npc":
				app.world.player.reset(Vector2i(310,630));expect(not view.near_npc(),"remote NPC service denied")
				app.world.player.reset(EditionVillage.SPAWN)
			app.notice.text=""
			await settle()
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/journal-layout/"+kind+"-"+str(dimensions.x)+".png"))
	var report:={"failures":failures,"sizes":["800x600","1280x800"],"panels":["skills","quests","npc"]}
	FileAccess.open("res://../artifacts/journal-layout/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
