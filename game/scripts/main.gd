extends Node

signal return_to_roster
var profile: Dictionary = {}
var shared_directory := "user://"

var audio := ClassicAudio.new()
var trial := ClassicTrial.new()
var trial_ui := ClassicTrialUI.new()
var ui_root: Control
var resources := ClassicResources.new()
var nav := ClassicNavigation.new()
var player := ClassicPlayer.new()
var saves := ClassicSave.new()
var world := ClassicWorld.new()
var mini := ClassicMinimap.new()
var zoom_preference := 2
var effective_zoom := 2
var status: Label
var coordinates: Label
var version_label: Label
var bottom: PanelContainer
var map_panel: PanelContainer
var notice_timer := 0.0
var autosave_time := 0.0
var help_open := false
var ready_to_play := false
var test_seconds := 0.0
var test_elapsed := 0.0
var test_next_goal := 0.0
var test_metrics_time := 0.0
var metrics_file: FileAccess
var test_output := ""
var test_rng := RandomNumberGenerator.new()
var demo_capture := false
var capture_done := false
var zoom_buttons: Array[Button] = []
var stats_frames: Array[float] = []
var test_mode := false
var should_shutdown := false
var ui_scale := 1
var pointer_position := Vector2.INF

func _ready() -> void:
	get_tree().auto_accept_quit = false
	ui_scale = maxi(1,roundi(DisplayServer.screen_get_scale()))
	DisplayServer.window_set_min_size(Vector2i(720,480)*ui_scale)
	var usable := DisplayServer.screen_get_usable_rect()
	var initial := Vector2i(1280,800)*ui_scale
	initial = initial.min(Vector2i(Vector2(usable.size)*0.88))
	DisplayServer.window_set_size(initial)
	DisplayServer.window_set_position(usable.position+(usable.size-initial)/2)
	Engine.max_fps = 60
	parse_arguments()
	if not resources.load_all():
		show_error(resources.error_message)
		return
	if not profile.is_empty():
		resources.hero.actions = resources.hero.variants["female" if profile.gender == "女" else "male"]
		trial.job = profile.job
		trial.hurt_sound = "0103008B" if profile.gender == "女" else "0103008A"
	nav.configure(resources.map)
	player.nav = nav
	var spawn := Vector2i(int(resources.map.spawn[0]),int(resources.map.spawn[1]))
	var state := saves.load_state(nav,resources.map.id,spawn)
	player.reset(state.cell)
	player.direction = state.direction
	zoom_preference = state.zoom
	audio.directory = saves.directory if test_mode or profile.is_empty() else shared_directory
	add_child(audio)
	if not audio.configure():
		show_error(audio.error_message)
		return
	if test_mode:
		audio.muted = true
		audio.apply_volumes()
	trial.configure(player,audio,resources.skills)
	world.trial = trial
	world.configure(resources,player)
	add_child(world)
	build_ui()
	resize_ui()
	get_viewport().size_changed.connect(resize_ui)
	ready_to_play = true
	if not saves.message.is_empty():
		notify_user(saves.message,8)
	elif not audio.error_message.is_empty():
		notify_user(audio.error_message,8)
	else:
		notify_user("欢迎回到玛法。点击地面，或使用 WASD 开始漫游。",7)
	if test_mode:
		test_rng.seed = 176
		metrics_file = FileAccess.open(test_output.path_join("metrics.jsonl"),FileAccess.WRITE)
		print("TEST_READY ",JSON.stringify({"cell":[player.cell.x,player.cell.y],"architecture":Engine.get_architecture_name(),"pid":OS.get_process_id()}))

func parse_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak="):
			test_seconds = float(arg.trim_prefix("--soak="))
			test_mode = true
		if arg.begins_with("--test-output="):
			test_output = arg.trim_prefix("--test-output=")
		if arg == "--capture": demo_capture = true
	if test_mode:
		if test_output.is_empty(): test_output = OS.get_user_data_dir().path_join("test")
		DirAccess.make_dir_recursive_absolute(test_output)
		saves.directory = test_output.path_join("save")
		DirAccess.make_dir_recursive_absolute(saves.directory)

