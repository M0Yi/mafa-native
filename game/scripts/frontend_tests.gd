extends SceneTree
var checks:=0
var failures: Array[String]=[]
var session: Node
var front: ClassicFrontend
var out: String
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok:failures.append(description);push_error(description)
func _initialize() -> void:run.call_deferred()
func shot(name: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func click_at(point: Vector2) -> void:
	var location:=front.get_global_transform()*point
	var motion:=InputEventMouseMotion.new();motion.position=location;motion.global_position=location;root.push_input(motion)
	var event:=InputEventMouseButton.new();event.position=location;event.global_position=location;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event);await process_frame
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func wait_auth() -> void:
	var until:=Time.get_ticks_msec()+60000
	while front.busy and Time.get_ticks_msec()<until:await create_timer(0.02).timeout
	check(not front.busy,"auth worker completes")
func run() -> void:
	out=ProjectSettings.globalize_path("res://../artifacts/frontend");DirAccess.make_dir_recursive_absolute(out)
	session=load("res://session.tscn").instantiate();session.directory="/tmp/mafa-frontend-%d" % Time.get_ticks_usec();root.add_child(session)
	front=session.front
	AudioServer.set_bus_mute(0,true)
	check(front.loaded and front.page=="login","entry screen ready")
	await shot("01-login")
	await click_at(Vector2(210,500));check(front.page=="register","scaled register button click")
	await shot("02-register")
	front.fields.username.text="demo_user";front.fields.password.text="test-only-password";front.fields.confirm.text="test-only-password"
	front.authenticate("register");check(front.busy and not front.fields.password.editable,"password hashing off UI thread")
	await wait_auth();check(front.page=="login","registration returns to login")
	front.fields.password.text="wrong-password";front.authenticate("login");await wait_auth();check(front.page=="login" and not front.note.text.is_empty(),"bad login error")
	front.fields.password.text="test-only-password";front.authenticate("login");await wait_auth();check(front.page=="worlds","login reaches world selection")
	await shot("03-worlds")
	front.show_page("roster");await shot("04-empty-roster")
	var ids: Array=[]
	for job in ["战士","法师","道士"]:
		for gender in ["男","女"]:
			front.picked_job=job;front.picked_gender=gender;front.show_page("create")
			front.fields.name.text="霜月"+job
			await shot("create-"+job+gender)
			check(front.audio.music.playing and front.audio.music.get_meta("track")=="00040001","creation music "+job+gender)
		front.create_character();check(front.page=="roster","create "+job);ids.append(front.selected_id)
	check(front.accounts.characters().size()==3,"three playable characters")
	await shot("05-roster")
	front.selected_id=ids[1];front.show_page("roster");front.start_game()
	await create_timer(2.0).timeout
	check(session.game!=null and session.game.ready_to_play,"enter map")
	if session.game!=null:
		check(session.game.profile.job=="法师" and session.game.profile.gender=="女" and session.game.trial.job=="法师","profile applied to job and body")
		check(session.game.resources.hero.actions==session.game.resources.hero.variants.female,"female animation selected")
		check(session.game.trial.hurt_sound=="0103008B" and session.game.audio.streams.has("0103008B"),"female hit voice selected")
		session.game.set_zoom(1);var pos=session.game.player.cell
		await shot("06-in-game")
		session.game.leave_character();await create_timer(0.3).timeout
		check(session.game==null and front.visible and front.page=="roster","return to selection")
		check(front.audio.music.playing,"selection music resumes")
		var folder:=front.accounts.character_directory(ids[1]);check(FileAccess.file_exists(folder.path_join("save.json")),"per character save")
		front.start_game();await create_timer(2.0).timeout
		check(session.game.player.cell==pos and session.game.zoom_preference==1,"resume character position and zoom")
		session.game.leave_character();await create_timer(0.3).timeout
		front.selected_id=ids[0];front.start_game();await create_timer(2.0).timeout
		check(session.game.zoom_preference==2 and session.game.trial.job=="战士","different character independent settings and class")
		session.game.leave_character();await create_timer(0.3).timeout
	front.show_page("delete");await shot("07-delete")
	front.fields.confirmation.text="错误名字"
	check(not front.accounts.archive_character(front.selected_id,front.fields.confirmation.text),"delete requires exact confirmation")
	front.show_page("roster");front.logout();check(front.page=="login" and front.accounts.current_id.is_empty(),"logout")
	front.show_page("password");await shot("08-password")
	DisplayServer.window_set_size(Vector2i(2000,1400));await create_timer(0.2).timeout
	await click_at(Vector2(500,450));check(front.page=="login","resized back button click")
	await click_at(Vector2(210,500));check(front.page=="register","resized register button click")
	print("FRONTEND_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"profile_root":session.directory}))
	root.remove_child(session);session.queue_free();await create_timer(0.3).timeout
	quit(0 if failures.is_empty() else 1)
