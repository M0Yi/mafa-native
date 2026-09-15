extends SceneTree
var app
var checks:=0
var failures: Array=[]
const PAGES=["login","register","password","recovery","world","door","roster","create","delete","restore","notice","recovery_code","quit","credits"]
const SIZES=[Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,800),Vector2i(1365,769),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(3440,1440),Vector2i(3840,2160),Vector2i(5120,2880),Vector2i(900,1400)]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr("FAIL: ",note)
func settle() -> void:
	for i in range(4):await process_frame
func click(control: Control) -> void:
	var at:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await settle()
func key(code: Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-entry-fit-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle()
	app.accounts.data={"version":1,"accounts":[{"id":"f".repeat(32),"username":"fixture","salt":"0".repeat(32),"hash":"0".repeat(64),"iterations":LocalAccounts.ITERATIONS,"characters":[]}]}
	app.accounts.current_id="f".repeat(32)
	app.accounts.create_character("适配战士","战士","男")
	app.accounts.create_character("适配法师","法师","女")
	app.accounts.last_recovery_code="TEST-ONLY-NOT-A-REAL-RECOVERY-CODE"
	for page in PAGES:
		app.entry.modal_text="窗口适配测试\n\n保留原图比例，输入框和按钮同步移动。"
		app.entry.show_page(page);await settle()
		if page=="register":
			expect(app.entry.fields.username.get_rect()==Rect2(241,180,117,16),"registration input fits Prguse 63 slot")
		if page in ["password","recovery"]:
			expect(app.entry.fields.password.get_rect()==Rect2(429,327,137,16),"password input fits Prguse 50 slot")
			expect(app.entry.controls.password_submit.text.is_empty() and app.entry.controls.password_submit.get_rect()==Rect2(370,402,76,32),"password button matches baked glyph without duplicate caption")
		var inputs: Dictionary=app.entry.fields.duplicate()
		for field in inputs.values():
			if field.editable:field.text="resize_test"
		var focused: Control=inputs.values()[0] if not inputs.is_empty() else null
		if focused!=null:focused.grab_focus()
		for dimensions in SIZES:
			root.size=dimensions;await settle()
			var viewport:=Rect2(Vector2.ZERO,Vector2(dimensions))
			var label: String=page+" at "+str(dimensions)
			expect(is_equal_approx(app.entry.canvas.scale.x,app.entry.canvas.scale.y),"uniform artwork scale: "+label)
			var safe:=viewport.grow(1)
			var bounded:=true
			for b in app.entry.controls.values():bounded=bounded and safe.encloses(b.get_global_rect()) and not b.get_global_rect().intersects(app.entry.message.get_global_rect())
			expect(bounded,"buttons visible and clear of footer: "+label)
			var retained:=true
			for id in inputs:
				var field: LineEdit=inputs[id]
				retained=retained and app.entry.fields[id]==field and safe.encloses(field.get_global_rect())
				if field.editable:retained=retained and field.text=="resize_test"
			expect(retained,"resize preserves fields and values: "+label)
			expect(focused==null or root.gui_get_focus_owner()==focused,"resize preserves keyboard focus: "+label)
			app.entry.notify("账号输入未通过检查，请核对账号和密码后重试。".repeat(6));await settle()
			expect(safe.encloses(app.entry.message.get_global_rect()),"long status remains inside viewport: "+label)
	# Resize after arriving on a page, then use the actual input dispatcher.
	for dimensions in SIZES:
		app.entry.show_page("login");root.size=dimensions;await settle()
		await click(app.entry.controls.register);expect(app.entry.page=="register","register hit: "+str(dimensions))
		app.entry.fields.username.text="resize_test";await key(KEY_TAB)
		expect(root.gui_get_focus_owner()==app.entry.fields.password,"Tab reaches password after scaling")
		await click(app.entry.controls.back);expect(app.entry.page=="login","registration back hit")
		await click(app.entry.controls.password);expect(app.entry.page=="password","password hit")
		await click(app.entry.controls.back)
		await click(app.entry.controls.recovery);expect(app.entry.page=="recovery","recovery hit")
		await click(app.entry.controls.back);expect(app.entry.page=="login","recovery back hit")
	root.size=Vector2i(1280,800);await settle();var before: float=app.entry.canvas.scale.x
	root.size=Vector2i(1280,801);await settle()
	expect(app.entry.canvas.scale.x>before and app.entry.canvas.scale.x-before<0.01,"one-pixel resize changes layout continuously")
	for factor in [1,2,4]:
		app.windows.requested_scale=factor;await settle()
		expect(is_equal_approx(app.entry.canvas.scale.x,801.0/620.0),"game UI preference does not lock entry scale")
	expect(app.resources.errors.is_empty(),"entry assets available")
	var result:={"checks":checks,"failures":failures,"pages":PAGES,"sizes":SIZES.map(func(s):return [s.x,s.y])}
	FileAccess.open("res://../artifacts/entry-adaptation/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));app.queue_free();await settle();await create_timer(0.2).timeout;quit(0 if failures.is_empty() else 1)
