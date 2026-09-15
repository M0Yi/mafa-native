extends SceneTree
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-window-position-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"window","name":"窗口位置","job":"战士","gender":"女"})
	var bank=app.windows.open("个人仓库","个人仓库")
	bank.use_native(3,Rect2(10,0,296,12))
	assert(bank.placement==Vector2(1,0.15))
	for dimensions in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size=dimensions;await settle()
		assert(absf(bank.get_global_rect().end.x-root.size.x)<1.0)
	bank.placement=Vector2(0.3,0.4);app.windows.close("个人仓库")
	bank=app.windows.open("个人仓库","个人仓库")
	assert(bank.placement.is_equal_approx(Vector2(0.3,0.4)))
	app.windows.close("个人仓库")
	root.size=Vector2i(1280,800)
	print("PASS: warehouse defaults to right edge at two sizes and preserves saved placement")
	var rows: Array=[]
	for saved in [[104,500],{"version":2,"anchor":[0.8,1.0]},["wrong",0],[null,{}],{"version":2,"anchor":[[],1]},[1e300,-1e300],{"version":2,"anchor":[1e300,-1e300]}]:
		app.windows.close_all()
		app.store.put_metadata("window:冒险面板",JSON.stringify(saved))
		app.show_bag()
		if not EditionWindows.valid_position_pair(saved) and not (saved is Dictionary and EditionWindows.valid_position_pair(saved.get("anchor"))):
			assert(app.windows.windows["冒险面板"].position.y==24)
		for dimensions in [Vector2i(1280,800),Vector2i(800,600),Vector2i(1280,800)]:
			root.size=dimensions;await settle()
			var win=app.windows.windows["冒险面板"]
			var rect: Rect2=win.get_global_rect()
			var boundary: float=root.size.y-196*app.windows.scale.y
			assert(rect.end.y<=boundary and rect.position.y>=0)
			assert(rect.end.x<=root.size.x and rect.position.x>=0)
			rows.append({"viewport":str(dimensions),"rect":str(rect),"quick_top":boundary,"saved":saved})
		app.windows.close("冒险面板");app.show_bag();await settle()
		assert(app.windows.windows["冒险面板"].get_global_rect().end.y<=root.size.y-196*app.windows.scale.y)
	var previous: String=app.store.read_metadata("window:冒险面板")
	app.windows.windows["冒险面板"].placement=Vector2(0.2,0.3)
	assert(app.store.db.query("PRAGMA query_only=ON;"))
	app.windows.close("冒险面板")
	assert(not app.windows.windows.has("冒险面板") and app.store.read_metadata("window:冒险面板")==previous)
	assert(app.pending_message.begins_with("窗口“冒险面板”已关闭，但位置未保存："))
	assert(app.store.db.query("PRAGMA query_only=OFF;"))
	app.show_bag();await settle()
	app.windows.windows["冒险面板"].placement=Vector2(0.2,0.3)
	app.windows.close("冒险面板")
	assert(app.pending_message=="窗口“冒险面板”的位置已保存")
	var retried=JSON.parse_string(app.store.read_metadata("window:冒险面板"))
	assert(is_equal_approx(float(retried.anchor[0]),0.2) and is_equal_approx(float(retried.anchor[1]),0.3))
	app.show_bag()
	var old_window=app.windows.windows["冒险面板"]
	old_window.button_navigation=true
	app.windows.close("冒险面板")
	app.show_bag()
	var replacement=app.windows.windows["冒险面板"]
	old_window.closed.emit(old_window)
	assert(app.windows.windows.get("冒险面板")==replacement)
	var back:=InputEventJoypadButton.new();back.button_index=JOY_BUTTON_B;back.pressed=true
	old_window._input(back)
	assert(app.windows.windows.get("冒险面板")==replacement)
	print("PASS: stale window close and controller input cannot close its replacement")
	print("PASS: position save failure closes window, preserves old metadata and reports error; retry saves")
	print(JSON.stringify({"passed":true,"cases":rows,"scope":"legacy pixel and normalized saved positions, live resize and close/reopen; programmatic viewport, no physical drag"}))
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
