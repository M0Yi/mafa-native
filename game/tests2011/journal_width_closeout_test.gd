extends SceneTree
var rows: Array=[]
var failures: Array=[]
func _initialize():call_deferred("run")
func inspect_controls(node: Node,clip: Rect2) -> void:
	for child in node.get_children():
		if child is Label and child.is_visible_in_tree():
			var rect: Rect2=child.get_global_rect()
			rows.append({"text":child.text,"width":rect.size.x,"available":clip.size.x,"lines":child.get_line_count()})
			if rect.position.x<clip.position.x-1 or rect.end.x>clip.end.x+1:failures.append(child.text)
		inspect_controls(child,clip)
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-journal-width-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"width","name":"文字布局","job":"战士","gender":"女"})
	for dimensions in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=dimensions;app.show_quests()
		for i in range(12):await process_frame
		var views: Array=app.form.find_children("*","VBoxContainer",true,false)
		for view in views:
			if view.get_script()!=null and view.get_script().resource_path.ends_with("quest_panel.gd"):
				for tab in [0,1]:
					app.rules.state.quests["nv_hunt"]="accepted"
					view.tab=tab;view.selected="nv_hunt";view.refresh()
					for i in range(12):await process_frame
					inspect_controls(view.details,view.details.get_parent().get_global_rect())
		app.windows.close_all()
	var report:={"rows":rows,"failures":failures}
	FileAccess.open("res://../artifacts/closeout-journal-width.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Journal width rows: ",rows.size()," failures: ",failures.size())
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() and not rows.is_empty() else 1)
