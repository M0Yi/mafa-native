extends SceneTree
var app
var checks:=0
var failures: Array=[]
var samples: Array=[]
func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr("FAIL: ",note)
func settle() -> void:
	for i in range(6):await process_frame
func pointer(at: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=at;event.global_position=at
	root.push_input(event,true)
func click(at: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=at;move.global_position=at;root.push_input(move,true)
	pointer(at,true);pointer(at,false);await settle()
func drag(from: Vector2,to: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=from;move.global_position=from;root.push_input(move,true)
	pointer(from,true)
	move=InputEventMouseMotion.new();move.position=to;move.global_position=to;move.relative=to-from;move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move,true)
	pointer(to,false);await settle()
func run() -> void:
	expect(EditionDisplay.window_pixels(Vector2(3840,2160),2)==Vector2i(2560,1600),"Retina default is 1280x800 logical points")
	expect(EditionDisplay.window_pixels(Vector2(1920,1080),1)==Vector2i(1280,800),"standard DPI default")
	expect(EditionDisplay.window_pixels(Vector2(1366,768),1)==Vector2i(1280,704),"default stays in usable screen")
	expect(EditionDisplay.window_pixels(Vector2(3840,2160),2,Vector2(1100,700))==Vector2i(2200,1400),"logical saved size survives density changes")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-display-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle()
	var profile:={"id":"a".repeat(32),"name":"显示适配测试","job":"战士","gender":"男","level":1}
	for screen in [Vector2i(800,600),Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1600),Vector2i(3440,1440),Vector2i(3840,2160),Vector2i(5120,2880)]:
		root.size=screen;app.entry.show_page("login");await settle()
		var zoom:=EditionDisplay.ui_zoom(Vector2(screen))
		expect(app.entry.canvas.scale.is_equal_approx(Vector2.ONE*EditionDisplay.entry_zoom(Vector2(screen))),"entry fits continuously at "+str(screen))
		var login: Control=app.entry.controls.login
		expect(Rect2(Vector2.ZERO,Vector2(screen)).encloses(login.get_global_rect()),"login button remains on screen")
		app.start_character(profile);app.world.paused=true;await settle()
		var hud: EditionHUD=app.classic_hud
		expect(hud.bar.scale==app.windows.scale,"HUD and windows agree on scale")
		expect(hud.bar.position.x==0 and is_equal_approx(hud.logical_width*zoom,screen.x),"HUD uses full width")
		var on_screen:=true
		for item in hud.anchored:on_screen=on_screen and Rect2(Vector2.ZERO,Vector2(screen)).encloses(item[0].get_global_rect())
		expect(on_screen,"all HUD button bounds stay inside viewport")
		expect(is_equal_approx(EditionDisplay.hud_x(764,hud.logical_width)*zoom,screen.x-36*zoom),"settings icon anchored to right edge")
		expect(hud.chat.size.x==hud.logical_width-412,"chat grows without stretching buttons")
		expect(app.world.zoom==EditionDisplay.map_zoom(Vector2(screen)),"map auto scale is independent")
		var cell: Vector2i=app.world.player.cell
		var pointer: Vector2=(Vector2(cell)*ClassicPlayer.CELL+Vector2(24,16)-app.world.camera)*app.world.zoom
		expect(app.world.point_to_cell(pointer)==cell,"map drawing and click transform agree")
		await click(hud.anchored[1][0].get_global_rect().get_center())
		expect(app.windows.windows.has("背包"),"scaled bag button receives viewport mouse events")
		var bag: EditionWindow=app.windows.windows["背包"]
		bag.placement=Vector2(0.2,0.2);await settle()
		var before:=bag.position
		var grab:=bag.header.get_global_rect().get_center()
		await drag(grab,grab+Vector2(30,20)*zoom)
		expect(bag.position.is_equal_approx(before+Vector2(30,20)),"fast drag moves by logical distance without a render frame at "+str(screen)+": "+str(bag.position-before))
		app.windows.close_all()
		await click(hud.anchored[3][0].get_global_rect().get_center())
		expect(app.windows.windows.has("设置与操作") and app.world.paused,"scaled settings button opens and pauses world")
		app.windows.close_all();app.world.paused=true
		app.show_bag();app.show_character();await settle()
		var bounded:=true
		for win in app.windows.windows.values():
			win.placement=Vector2(0.95,0.95);win._process(0)
			bounded=bounded and Rect2(Vector2.ZERO,Vector2(screen)).encloses(win.get_global_rect())
		expect(bounded,"multiple windows remain entirely visible")
		var top: EditionWindow=app.windows.windows[app.windows.order.back()]
		var window_id:=top.window_id;var anchor:=top.placement
		app.windows.close(window_id);var restored: EditionWindow=app.windows.open(window_id,"恢复位置");await settle()
		expect(restored.placement.is_equal_approx(anchor),"normalized placement survives close/reopen")
		app.windows.confirm("显示适配检查",func():pass);await settle()
		expect(app.windows.modal.size.x<=screen.x and app.windows.modal.size.y<=screen.y,"confirmation fits at every scale")
		app.windows.modal.hide();app.windows.close_all()
		samples.append({"pixels":[screen.x,screen.y],"ui_zoom":zoom,"map_zoom":app.world.zoom,"hud_width":hud.logical_width})
	# Resize an existing window across a large change, rather than recreating it.
	root.size=Vector2i(5120,2880);app.show_bag();await settle()
	var win: EditionWindow=app.windows.windows[app.windows.order.back()];win.placement=Vector2(1,1)
	root.size=Vector2i(800,600);await settle()
	expect(Rect2(0,0,800,600).encloses(win.get_global_rect()),"open window remains reachable after shrink")
	expect(app.resources.errors.is_empty(),"all display assets load")
	var result:={"checks":checks,"failures":failures,"samples":samples}
	FileAccess.open("res://../artifacts/display-adaptation/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));app.queue_free();await settle();await create_timer(0.2).timeout;quit(0 if failures.is_empty() else 1)
