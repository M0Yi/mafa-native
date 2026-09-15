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
func capture(name: String) -> void:
	app._process(0);app.world.queue_redraw()
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/regional-0.9.4/"+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-regional-input-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"input","name":"区域操作检查","job":"战士","gender":"男"})
	app.enter_map("0",Vector2i(289,615));app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=10000;app.rules.apply(next,"fixture")
	var npc: Dictionary=app.world.entities.filter(func(n):return n.id=="server:npc:6")[0]
	app.show_reference_npc(npc);await capture("teleporter")
	var b:=find_button(app.windows,"前往 盟重")
	expect(b!=null,"town teleporter route button exists")
	if b!=null:await click(b.get_global_rect().get_center())
	expect(app.world.metadata.id=="3" and app.rules.state.gold==8000,"viewport route click charges once and enters province")
	await capture("province")
	for map in ["0159","0149"]:
		app.enter_map(map);app.world.paused=false
		var merchants: Array=app.world.entities.filter(func(n):return n.kind=="npc" and not EditionRegion.shop(n.id).is_empty())
		expect(not merchants.is_empty(),"interior has reference merchant "+map)
		if merchants.is_empty():continue
		npc=merchants[0];app.show_reference_npc(npc);await capture("shop-"+map)
		app.windows.close_all()
	var report:={"checks":checks,"failures":failures,"input":"Godot viewport mouse events; not manual macOS interaction"}
	FileAccess.open("res://../artifacts/regional-0.9.4/input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
