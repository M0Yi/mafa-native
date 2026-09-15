extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func press(key: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=key;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-repair-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for pair in [["story_home_repair","wood_sword","weapon"],["story_centipede_crystal_repair","robe","armor"]]:
		app.windows.close_all();app.start_character({"id":pair[0],"name":"手柄修理","job":"战士","gender":"男"});app.world.hide()
		var q: Dictionary=EditionRules.Story.quest(pair[0]);var repair: Dictionary={}
		for o in q.objectives:
			if o.type=="repair":repair=o;break
		var npc: Dictionary=app.rules.story_npc(repair.npc)
		expect(app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1])),"enter repair NPC map");app.world.paused=false
		var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.gold=1000
		var slot: int=EditionInventory.SLOTS.find(pair[2]);next.items=next.items.filter(func(i):return i.container!="equipment" or int(i.slot)!=slot)
		next.items.append(EditionInventory.make_item(pair[1],1,"equipment",slot,50));EditionInventory.mirror(next)
		expect(app.rules.apply(next,"repair_equipment_fixture"),"prepare worn equipped item")
		app.controller_interact(npc);await settle();var view=app.form.get_child(1)
		for i in range(view.rows.size()):
			if view.rows[i].id==q.id:view.cursor=i;break
		await press(JOY_BUTTON_A)
		expect("Y 修理" in view.hint.text,"task describes controller repair action")
		var before: Dictionary=app.rules.state.duplicate(true)
		await press(JOY_BUTTON_Y)
		expect(app.windows.order.back()=="手柄修理" and app.rules.state==before,"Y opens quote without charging")
		var service=app.form.get_child(1);var cell: Vector2i=app.world.player.cell
		for size in [Vector2i(800,600),Vector2i(1280,800)]:
			root.size=size;await settle()
			expect(Rect2(Vector2.ZERO,Vector2(size)).encloses(app.panel.get_global_rect()),"repair panel fits "+str(size))
			expect(app.panel.get_global_rect().encloses(service.get_child(service.get_child_count()-1).get_global_rect()),"repair hints visible "+str(size))
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://../artifacts/world-story/controller-repair-"+pair[2]+"-"+str(size.x)+".png")
		root.size=Vector2i(800,600);await settle()
		app.allow_focus_pause=true;app._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await settle();await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"focus pause cannot pass repair input to window")
		app.windows.modal.hide();app.windows.pause_reason="";app.world.paused=false;app.allow_focus_pause=false
		next=app.rules.state.duplicate(true);next.hp=0;app.rules.apply(next,"death_fixture");await settle()
		var dead: Dictionary=app.rules.state.duplicate(true);await press(JOY_BUTTON_A)
		expect(app.rules.state==dead,"dead character cannot repair through stale panel")
		next=app.rules.state.duplicate(true);next.hp=before.hp;app.rules.apply(next,"restore_health_fixture");before=app.rules.state.duplicate(true)
		app.world.player.cell+=Vector2i(20,20);await press(JOY_BUTTON_A)
		expect(app.rules.state==before and "商人身边" in service.result.text,"stale distant window refuses repair")
		app.world.player.cell=cell;app.world.paused=true;await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"pause refuses repair");app.world.paused=false
		next=app.rules.state.duplicate(true);next.gold=0;app.rules.apply(next,"empty_budget_fixture");await settle()
		before=app.rules.state.duplicate(true);await press(JOY_BUTTON_A)
		expect(app.rules.state==before and "修理需要" in service.result.text,"insufficient money refuses repair")
		next=app.rules.state.duplicate(true);next.gold=1000;app.rules.apply(next,"restore_budget_fixture");await settle()
		before=app.rules.state.duplicate(true);var quote: Dictionary=app.rules.reference_repair_quote(npc.id)
		app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"failed save rolls back repair and task progress")
		app.store.db.query("PRAGMA query_only=OFF;");await press(JOY_BUTTON_A)
		expect(app.rules.state.gold==before.gold-int(quote.cost) and app.rules.reference_repair_quote(npc.id).items.is_empty(),"A repairs and charges quoted fee")
		expect(EditionRules.Story.progress(app.rules.state,q,q.objectives.find(repair))==1,"repair advances named NPC objective")
		before=app.rules.state.duplicate(true);await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"repeated A does not charge again")
		await press(JOY_BUTTON_B)
		expect(app.windows.order.back()=="手柄人物委托" and view.reading and view.rows[view.cursor].id==q.id,"B restores selected task detail")
		expect("修理目标已完成。" in view.text.text,"underlying task updates completion")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport joypad events for weapon and armor repair, 800/1280 window bounds and screenshots, distance/focus/death/pause/budget/save failure/retry/back; accepted quest, position and wear fixtures; no physical controller or natural journey"}
	FileAccess.open("res://../artifacts/world-story/controller-repair-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
