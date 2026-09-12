extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var app = load("res://main.tscn").instantiate()
	app.saves.directory = "user://integration-tests-%d" % OS.get_process_id()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	check(app.ready_to_play,"real resource-backed scene initializes")
	if not app.ready_to_play:
		quit(1)
		return
	var normal_size := DisplayServer.window_get_size()
	var spawn: Vector2i = app.player.cell
	var target := spawn+Vector2i(1,0)
	for candidate in ClassicNavigation.DIRECTIONS:
		if app.nav.can_step(spawn,spawn+candidate):
			target = spawn+candidate
			break
	for zoom in [1,2,3]:
		app.set_zoom(zoom)
		app.world.update_view(0,root.get_visible_rect().size,app.effective_zoom*app.ui_scale)
		var point: Vector2 = app.world.screen_for_cell(target)
		check(app.world.cell_at_screen(point) == target,"screen/world roundtrip at zoom %d" % zoom)
		app.player.route.clear()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = point
		root.push_input(click)
		await process_frame
		check(not app.player.route.is_empty() and app.player.route.back() == target,"left mouse click reaches correct grid at zoom %d" % zoom)
		click.pressed = false
		root.push_input(click)
	# Keyboard state travels through Godot's input system, rather than calling movement directly.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(app.keyboard_direction() == Vector2i(1,0),"physical D maps to right")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	check(app.keyboard_direction() == Vector2i.ZERO,"released key does not stick")
	key = InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(Input.is_physical_key_pressed(KEY_SHIFT),"shift state enters input system")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	# Resize to the supported small-window limit; test the same click transform again.
	DisplayServer.window_set_size(Vector2i(720,480)*app.ui_scale)
	await process_frame
	await process_frame
	app.resize_ui()
	check(app.effective_zoom == 1,"small window falls back to 1x")
	app.world.update_view(0,root.get_visible_rect().size,app.effective_zoom*app.ui_scale)
	check(app.world.cell_at_screen(app.world.screen_for_cell(target)) == target,"click mapping survives resize")
	DisplayServer.window_set_size(normal_size)
	await process_frame
	await process_frame
	app.resize_ui()
	check(app.effective_zoom == 3,"preferred zoom restored when window grows")
	app.player.reset(target)
	check(app.save_current(),"integration saves current player state")
	var saved: Dictionary = app.saves.load_state(app.nav,app.resources.map.id,spawn)
	check(saved.cell == target and saved.zoom == 3,"position and zoom reload correctly")
	# Missing JSON metadata and a bad manifest are caught before rendering starts.
	var invalid_base := "user://bad-resource-test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(invalid_base)
	var file := FileAccess.open(invalid_base.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version":999}))
	file.close()
	var resources := ClassicResources.new()
	check(not resources.load_all(invalid_base),"unsupported manifest rejected")
	# Keyboard casting uses the last viewport mouse event, including after zoom changes.
	app.audio.muted=true;app.audio.apply_volumes()
	app.player.reset(spawn);app.trial_ui.toggle_trial();app.trial_ui.book.hide()
	for zoom in [1,2,3]:
		app.player.reset(spawn);app.trial.reset_targets();app.set_zoom(zoom)
		app.world.update_view(0,root.get_visible_rect().size,app.effective_zoom*app.ui_scale)
		var enemy: Dictionary=app.trial.actors[0]
		var point: Vector2=app.world.screen_for_cell(enemy.cell)
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
		root.push_input(motion)
		await process_frame
		check(app.world.cell_at_screen(app.pointer())==enemy.cell,"cast pointer at zoom %d" % zoom)
		var layers: Array=app.resources.skills.actors[enemy.kind]["stand"][enemy.direction][0]
		for layer in layers:
			if layer.get("shadow",false):continue
			var body: Vector2=(enemy.anchor+Vector2(layer.offset[0],layer.offset[1])+Vector2(layer.texture[3],layer.texture[4])/2)*app.world.zoom_level+app.world.position
			check(app.world.aim_at_screen(body)==enemy.cell,"sprite body targeting at zoom %d" % zoom)
		var casts: int=app.trial.total_casts
		var q:=InputEventKey.new();q.physical_keycode=KEY_Q;q.keycode=KEY_Q;q.pressed=true
		root.push_input(q);await process_frame
		check(app.trial.total_casts==casts+1 and app.trial.mp<300,"Q casts at zoom %d" % zoom)
		q=q.duplicate();q.pressed=false;root.push_input(q)
	print("INTEGRATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"dpi_scale":app.ui_scale}))
	quit(0 if failures.is_empty() else 1)
