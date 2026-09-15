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
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/novice-live-progress-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"progress","name":"委托进度","job":"战士","gender":"男"});app.world.hide()
	expect(app.rules.novice_quest("nv_arrival") and app.rules.novice_quest("nv_arrival") and app.rules.novice_quest("nv_equip"),"prepare actual starter rewards and equipment quest")
	var elder: Dictionary=EditionVillage.entities().filter(func(e):return e.id=="border:elder")[0]
	app.game_panel(elder.name,Vector2(620,460))
	var view=load("res://scripts/edition2011/ui/quest_panel.gd").new();app.form.add_child(view);view.setup(app,elder);await settle()
	expect(view.selected=="nv_equip" and view.submit_control.disabled,"equipment task initially not deliverable")
	var control=view.submit_control
	expect(app.rules.use_item("wood_sword") and app.rules.use_item("robe"),"equip actual reward items")
	await settle()
	expect(view.submit_control==control and not control.disabled,"equipment changes enable existing button without rebuilding")
	expect(app.rules.novice_quest("nv_equip") and app.rules.novice_quest("nv_hunt"),"complete equipment and accept hunt")
	view.selected="nv_hunt";view.refresh();await settle();control=view.submit_control
	for i in range(3):expect(app.rules.reward_kill("progress-chicken-"+str(i),"village_chicken"),"prepared kill event")
	await settle()
	expect(control.disabled and view.progress_rows.back().label.text=="击败鸡 3/3 · 鸡肉 0/3","kill count updates but missing ground meat prevents delivery")
	for loot in app.rules.state.ground_loot.duplicate(true):
		if loot.type=="chicken_meat":expect(app.rules.pickup(loot.uid,"0",EditionVillage.SPAWN),"pick up meat")
	await settle()
	expect(view.submit_control==control and not control.disabled and "可以交付" in view.progress_rows.back().label.text,"pickup updates progress and button live")
	expect(app.rules.warehouse("chicken_meat",true),"put one meat away")
	await settle()
	expect(control.disabled and "鸡肉 2/3" in view.progress_rows.back().label.text,"losing required bag material disables delivery again")
	expect(app.rules.warehouse("chicken_meat",false),"retrieve meat")
	await settle();expect(not control.disabled,"retrieval enables delivery again")
	expect(app.rules.novice_quest("nv_hunt"),"deliver hunt")
	await settle()
	expect(view.selected=="nv_hunt" and view.submit_control.disabled and view.submit_control.text=="已完成","external submission refreshes lifecycle while preserving selected quest")
	expect(app.rules.novice_quest("nv_patrol"),"accept patrol")
	view.selected="nv_patrol";view.refresh();await settle();control=view.submit_control
	expect(control.disabled,"patrol not ready before arrival")
	expect(app.rules.novice_patrol("0",EditionVillage.PATROL),"prepared patrol arrival")
	await settle()
	expect(view.submit_control==control and not control.disabled and "可以交付" in view.progress_rows.back().label.text,"patrol arrival updates without reopening")
	view.tab=1;view.refresh();view.show_journey(3);await settle()
	var journey_label=view.details.get_child(0)
	expect(app.rules.warehouse("potion",true),"unrelated transaction while reading journey")
	await settle()
	expect(is_instance_valid(journey_label) and view.details.get_child(0)==journey_label and journey_label.text=="学会远行","unrelated revision does not reset journey reading")
	var report:={"checks":checks,"failures":failures,"scope":"visible novice panel updates after real inventory/equipment/pickup transactions; supplied kill events, no natural combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/novice-live-progress-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
