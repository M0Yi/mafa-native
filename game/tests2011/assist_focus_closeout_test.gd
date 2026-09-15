extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-assist-focus-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"focus","name":"焦点测试","job":"法师","gender":"女"})
	app.gameplay.show_assist()
	var view=app.form.get_child(app.form.get_child_count()-1)
	for i in range(8):await process_frame
	view.controls[2].grab_focus();assert(view.cursor==2)
	var before: bool=app.rules.state.get("assist",{}).get("mp",false)
	var before_position: Vector2=view.controls[2].global_position
	var event:=InputEventJoypadButton.new();event.pressed=true;event.button_index=JOY_BUTTON_A
	view._input(event)
	assert(app.rules.state.assist.mp==not before)
	assert(view.controls[2].text==("已开启" if not before else "已关闭"))
	for i in range(8):await process_frame
	assert(view.controls[2].global_position==before_position)
	view.controls[3].get_line_edit().grab_focus();assert(view.cursor==3)
	var value: float=view.controls[3].value
	event.button_index=JOY_BUTTON_DPAD_RIGHT;view._input(event)
	assert(view.controls[3].value==value+1)
	view.select(4);view.controls[1].grab_focus();assert(view.cursor==1)
	view.select(0);assert(view.cursor==0)
	var saved: Dictionary=app.rules.state.duplicate(true)
	assert(app.store.db.query("PRAGMA query_only=ON;"))
	var checked: bool=view.controls[2].button_pressed
	view.controls[2].button_pressed=not checked
	assert(view.controls[2].button_pressed==checked and app.rules.state==saved)
	assert(view.controls[2].text==("已开启" if checked else "已关闭"))
	assert(app.notice.text==app.rules.message and not app.rules.message.is_empty())
	value=view.controls[3].value
	view.controls[3].value=value+1
	assert(view.controls[3].value==value and app.rules.state==saved)
	assert(app.notice.text==app.rules.message)
	assert(app.store.db.query("PRAGMA query_only=OFF;"))
	view.controls[3].value=value+1
	assert(app.store.load_world("focus").assist.mp_threshold==value+1)
	app.windows.close("内挂设置");app.gameplay.show_assist()
	view=app.form.get_child(app.form.get_child_count()-1)
	assert(view.controls[3].value==value+1 and view.controls[2].button_pressed==checked)
	var layouts: Array=[]
	for dimensions in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=dimensions
		for page in range(5):
			view.select(page)
			for i in range(12):await process_frame
			var win=app.windows.windows["内挂设置"]
			var bounds:=Rect2(Vector2.ZERO,Vector2(dimensions))
			assert(bounds.grow(1).encloses(win.get_global_rect()))
			var clip: Rect2=win.scroll.get_global_rect()
			for control in view.controls:
				var rect: Rect2=control.get_global_rect()
				assert(rect.position.x>=clip.position.x-1 and rect.end.x<=clip.end.x+1)
			assert(bounds.grow(1).encloses(win.close_button.get_global_rect()))
			layouts.append({"width":dimensions.x,"height":dimensions.y,"page":page,"controls":view.controls.size(),"scroll_needed":view.hint.get_global_rect().end.y>clip.end.y})
	FileAccess.open("res://../artifacts/closeout-assist-layout.json",FileAccess.WRITE).store_string(JSON.stringify(layouts,"  "))
	print("PASS: 15 assist page/size layouts keep window, controls and close button within horizontal bounds")
	print("PASS: SQLite write refusal restores checkbox/number and displays failure; retry persists and reopening restores controls")
	print("PASS: checkbox, numeric editor and action focus synchronize controller cursor; A/right act on focused row")
	view.select(0)
	app.show_controller_panel()
	var controller=app.form.get_child(app.form.get_child_count()-1)
	event.button_index=JOY_BUTTON_RIGHT_SHOULDER
	var controller_page: int=controller.page
	view._input(event);controller._input(event)
	assert(view.page==0 and controller.page==posmod(controller_page+1,4))
	app.windows.confirm("测试确认",func():pass)
	controller_page=controller.page
	view._input(event);controller._input(event)
	assert(view.page==0 and controller.page==controller_page)
	app.windows.modal.hide();app.windows.close("手柄操作")
	view._input(event);assert(view.page==1)
	print("PASS: shoulder input belongs to top window; modal blocks both; closing top restores underlying navigation")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
