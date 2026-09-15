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
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-passage-input-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"input","name":"入口操作检查","job":"战士","gender":"男"});app.world.hide()
	app.enter_map("3",Vector2i(329,315));app._process(0)
	var route: Dictionary=app.resources.connections.current[Vector2i(330,314)]
	var label: Dictionary=app.world.labels.passage_layout(route)
	await click(label.rect.get_center())
	expect(not app.world.player.route.is_empty(),"viewport mouse click on door label starts path")
	for i in range(240):
		app._process(1.0/60)
		if app.world.metadata.id=="0159":break
	expect(app.world.metadata.id=="0159","mouse path crosses into blacksmith")
	var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_M;key.keycode=KEY_M;root.push_input(key,true)
	key=key.duplicate();key.pressed=false;root.push_input(key,true);await settle()
	var button:=find_button(app.windows,"本区出入口")
	expect(button!=null,"M opens world map with passage navigation")
	if button!=null:await click(button.get_global_rect().get_center())
	button=find_button(app.windows,"盟重省 [")
	expect(button!=null,"passage window lists original province exit")
	if button!=null:await click(button.get_global_rect().get_center())
	expect(not app.world.player.route.is_empty(),"actual passage button hit starts walking")
	for i in range(240):
		app._process(1.0/60)
		if app.world.metadata.id=="3":break
	expect(app.world.metadata.id=="3" and app.rules.state.map=="3","exit button walks back and persists province")
	var report:={"checks":checks,"failures":failures,"input":"viewport mouse and keyboard events; no direct button signal emission"}
	FileAccess.open("res://../artifacts/combat-passages-0.9.8/shop-input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
