extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func click(view,label: String) -> void:
	var button: Button=null
	for candidate in app.panel.navigation_buttons(view):
		if candidate.text==label:button=candidate;break
	expect(button!=null,"service button exists: "+label)
	if button==null:return
	if button.get_parent()==view.details:view.details.get_parent().ensure_control_visible(button)
	await settle()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=button.get_global_rect().get_center();e.global_position=e.position;root.push_input(e,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/village-service-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"guard","name":"村长事务","job":"战士","gender":"男"});app.world.hide()
	var elder: Dictionary=EditionVillage.entities().filter(func(e):return e.id=="border:elder")[0]
	for mode in ["paused","far","dead","normal"]:
		app.windows.close_all();app.enter_map("0",EditionVillage.SPAWN);app.world.paused=false
		var prepared: Dictionary=app.rules.state.duplicate(true);prepared.hp=0 if mode=="dead" else 50;prepared.quests.erase("nv_arrival")
		expect(app.rules.apply(prepared,"health_fixture"),"prepare health")
		# Open near the elder first, then change conditions with the window still open.
		app.game_panel(elder.name,Vector2(620,460))
		var view=load("res://scripts/edition2011/ui/quest_panel.gd").new();app.form.add_child(view);view.setup(app,elder);await settle()
		if mode=="paused":app.world.paused=true
		if mode=="far":app.world.player.cell=Vector2i(300,630)
		var before: Dictionary=app.rules.state.duplicate(true)
		await click(view,"接受任务")
		if mode=="normal":expect(app.rules.state.quests.get("nv_arrival")=="accepted","near living unpaused character accepts")
		else:expect(app.rules.state==before,"blocked acceptance preserves state: "+mode)
		if mode!="normal":
			var accepted: Dictionary=app.rules.state.duplicate(true);accepted.quests.nv_arrival="accepted";accepted.novice={"chickens":0,"patrol":false}
			expect(app.rules.apply(accepted,"accepted_task_fixture"),"prepare deliverable task")
		view.refresh();await settle();before=app.rules.state.duplicate(true)
		await click(view,"交付任务")
		if mode=="normal":expect(app.rules.state.quests.get("nv_arrival")=="done","normal delivery works")
		else:expect(app.rules.state==before,"blocked delivery preserves rewards: "+mode)
		before=app.rules.state.duplicate(true)
		await click(view,"恢复")
		if mode=="normal":expect(app.rules.state.hp==app.rules.max_hp(),"normal recovery works")
		else:expect(app.rules.state==before,"blocked recovery preserves state: "+mode)
	var report:={"checks":checks,"failures":failures,"scope":"viewport mouse village services after pause, distance or death change; prepared health/location, no natural combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/village-service-guard-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