func make_label(text: String, font_size: int, color := Color("eadcbb")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.06,0.05,0.94)
	style.border_color = Color(0.55,0.48,0.31,0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.scale = Vector2.ONE*ui_scale
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","Heiti SC","Arial"])
	theme.default_font = font
	theme.default_font_size = 14
	root.theme = theme
	ui_root = root
	canvas.add_child(root)
	var heading := PanelContainer.new()
	heading.position = Vector2(22,22)
	heading.add_theme_stylebox_override("panel",panel_style())
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(titles)
	titles.add_child(make_label("玛法 · 旧日漫游",23))
	titles.add_child(make_label("比奇县    /    原生单机 · 声音与技能试练" if profile.is_empty() else "%s · %s · %s" % [profile.name,profile.job,profile.gender],13,Color("a3ae96")))
	map_panel = PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel",panel_style())
	root.add_child(map_panel)
	var map_box := VBoxContainer.new()
	map_panel.add_child(map_box)
	var map_title := HBoxContainer.new()
	map_box.add_child(map_title)
	map_title.add_child(make_label("比奇 · 旧城",13))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_title.add_child(spacer)
	map_title.add_child(make_label("北 ↑",11,Color("a3ae96")))
	mini.custom_minimum_size = Vector2(144,144)
	mini.configure(nav,player)
	map_box.add_child(mini)
	coordinates = make_label("",12,Color("a3ae96"))
	map_box.add_child(coordinates)
	bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel",panel_style())
	root.add_child(bottom)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",7)
	bottom.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",12)
	box.add_child(top)
	status = make_label("",14)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(status)
	for level in [1,2,3]:
		var button := Button.new()
		button.text = "%d×" % level
		button.custom_minimum_size = Vector2(42,30)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): set_zoom(level))
		zoom_buttons.append(button)
		top.add_child(button)
	var help := Button.new()
	help.text = "操作 ?"
	help.focus_mode = Control.FOCUS_NONE
	help.pressed.connect(toggle_help)
	top.add_child(help)
	if not profile.is_empty():
		var roster := Button.new()
		roster.text = "返回选角"
		roster.focus_mode = Control.FOCUS_NONE
		roster.pressed.connect(leave_character)
		top.add_child(roster)
	var exit_button := Button.new()
	exit_button.text = "保存退出"
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(shutdown)
	top.add_child(exit_button)
	version_label = make_label("经典兼容素材 · 非核验 1.76  |  本地离线  |  0.3.0",11,Color("91a08e"))
	box.add_child(version_label)
	root.add_child(trial_ui)
	trial_ui.configure(self,trial,audio)

func resize_ui() -> void:
	if bottom == null: return
	var size := get_viewport().get_visible_rect().size/float(ui_scale)
	bottom.position = Vector2(22,size.y-106)
	bottom.size = Vector2(size.x-44,84)
	map_panel.position = Vector2(size.x-204,22)
	trial_ui.book.size.y = maxf(180,size.y-302)
	trial_ui.sound_panel.position.y = 114 if size.y < 600 else 181
	effective_zoom = zoom_preference if size.x >= 960 and size.y >= 640 else 1
	for i in range(zoom_buttons.size()):
		zoom_buttons[i].modulate = Color("ebd39c") if i+1 == effective_zoom else Color("9ca895")

func set_zoom(level: int) -> void:
	zoom_preference = level
	resize_ui()
	notify_user("像素缩放 %d×" % effective_zoom)

func toggle_help() -> void:
	help_open = not help_open
	if help_open:
		notify_user("左键寻路 · 右键按住跑动 · WASD 移动 · Shift 跑步 · 1/2/3 缩放 · F3 碰撞",30)
	else:
		notify_user("继续探索比奇旧城。")

func notify_user(text: String, duration := 3.0) -> void:
	if status != null: status.text = text
	notice_timer = duration

func keyboard_direction() -> Vector2i:
	var x := int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var y := int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	return Vector2i(x,y)

func _process(delta: float) -> void:
	if not ready_to_play or should_shutdown: return
	var manual := keyboard_direction()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse := pointer()
		if not bottom.get_global_rect().has_point(mouse) and not map_panel.get_global_rect().has_point(mouse) and not trial_ui.covers(mouse):
			var direction := (mouse-world.screen_for_cell(player.cell))/ClassicPlayer.CELL
			if direction.length() > 0.3:
				var index := posmod(roundi((direction.angle()+PI/2.0)/(PI/4.0)),8)
				manual = ClassicNavigation.DIRECTIONS[index]
				running = true
	if not get_window().has_focus() and not test_mode:
		manual = Vector2i.ZERO
		player.route.clear()
	if test_mode:
		running = int(test_elapsed/15.0) % 2 == 1
		update_soak(delta)
	if trial.cast_time > 0:
		manual = Vector2i.ZERO
	player.update(delta,manual,running)
	audio.footsteps(player)
	trial.update(delta)
	trial_ui.update_state()
	world.update_view(delta,get_viewport().get_visible_rect().size,effective_zoom*ui_scale)
	mini.queue_redraw()
	var origin: Array = resources.map.origin
	coordinates.text = "%d, %d   ·   %d FPS" % [player.cell.x+int(origin[0]),player.cell.y+int(origin[1]),Engine.get_frames_per_second()]
	notice_timer -= delta
	if notice_timer <= 0:
		status.text = "左键寻路  /  WASD 移动  /  Shift 跑步"
	autosave_time += delta
	if autosave_time >= 30:
		autosave_time = 0
		if not save_current(): notify_user(saves.message,8)

