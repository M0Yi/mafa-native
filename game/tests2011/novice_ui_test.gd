extends SceneTree
var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func click(point: Vector2,double:=false) -> void:
	var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.double_click=double and down;root.push_input(event,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-novice-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.sound_started.connect(func(id):sounds.append(id))
	app.start_character({"id":"novice-ui","name":"村庄测试","job":"战士","gender":"男"});app.rules.novice_quest("nv_arrival");app.rules.novice_quest("nv_arrival")
	for screen in [Vector2i(800,600),Vector2i(1280,800),Vector2i(2560,1600)]:
		root.size=screen;app.show_bag();await settle()
		var bag: EditionWindow=app.windows.windows["背包"]
		var grid: EditionItemPanel=bag.body.get_child(1)
		check(grid.cells.get_child_count()==40,"bag first page 40 cells "+str(screen))
		for item in grid.get_children():
			if item is Button and item.text=="翻页":await click(item.get_global_rect().get_center());break
		check(grid.page==1 and grid.cells.get_child_count()==8,"second page includes 8 empty destination slots")
		for slot in grid.cells.get_children():check(slot.slot_index<48,"bag never exposes invalid slot")
		grid.page=0;grid.rebuild();await settle()
		if not app.rules.state.equipment.has("weapon"):
			for slot in grid.cells.get_children():
				if not slot.item.is_empty() and slot.item.type=="wood_sword":await click(slot.get_global_rect().get_center(),true);break
			check(app.rules.state.equipment.get("weapon")=="wood_sword","viewport double click equips wooden sword")
			for slot in grid.cells.get_children():
				if not slot.item.is_empty() and slot.item.type=="robe":await click(slot.get_global_rect().get_center(),true);break
			check(app.rules.state.equipment.get("armor")=="robe","viewport double click equips cloth")
		app.show_character();await settle()
		var gear: EditionWindow=app.windows.windows["人物属性"]
		check(Rect2(Vector2.ZERO,Vector2(screen)).encloses(gear.get_global_rect()),"equipment window fits "+str(screen))
		var panel: Control=gear.body.get_child(1)
		var slots:=0
		for child in panel.get_children():
			if child is EditionItemSlot:slots+=1;check(panel.get_global_rect().encloses(child.get_global_rect()),"equipment hit box within panel")
		check(slots==13,"13 equipment targets")
		check(panel.stats.position.y+panel.stats.size.y<=panel.details.position.y,"attributes and details do not overlap")
		app.windows.close_all()
	check(111 in sounds and 112 in sounds,"wooden weapon and armor item sounds")
	app.show_village_map();await settle()
	var map_window: EditionWindow=app.windows.windows["边界村地图"]
	var map_view: Control=map_window.body.get_child(1)
	check(map_view.terrain!=null,"village navigation map generated from original collision")
	app.windows.close_all()
	# Resolve hit exactly once, and freeze scheduled hit while paused at different frame rates.
	for fps in [30,60,120]:
		app.set_process(false);app.enter_map("0",Vector2i(274,656));app.elapsed=0;app.world.elapsed=0;app.fight_timer=0;app.world.paused=false
		var chicken: Dictionary=app.world.entities.filter(func(e):return e.get("species")=="village_chicken")[0]
		chicken.hp=1;app.selected=chicken
		var kills:=int(app.rules.state.kills)
		app.attack_target();app.world.paused=true
		app._process(5)
		check(chicken.hp==1 and app.elapsed==0,"paused hit does not advance "+str(fps))
		app.world.paused=false
		for i in range(fps):app._process(1.0/fps)
		check(chicken.hp==0 and int(app.rules.state.kills)==kills+1,"one hit outcome at "+str(fps)+" FPS")
		check(chicken.motion=="die" and 1805 in sounds,"chicken death animation and mapped sound")
		app.resolve_attack();check(int(app.rules.state.kills)==kills+1,"hit cannot repeat")
		app.world.elapsed=2;app.world.queue_redraw();await settle()
	check(51 in sounds,"wooden sword swing uses wooden sound")
	app.world.gender="女";app.rules.character.gender="女";app.show_character();await settle()
	check(app.resources.errors.is_empty(),"village NPC, scene, UI and female gear frames all readable")
	var result:={"checks":checks,"failures":failures,"sounds":sounds}
	FileAccess.open("res://../artifacts/novice-village/ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
