extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	for density in [1.0,2.0]:
		var stable:=true
		for width in range(800,2601):
			var screen: Vector2=Vector2(width,800)*density
			stable=stable and is_equal_approx(EditionDisplay.map_zoom(screen,0,density),2*density) and is_equal_approx(EditionDisplay.ui_zoom(screen,0,density),density)
		expect(stable,"auto map/UI stay stable through every horizontal pixel at density "+str(density))
		stable=true
		for height in range(600,1801):
			var screen: Vector2=Vector2(2560,height)*density
			stable=stable and is_equal_approx(EditionDisplay.map_zoom(screen,0,density),2*density) and is_equal_approx(EditionDisplay.ui_zoom(screen,0,density),density)
		expect(stable,"auto map/UI stay stable through every vertical pixel at density "+str(density))
	for requested in [1,2,3,4]:
		var smooth:=true;var previous:=0.0
		for size in range(600,3201):
			var factor:=EditionDisplay.ui_zoom(Vector2(size*4.0/3.0,size),requested,2)
			if previous>0:smooth=smooth and absf(factor-previous)<0.002
			previous=factor
		expect(smooth,"oversized manual UI shrinks continuously: "+str(requested))
	expect(EditionDisplay.map_zoom(Vector2(800,600),3)==EditionDisplay.map_zoom(Vector2(3840,2160),3),"manual map scale never overridden by window size")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-displayfix-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"displayfix","name":"定位测试","job":"战士","gender":"男"});app.world.paused=true
	var actor: Dictionary=EditionVillage.entities().filter(func(e):return e.get("species")=="village_chicken")[0]
	actor.cell=[274,656];app.world.player.reset(Vector2i(274,656));app.world.entities=[actor]
	for screen in [Vector2i(1598,1198),Vector2i(1600,1200),Vector2i(1602,1202),Vector2i(2558,1598),Vector2i(2560,1600),Vector2i(2562,1602),Vector2i(3200,1800)]:
		app.display_density=2;root.size=screen;await settle()
		expect(app.world.zoom==4,"map stable across old threshold "+str(screen))
		expect(is_equal_approx(app.windows.scale.x,app.classic_hud.bar.scale.x),"HUD/window scale agree")
		expect(app.world.labels.get_global_transform().is_equal_approx(Transform2D.IDENTITY),"label overlay stays in screen coordinates")
		var layout: Dictionary=app.world.labels.layout(actor)
		expect(absf(layout.name_rect.get_center().x-layout.head.x)<=0.5,"monster nickname centered over sprite")
		expect(layout.health_rect.end.y<layout.name_rect.position.y and layout.name_rect.end.y<layout.head.y,"name and health are above sprite, not over body")
		expect(app.world.pick_entity(layout.name_rect.get_center()).get("id")==actor.id,"nickname hit box uses same projection")
		var frame: Rect2=app.resources.frame_bounds("mon17",app.world.actor_frame(actor))
		var center: Vector2=(Vector2(actor.cell[0],actor.cell[1])*ClassicPlayer.CELL+frame.get_center()-app.world.camera)*app.world.zoom
		expect(app.world.pick_entity(center).get("id")==actor.id,"monster image can be clicked after resize")
		var cell: Vector2i=app.world.player.cell
		var point: Vector2=(Vector2(cell)*ClassicPlayer.CELL+Vector2(24,16)-app.world.camera)*app.world.zoom
		expect(app.world.point_to_cell(point)==cell,"map mouse round trip after resize")
		app.show_bag();app.show_character();await settle()
		var contained:=true
		for win in app.windows.windows.values():contained=contained and Rect2(Vector2.ZERO,Vector2(screen)).encloses(win.get_global_rect())
		expect(contained,"open bag and gear fit while resizing")
		app.windows.close_all()
	for direction in range(8):
		actor.direction=direction
		var initial: Dictionary=app.world.labels.layout(actor)
		var stable:=true
		for frame in range(4):
			app.world.elapsed=frame*0.2
			stable=stable and app.world.labels.layout(actor).name_rect==initial.name_rect
		expect(stable,"nickname does not bob across idle frames, direction "+str(direction))
	for sample in [{"id":"npc","name":"边界村小店老板","bank":"npc","frame":60,"frames":4,"kind":"npc","cell":[274,656]}, {"id":"large","name":"体型较大的怪物","bank":"mon1","frame":0,"frames":4,"kind":"monster","hp":100,"max_hp":100,"generation":0,"cell":[274,656]}]:
		app.world.paused=false;app.world.entities=[sample]
		var info: Dictionary=app.world.labels.layout(sample)
		expect(absf(info.name_rect.get_center().x-info.head.x)<=0.5,"different name length and creature height centered")
		app.selected={}
		var at: Vector2=info.name_rect.get_center()
		var click:=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;click.position=at;click.global_position=at;root.push_input(click,true)
		click=click.duplicate();click.pressed=false;root.push_input(click,true);await settle()
		expect(app.selected.get("id")==sample.id,"real viewport nickname click selects "+sample.id)
		app.windows.close_all()
	expect(app.resources.errors.is_empty(),"all positioning metadata and frames available")
	var result:={"checks":checks,"failures":failures}
	FileAccess.open("res://../artifacts/display-fix-0.7.1/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
