extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-controller-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"feedback","name":"操作反馈","job":"战士","gender":"女"})
	app.show_controller_panel()
	var view=app.form.get_child(app.form.get_child_count()-1)
	var before: Dictionary=app.rules.state.duplicate(true)
	assert(app.store.db.query("PRAGMA query_only=ON;"))
	view.operate(true)
	assert(app.rules.state==before and not app.rules.message.is_empty())
	assert(app.notice.text==app.rules.message and app.pending_message==app.rules.message)
	assert(app.store.db.query("PRAGMA query_only=OFF;"))
	view.operate(true)
	assert(app.notice.text==app.rules.message and app.rules.state.quickbar[0]=="potion")
	assert(app.store.load_world("feedback").quickbar[0]=="potion")
	root.size=Vector2i(800,600)
	app.info("保存失败：当前存档无法写入。请检查存储空间与目录权限，处理后重试；本次操作没有修改物品。")
	for i in range(20):await process_frame
	var win=app.windows.windows["手柄操作"]
	print("Feedback layout: hint bottom=",view.hint.get_global_rect().end.y," scroll bottom=",win.scroll.get_global_rect().end.y)
	assert(view.hint.get_global_rect().end.y<=win.scroll.get_global_rect().end.y+1)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/closeout-controller-feedback.png")
	print("PASS: failed binding preserves state and displays inline result; retry persists and replaces failure feedback")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
