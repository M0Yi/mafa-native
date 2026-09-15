extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-auto-combat-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"auto","name":"自动战斗检查","job":"战士","gender":"女"})
	app.enter_map("0",Vector2i(300,614));app.world.paused=false
	assert(app.rules.set_assist("attack",true));assert(app.rules.set_assist("pickup",false))
	var blocked:=[0]
	app.world.player.route_blocked.connect(func(_cell):blocked[0]+=1)
	var inventory_before: Dictionary=app.rules.state.inventory.duplicate(true)
	var initial: Vector2i=app.world.player.cell
	for i in range(3600):app._process(1.0/60)
	var loot: Array=app.rules.state.get("ground_loot",[])
	var report:={"scope":"60 simulated seconds via real main update and AI, followed by walking pickup and same-process DB close/reopen at village shop area; new unarmed warrior and enabled auto attack fixtures, no hardware input or FPS claim","moved":initial!=app.world.player.cell,"cell":str(app.world.player.cell),"hp":app.rules.state.hp,"ground_loot":loot.size(),"regional_deaths":app.rules.state.get("regional_deaths",{}).size(),"message":app.pending_message,"blocked":blocked[0],"inventory_unchanged":inventory_before==app.rules.state.inventory}
	var passed: bool=report.moved and report.regional_deaths>0 and report.ground_loot>0 and report.inventory_unchanged
	if passed:
		assert(app.rules.set_assist("attack",false))
		assert(app.rules.set_assist("pickup",true))
		var target: Dictionary=loot[0].duplicate(true)
		var target_cell:=Vector2i(target.cell[0],target.cell[1])
		var count_before: int=app.rules.state.gold if target.type=="gold" else int(app.rules.state.inventory.get(target.type,0))
		var initial_distance: float=app.world.player.cell.distance_to(target_cell)
		app.gameplay.auto_pickup_underfoot(app.rules.state.assist)
		var remains: bool=app.rules.state.ground_loot.any(func(row):return row.uid==target.uid)
		report["remote_not_picked"]=remains if initial_distance>0 else true
		var reached: bool=app.world.approach(target_cell)
		var picked:=not remains
		for i in range(1200):
			if picked:break
			app._process(1.0/60)
			picked=not app.rules.state.ground_loot.any(func(row):return row.uid==target.uid)
		var count_after: int=app.rules.state.gold if target.type=="gold" else int(app.rules.state.inventory.get(target.type,0))
		report["walked_to_pickup"]=reached and picked and app.world.player.cell==target_cell
		report["pickup_quantity_received"]=count_after-count_before>=int(target.count)
		assert(app.save_world())
		var saved_inventory: Dictionary=app.rules.state.inventory.duplicate(true)
		var saved_loot: Array=app.rules.state.ground_loot.duplicate(true)
		app.store.close();assert(app.store.open())
		assert(app.rules.attach({"id":"auto","name":"自动战斗检查","job":"战士","gender":"女"}))
		report["reload_detail"]={"inventory_before":saved_inventory,"inventory_after":app.rules.state.inventory,"loot_before":saved_loot,"loot_after":app.rules.state.ground_loot}
		report["pickup_restored"]=app.rules.state.inventory==JSON.parse_string(JSON.stringify(saved_inventory)) and app.rules.state.ground_loot==JSON.parse_string(JSON.stringify(saved_loot))
		passed=passed and report.remote_not_picked and report.walked_to_pickup and report.pickup_quantity_received and report.pickup_restored
	print(JSON.stringify(report))
	FileAccess.open("res://../artifacts/closeout-auto-combat.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if passed else 1)
