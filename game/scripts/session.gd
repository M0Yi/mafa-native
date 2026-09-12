extends Node

var front: ClassicFrontend
var game: Node
var directory := "user://"

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak="):
			game=load("res://main.tscn").instantiate();add_child(game);return
		if arg.begins_with("--profile-root="):directory=arg.trim_prefix("--profile-root=")
	var scale := maxi(1,roundi(DisplayServer.screen_get_scale()))
	DisplayServer.window_set_min_size(Vector2i(800,600)*scale)
	var screen := DisplayServer.screen_get_usable_rect()
	var size := (Vector2i(800,600)*scale).min(screen.size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position+(screen.size-size)/2)
	front=ClassicFrontend.new();front.accounts.directory=directory
	front.enter_character.connect(func(profile,folder):enter_game.call_deferred(profile,folder))
	front.exit_requested.connect(func():get_tree().quit())
	add_child(front)
	get_viewport().size_changed.connect(resize_front)
	resize_front()

func resize_front() -> void:
	if front==null:return
	var size := get_viewport().get_visible_rect().size
	var factor := maxf(1.0,floorf(minf(size.x/800.0,size.y/600.0)))
	front.scale=Vector2.ONE*factor
	front.position=(size-Vector2(800,600)*factor)/2.0

func enter_game(profile: Dictionary,folder: String) -> void:
	if profile.is_empty() or folder.is_empty():return
	front.hide();front.process_mode=Node.PROCESS_MODE_DISABLED
	game=load("res://main.tscn").instantiate()
	game.profile=profile;game.saves.directory=folder;game.shared_directory=directory
	game.return_to_roster.connect(func():leave_game.call_deferred())
	add_child(game)

func leave_game() -> void:
	remove_child(game);game.queue_free();game=null
	front.audio.load_settings();front.audio.apply_volumes()
	front.audio.music.set_meta("track","")
	front.process_mode=Node.PROCESS_MODE_INHERIT
	front.show();front.show_page("roster");resize_front()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and game==null:get_tree().quit()
