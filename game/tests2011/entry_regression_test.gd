extends SceneTree

var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]
var tracks: Array=[]
var ids: Array=[]

func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr("FAIL: ",note)
func settle() -> void:
	for i in range(4):await process_frame
func click(at: Vector2) -> void:
	var position: Vector2=app.entry.canvas.get_global_transform()*at
	var move:=InputEventMouseMotion.new();move.position=position;root.push_input(move,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=position
		root.push_input(event,true);await process_frame
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate()
	app.store.path=OS.get_environment("TMPDIR")+"mafa-entry-regression-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.allow_focus_pause=false;root.add_child(app);await settle()
	app.sound_started.connect(func(id):sounds.append(id))
	app.music_started.connect(func(track):tracks.append(track))
	# Synthetic identity isolates mouse routing and persistence from password hashing.
	app.accounts.data={"version":1,"accounts":[{"id":"f".repeat(32),"username":"fixture","salt":"0".repeat(32),"hash":"0".repeat(64),"iterations":LocalAccounts.ITERATIONS,"characters":[]}]}
	app.accounts.current_id="f".repeat(32)
	for i in range(2):
		var c: Dictionary=app.accounts.create_character("测试角色"+str(i),"战士","男");ids.append(c.id)
	app.entry.show_page("roster");await settle()
	expect(sounds==[101],"first roster revival emits one matching sound")
	app.entry.selection_time=0.1;app.entry.show_page("create")
	expect(app.entry.selection_time>=0.65,"leaving mid revival completes the interrupted visual")
	app.entry.show_page("roster")
	expect(sounds==[101],"returning does not replay or silently resume a partial revival")
	for dimensions in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1600,1200)]:
		root.size=dimensions;await settle()
		sounds.clear();await click(Vector2(720,469))
		expect(app.entry.selected_id==ids[1],"right baked Select hit at "+str(dimensions))
		expect(sounds==[101],"one revival at "+str(dimensions))
		sounds.clear();await click(Vector2(720,469));expect(sounds.is_empty(),"same selection is silent")
		await click(Vector2(169,468));expect(app.entry.selected_id==ids[0],"left Select hit")
		await click(Vector2(400,498));expect(app.entry.page=="create","baked Create hit")
		expect(app.entry.fields.name.get_rect()==Rect2(492,193,136,18),"name stays inside baked inset")
		sounds.clear();await click(Vector2(534,259));expect(app.entry.chosen_job==1,"mage icon hit")
		expect(sounds==[103],"job icon uses normal click, no melt sound")
		sounds.clear();await click(Vector2(534,259));expect(sounds.is_empty(),"unchanged job is silent")
		await click(Vector2(488,259));expect(app.entry.chosen_job==0,"warrior icon hit")
		sounds.clear();await click(Vector2(579,332));expect(app.entry.chosen_sex==1 and sounds==[103],"female icon and single click")
		await click(Vector2(534,332));expect(app.entry.chosen_sex==0,"male icon hit")
		await click(Vector2(675,126));expect(app.entry.page=="roster","native close glyph hit")
		expect(tracks==["sellect-loop2.wav"],"return keeps background music playing")
		await click(Vector2(405,537));expect(app.entry.page=="credits","visible credits button has behavior")
		await click(Vector2(390,438));expect(app.entry.page=="roster","credits returns to selection")
	# Empty-name failure must not create, revive, or restart background music.
	await click(Vector2(400,498));sounds.clear();await click(Vector2(560,460))
	expect(app.entry.page=="create" and app.accounts.characters().size()==2,"invalid submit preserves create form")
	expect(sounds==[104],"failed submit has only stone button sound")
	app.entry.fields.name.text="第三名角色";sounds.clear()
	# Submit through real key event routing, including the focused LineEdit path.
	app.entry.fields.name.grab_focus();await settle()
	var key:=InputEventKey.new();key.keycode=KEY_ENTER;key.physical_keycode=KEY_ENTER;key.pressed=true;root.push_input(key,true)
	key=key.duplicate();key.pressed=false;root.push_input(key,true);await settle()
	expect(app.accounts.characters().size()==3,"Enter creates exactly one character")
	expect(sounds==[104,101],"Enter submit and successful revival each occur once")
	var third: String=app.accounts.characters()[2].id
	expect(app.entry.roster_page==1 and app.entry.selected_id==third,"third character selected on page two")
	expect(app.entry.controls.create.disabled,"full account disables creation")
	await click(Vector2(610,418));expect(app.entry.roster_page==0 and app.entry.selected_id==ids[0],"paging selects visible character")
	await click(Vector2(610,418));expect(app.entry.roster_page==1 and app.entry.selected_id==third,"paging back selects third character")
	expect(app.resources.errors.is_empty(),"all referenced assets available")
	var result:={"checks":checks,"failures":failures,"scope":"viewport mouse/key dispatch, selection audio events, three sizes, three characters"}
	FileAccess.open("res://../artifacts/ui-fix/regression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));app.queue_free();await settle();await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
