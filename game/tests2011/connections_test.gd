extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func walk_route(route: Dictionary,fps: int) -> bool:
	var destination:=Vector2i(route.cell[0],route.cell[1])
	if not app.world.approach(destination):
		print("ROUTE_REFUSED ",JSON.stringify({"map":app.world.metadata.id,"from":str(app.world.player.cell),"to":str(destination)}));return false
	for i in range(fps*15):
		app.world.update_world(1.0/fps,Vector2(1280,800),false)
		var crossing: Dictionary=app.resources.connections.poll(app.world.player)
		if not crossing.is_empty():return app.cross_passage(crossing)
	print("ROUTE_TIMEOUT ",JSON.stringify({"map":app.world.metadata.id,"cell":str(app.world.player.cell),"to":str(destination),"armed":app.resources.connections.armed,"remaining":str(app.world.player.route)}))
	return false
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-connections-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	if not app.resources.errors.is_empty():expect(false,str(app.resources.errors));quit(1);return
	app.start_character({"id":"connections","name":"通路检查","job":"战士","gender":"男"})
	app.world.hide()
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/map-connections.json"))
	var graph: Dictionary={}
	for r in catalog.routes:
		var a:=str(r.component);var b:=str(r.target_component)
		if not graph.has(a):graph[a]=[]
		if not graph.has(b):graph[b]=[]
		graph[a].append(b)
	for reverse in [false,true]:
		var edges:=graph
		if reverse:
			edges={}
			for a in graph:edges[a]=[]
			for a in graph:
				for b in graph[a]:edges[b].append(a)
		var visited: Dictionary={};var queue: Array=[edges.keys()[0]]
		while not queue.is_empty():
			var a=queue.pop_back()
			if visited.has(a):continue
			visited[a]=true;queue.append_array(edges[a])
		expect(visited.size()==graph.size(),"directed world graph reachable reverse="+str(reverse))
	var index:=0
	var runtime: Dictionary={}
	for m in app.resources.maps:
		expect(app.enter_map(m.id),"map loads "+m.id)
		var exits: Array=app.resources.connections.routes
		expect(not exits.is_empty(),"map has physical exit "+m.id)
		expect(app.world.navigation.walkable(app.world.player.cell),"free spawn "+m.id)
		var reachable:=false
		for r in exits:
			var at:=Vector2i(r.cell[0],r.cell[1])
			expect(app.world.navigation.walkable(at),"exit not blocked by terrain or NPC "+m.id+":"+str(at))
			if not reachable and not app.world.navigation.path(app.world.player.cell,at).is_empty():reachable=true
		expect(reachable,"spawn reaches physical exit "+m.id)
		runtime[m.id]={"spawn":[app.world.player.cell.x,app.world.player.cell.y],"npcs":app.world.entities.filter(func(e):return e.kind=="npc").map(func(e):return e.cell)}
		index+=1
		if index%100==0:print("Checked connections ",index);await process_frame
	# Exact coordinates from original mapinfo.txt, not the faulty JSONC Y=0.
	for fps in [30,60,120]:
		for pair in [["0159",330,314],["0149",311,292],["0151",626,320],["0152",637,242]]:
			app.enter_map("3")
			var door:=Vector2i(pair[1],pair[2])
			for d in ClassicNavigation.DIRECTIONS:
				if app.world.navigation.can_step(door+d,door):app.world.player.reset(door+d);break
			app.resources.connections.enter("3",app.world.player)
			var r: Dictionary=app.resources.connections.current.get(Vector2i(pair[1],pair[2]),{})
			expect(not r.is_empty() and r.target_map==pair[0],"original shop door "+str(pair))
			if r.is_empty():continue
			if not app.world.navigation.walkable(app.world.player.cell):expect(false,"door approach walkable");continue
			expect(walk_route(r,fps),"walk into shop at "+str(fps)+" FPS "+pair[0])
			expect(app.world.metadata.id==pair[0] and app.rules.state.map==pair[0],"arrival persisted "+pair[0])
			expect(not app.world.entities.any(func(e):return e.kind=="monster"),"shops contain no forest encounters")
			for i in range(fps):
				app.world.update_world(1.0/fps,Vector2(1280,800),false)
				expect(app.resources.connections.poll(app.world.player).is_empty(),"idle arrival does not bounce")
			var back: Dictionary={}
			for exit in app.resources.connections.routes:
				if exit.target_map=="3" and exit.kind=="reference":back=exit;break
			expect(not back.is_empty(),"original shop return exists")
			if not back.is_empty():expect(walk_route(back,fps),"walk out of shop "+pair[0]+" at "+str(fps))
			expect(app.world.metadata.id=="3" and app.rules.state.map=="3","shop returns to province and persists")
	app.enter_map("0159");expect(app.world.entities.any(func(e):return e.name=="铁匠铺老板" and e.get("service")=="reference" and not EditionRegion.shop(e.id).is_empty()),"blacksmith service instantiated")
	app.enter_map("f013",Vector2i(25,24))
	expect(app.world.player.cell!=Vector2i(25,24),"old isolated saved position relocated to connected floor")
	app.enter_map("3",Vector2i(329,315));app.world.update_world(0,Vector2(1280,800),false)
	var door_route: Dictionary=app.resources.connections.current[Vector2i(330,314)]
	for density in [1.0,2.0]:
		app.world.display_density=density
		var hit: Dictionary=app.world.labels.passage_layout(door_route)
		app.world.handle_click(hit.rect.get_center())
		expect(not app.world.player.route.is_empty() and app.world.player.route.back()==Vector2i(330,314),"door label hit targets tile at density "+str(density))
	# Route latching on a reconstructed two-way junction whose landing is itself
	# a source tile: loading, pausing and standing never trigger a second transfer.
	var bridge: Dictionary=catalog.routes.filter(func(r):return r.kind=="reconstructed_passage")[0]
	app.enter_map(bridge.map,Vector2i(bridge.cell[0],bridge.cell[1]))
	expect(not app.resources.connections.armed,"load on threshold starts disarmed")
	app.world.paused=true;expect(not app.cross_passage(bridge),"pause prevents transition");app.world.paused=false
	app.world.player_alive=false
	var saved_hp=app.rules.state.hp;app.rules.state.hp=0
	expect(not app.cross_passage(bridge),"death prevents transition");app.rules.state.hp=saved_hp
	app.world.player_alive=true
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.cross_passage(bridge),"failed SQLite write refuses transition")
	expect(app.world.metadata.id==bridge.map and app.rules.state==before,"write failure retains map and persisted state")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.resources.errors.is_empty(),"no missing runtime resources")
	var report:={"checks":checks,"failures":failures,"maps":index,"graph_components":graph.size(),"runtime":runtime,"resource_errors":app.resources.errors}
	FileAccess.open("res://../artifacts/connections-0.9.3/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"checks":checks,"failures":failures,"maps":index,"graph_components":graph.size()}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
