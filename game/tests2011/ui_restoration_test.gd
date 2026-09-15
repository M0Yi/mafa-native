extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr("FAIL: ",note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for _i in range(4):await process_frame
func auth() -> void:
	while app.thread.is_started():await process_frame
	await settle()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/ui-restoration/"+name+".png"))
func run() -> void:
	app=load("res://edition2011.tscn").instantiate()
	app.store.path=OS.get_environment("TMPDIR")+"mafa-restoration-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.allow_focus_pause=false
	root.add_child(app);await settle()
	var entry: EditionEntry=app.entry
	expect(entry.page=="login","original login entry")
	expect(entry.controls.quit.size==Vector2(16,23),"native skin hit area does not inherit button minimum size")
	await shot("login")
	entry.show_page("register");await settle();await shot("register")
	entry.fields.username.text="restoration";entry.fields.password.text="local-test-123";entry.fields.confirm.text="local-test-123"
	entry.authenticate("register");await auth()
	expect(entry.page=="recovery_code","registration exposes recovery code")
	var code: String=app.accounts.last_recovery_code
	expect(code.length()==32,"recovery has 128 random bits")
	expect(not app.store.read_metadata("accounts").contains(code),"no raw recovery code persisted")
	entry.confirm_modal();entry.fields.username.text="restoration";entry.fields.password.text="local-test-123"
	entry.authenticate("login");await auth();expect(entry.page=="world","login opens local world selection")
	entry.open_door();entry._process(2.99);expect(entry.page=="door","door lasts three seconds")
	entry._process(0.02);expect(entry.page=="roster","door transitions exactly once")
	entry.show_page("create");entry.chosen_job=2;entry.chosen_sex=1;entry.fields.name.text="测试道士"
	await settle();await shot("create")
	entry.create_character();await settle()
	expect(app.accounts.characters().size()==1,"create and persist character")
	var profile: Dictionary=app.accounts.characters()[0]
	expect(profile.job=="道士" and profile.gender=="女","class and gender selections preserved")
	await shot("roster")
	entry.enter_selected();expect(entry.page=="notice","enter shows notice")
	entry.confirm_modal();await settle();expect(app.mode=="game","notice enters playable map")
	app.rules.shop("sword",1);app.rules.use_item("sword");app.rules.shop("robe",1);app.rules.use_item("robe")
	app.show_bag();app.show_character();await settle()
	expect(app.windows.windows.size()==2,"multiple windows coexist")
	app.close_panel();expect(app.windows.windows.size()==1,"escape closes top only")
	var t: float=app.elapsed;await settle();expect(app.elapsed>t,"ordinary window keeps time running")
	app.show_settings();t=app.elapsed;await settle();expect(app.elapsed==t,"settings freezes time")
	var pause_key:=InputEventKey.new();pause_key.pressed=true;pause_key.physical_keycode=KEY_P
	app._unhandled_input(pause_key);expect(app.world.paused,"pause key cannot bypass settings freeze")
	app.close_panel();expect(not app.world.paused,"closing settings resumes")
	await shot("world-windows")
	expect(app.save_world(),"save and backup")
	app.show_roster()
	expect(app.accounts.archive_character(profile.id,profile.name),"soft delete")
	expect(app.accounts.characters().is_empty(),"deleted profile hidden")
	expect(app.accounts.restore_character(profile.id),"restore deleted profile")
	expect(app.accounts.character(profile.id).name==profile.name,"restored identity unchanged")
	expect(app.accounts.recover_password("restoration",code,"new-local-test-123","new-local-test-123"),"recover password")
	expect(not app.accounts.recover_password("restoration",code,"again-test-123","again-test-123"),"recovery code cannot replay")
	expect(app.accounts.login("restoration","new-local-test-123"),"recovered password authenticates")
	expect(app.resources.errors.is_empty(),"referenced entry frames and sounds available")
	app.queue_free();await process_frame
	await create_timer(0.2).timeout
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"isolated account, entry animations, window interaction, save; not full content acceptance"}))
	quit(0 if failures.is_empty() else 1)