func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_play: return
	if event is InputEventKey and event.pressed and not event.echo and trial_ui.key(event.physical_keycode):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if trial.cast_time > 0: return
		var target := world.cell_at_screen(event.position)
		if player.go_to(target):
			world.target = target
		else:
			notify_user("此处无法到达，请选择道路或空地。")
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: set_zoom(1)
			KEY_2: set_zoom(2)
			KEY_3: set_zoom(3)
			KEY_F1, KEY_SLASH: toggle_help()
			KEY_F3:
				world.show_collision = not world.show_collision
				notify_user("碰撞标记：" + ("显示" if world.show_collision else "隐藏"))
			KEY_ESCAPE:
				player.route.clear()
				notify_user("已停止寻路。使用右下角「保存退出」离开。")

func save_current() -> bool:
	var saved := saves.save_state(resources.map.id,player.cell,zoom_preference,player.direction)
	if not test_mode and not audio.save_settings():
		saves.message = "声音设置保存失败"
		return false
	return saved

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown()

func shutdown() -> void:
	if ready_to_play and not save_current():
		notify_user(saves.message + "，请稍后重试。",10)
		return
	should_shutdown = true
	if metrics_file != null:
		metrics_file.flush()
		metrics_file.close()
	get_tree().quit()

func show_error(message: String) -> void:
	var label := Label.new()
	label.position = Vector2(50,80)
	label.size = Vector2(1100,300)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC","Heiti SC"])
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",22)
	label.text = "资源尚未就绪\n\n" + message + "\n\n请重新转换资源或使用完整应用包。错误详情也已写入运行日志。"
	add_child(label)
	push_error(message)
	if test_mode: get_tree().quit(2)

func update_soak(delta: float) -> void:
	test_elapsed += delta
	stats_frames.append(delta)
	test_next_goal -= delta
	if test_next_goal <= 0 or (player.route.is_empty() and player.progress >= 1.0):
		for attempt in range(50):
			var target := player.cell+Vector2i(test_rng.randi_range(-16,16),test_rng.randi_range(-16,16))
			if player.go_to(target) and not player.route.is_empty():
				world.target = target
				break
		test_next_goal = 8.0
	test_metrics_time += delta
	if test_metrics_time >= 5:
		test_metrics_time = 0
		stats_frames.sort()
		var record := {"seconds":test_elapsed,"fps":Engine.get_frames_per_second(),"p95_frame_ms":stats_frames[int(stats_frames.size()*0.95)]*1000,
			"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"vram_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"steps":player.completed_steps,"cell":[player.cell.x,player.cell.y],"action":player.action,"zoom":effective_zoom}
		if metrics_file != null:
			metrics_file.store_line(JSON.stringify(record))
			metrics_file.flush()
		stats_frames.clear()
	if demo_capture and not capture_done and test_elapsed > 3.0:
		capture_done = true
		capture_frame.call_deferred()
	if test_elapsed >= test_seconds:
		print("TEST_COMPLETE ",JSON.stringify({"seconds":test_elapsed,"steps":player.completed_steps,"cell":[player.cell.x,player.cell.y]}))
		shutdown.call_deferred()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(test_output.path_join("screenshot.png"))

func _input(event: InputEvent) -> void:
	# Keep targeting in the same viewport coordinates as click-to-move.
	# OS cursor polling can refer to a different window during focus changes.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if get_viewport().get_visible_rect().has_point(event.position):
			pointer_position=event.position

func pointer() -> Vector2:
	return pointer_position if pointer_position.is_finite() else get_viewport().get_mouse_position()

func leave_character() -> void:
	if not save_current():
		notify_user(saves.message+"，请稍后重试。",10)
		return
	should_shutdown = true
	audio.music.stop()
	return_to_roster.emit()
