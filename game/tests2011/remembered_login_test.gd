extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move,true)
	var press:=InputEventMouseButton.new();press.position=point;press.global_position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
	var release:=press.duplicate();release.pressed=false;root.push_input(release,true)
	await settle()
func find_button(node: Node,prefix: String) -> BaseButton:
	if node is BaseButton and str(node.text).begins_with(prefix):return node
	for child in node.get_children():
		var found:=find_button(child,prefix)
		if found!=null:return found
	return null
func auth_finished() -> void:
	while app.thread.is_alive():await process_frame
	if app.thread.is_started():app.entry.finish_auth(bool(app.thread.wait_to_finish()))
	await settle()
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-login-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	expect(app.accounts.register_account("remember_test","test-password-095","test-password-095"),"isolated registration")
	var e=app.entry
	e.fields.username.text="remember_test";e.fields.password.text="test-password-095"
	await click(e.controls.remember.get_global_rect().get_center())
	expect(e.controls.remember.button_pressed,"checkbox actual mouse hit")
	await click(e.controls.login.get_global_rect().get_center());await auth_finished()
	expect(e.page=="world","password login succeeds")
	var saved:=EditionRememberedLogin.saved(app.accounts)
	expect(saved.get("username")=="remember_test","successful login persists device credential")
	expect(not FileAccess.get_file_as_string(EditionRememberedLogin.path(app.store)).contains("test-password-095"),"no plaintext password stored")
	app.accounts.current_id="";app.accounts.load_database();e.show_page("login");await settle()
	expect(e.fields.username.text=="remember_test" and e.fields.password.text.is_empty() and e.controls.remember.button_pressed,"reopened login restores account and saved-login hint")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/remembered-login-0.9.5/login.png")
	await click(e.controls.login.get_global_rect().get_center());await auth_finished()
	expect(e.page=="world" and not app.accounts.current_id.is_empty(),"remembered credential logs in without password input")
	app.accounts.current_id="";e.show_page("login");await settle()
	e.fields.password.text="wrong-password"
	await click(e.controls.login.get_global_rect().get_center());await auth_finished()
	expect(e.page=="login" and app.accounts.current_id.is_empty(),"explicit wrong password never falls back to saved credential")
	expect(app.accounts.change_password("remember_test","test-password-095","new-password-095","new-password-095"),"password changed")
	expect(not EditionRememberedLogin.login(app.accounts,"remember_test"),"password change revokes remembered login")
	app.accounts.login("remember_test","new-password-095");EditionRememberedLogin.remember(app.accounts)
	e.show_page("login");await settle();await click(e.controls.remember.get_global_rect().get_center())
	expect(not FileAccess.file_exists(EditionRememberedLogin.path(app.store)) and EditionRememberedLogin.saved(app.accounts).is_empty(),"uncheck removes saved credential immediately")
	e.show_page("login");expect(not e.controls.remember.button_pressed,"forget persists on reopen")
	var report:={"checks":checks,"failures":failures,"input":"Godot viewport mouse events, isolated SQLite; no user account access"}
	FileAccess.open("res://../artifacts/remembered-login-0.9.5/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
