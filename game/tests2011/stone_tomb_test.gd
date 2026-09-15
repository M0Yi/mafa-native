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
	app.enter_map("3",Vector2i(305,324));app._process(0)
	var route: Dictionary=app.resources.connections.current[Vector2i(305,323)]
	expect(route.target_map=="d710","corrected province entrance targets stone tomb")
	var label: Dictionary=app.world.labels.passage_layout(route)
	await click(label.rect.get_center())
	for i in range(300):
		app._process(1.0/60)
		if app.world.metadata.id=="d710":break
	expect(app.world.metadata.id=="d710","viewport click walks through stone tomb entrance")
	expect(app.world.navigation.mobile(app.world.player.cell),"arrival is not an isolated tile")
	# Click an interior floor tile through the real viewport input path.
	var target:=Vector2i(29,22)
	app._process(0)
	await click((Vector2(target)*ClassicPlayer.CELL+ClassicPlayer.CELL/2-app.world.camera)*app.world.zoom)
	for i in range(300):app._process(1.0/60)
	expect(app.world.metadata.id=="d710" and app.world.player.cell==target,"can walk off arrival into tomb")
	route=app.resources.connections.routes.filter(func(r):return r.target_map=="3")[0]
	app._process(0);label=app.world.labels.passage_layout(route);await click(label.rect.get_center())
	for i in range(400):
		app._process(1.0/60)
		if app.world.metadata.id=="3":break
	expect(app.world.metadata.id=="3","can walk back to province")
	app.enter_map("d710",Vector2i(26,23));app._process(0)
	expect(app.world.player.cell!=Vector2i(26,23) and app.world.navigation.mobile(app.world.player.cell),"old trapped save relocates on map load")
	app.world.show();await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/combat-passages-0.9.8/stone-tomb.png")
	var report:={"checks":checks,"failures":failures,"input":"viewport mouse events; no direct button signal emission"}
	FileAccess.open("res://../artifacts/combat-passages-0.9.8/stone-tomb-input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
