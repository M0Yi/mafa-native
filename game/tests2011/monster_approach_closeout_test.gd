extends SceneTree
# Isolated interaction regression; no hardware input or FPS claim.
var app
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate()
	app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-approach-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app)
	app.set_process(false)
	app.start_character({"id":"cpu","name":"接近目标测试","job":"战士","gender":"女"})
	app.world.paused=false;app.show_bag()
	for i in range(10):await process_frame
	app.close_panel()
	var monster: Dictionary=app.world.entities.filter(func(e):return e.kind=="monster")[0]
	var placed:=false
	for direction in ClassicNavigation.DIRECTIONS:
		var target: Vector2i=app.world.player.cell+direction*3
		if not app.world.navigation.mobile(target):continue
		monster.cell=[target.x,target.y];app.world.actors.mover(monster).reset(target)
		app.interact(monster)
		if app.world.player.route.is_empty():continue
		assert(app.world.player.route.back()!=target)
		assert(app.world.player.route.back().distance_to(target)<1.5)
		assert(app.pending_attack.is_empty())
		# Replan while partway through a step; new route must start at destination.
		app.world.player.update(0.01,Vector2i.ZERO,false)
		var destination: Vector2i=app.world.player.destination
		app.gameplay.approach_target(monster)
		assert(app.world.player.progress<1.0)
		assert(not app.world.player.route.is_empty())
		if not app.world.player.route.is_empty():
			assert(app.world.navigation.can_step(destination,app.world.player.route[0]))
			for reserved in app.world.actors.player_reserved_cells():assert(reserved not in app.world.player.route)
		assert(app.rules.set_assist("attack",true))
		app.gameplay.origin_map=app.world.metadata.id;app.gameplay.origin=app.world.player.cell
		app.world.manual_control_until=app.world.elapsed+0.5
		app.selected={}
		var route_before: Array=app.world.player.route.duplicate()
		app.gameplay.assist_left=0;app.gameplay.update(0.31)
		assert(app.world.player.route==route_before and app.selected.is_empty())
		app.world.manual_control_until=0
		app.gameplay.assist_left=0;app.gameplay.update(0.31)
		assert(app.world.player.route==route_before and app.selected.is_empty())
		placed=true;break
	assert(placed)
	monster.cell=[-5,-5]
	app.interact(monster)
	assert(app.world.player.route.is_empty())
	assert(app.pending_message=="无法到达目标附近，请换一条路线")
	assert(app.pending_attack.is_empty())
	print("MONSTER_APPROACH_PASS unreachable feedback; distance 3 routes adjacent without overlapping or premature damage; fixture invocation, not hardware")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
