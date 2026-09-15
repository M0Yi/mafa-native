extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/player-route-blocked-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"blocked","name":"寻路受阻","gender":"男","job":"战士"});app.world.hide();app.world.paused=false
	var world=app.world
	world.navigation.configure({"size":[5,1],"walkable":[[1,1,1,1,1]]})
	world.player.path_avoid.clear();world.entities.clear();world.actors.reset()
	var before: Dictionary=app.rules.state.duplicate(true)
	for fps in [30,60,120]:
		world.player.reset(Vector2i.ZERO)
		var actor: Dictionary={"id":"blocking-traveler","kind":"traveler","cell":[1,0],"hp":250}
		world.entities=[actor];world.actors.reset()
		expect(world.player.go_to(Vector2i(4,0)),"initial geometric route exists")
		var messages: int=app.chat_history.size()
		world.player.update(1.0/fps,Vector2i.ZERO,false)
		expect(world.player.cell==Vector2i.ZERO and world.player.progress==1 and world.player.route.is_empty(),"living actor stops route before overlap")
		expect(app.chat_history.size()==messages+1 and "已停止寻路" in app.pending_message,"blocked route emits visible chat once")
		for i in range(fps*2):world.player.update(1.0/fps,Vector2i.ZERO,false)
		expect(app.chat_history.size()==messages+1,"idle does not repeat warning")
		expect(not world.player.begin_step(Vector2i(1,0),false),"manual movement also respects occupied actor")
		actor.hp=0
		expect(world.player.go_to(Vector2i(4,0)),"route can be retried after blocker no longer alive")
		for i in range(fps*3):world.player.update(1.0/fps,Vector2i.ZERO,false)
		expect(world.player.cell==Vector2i(4,0),"corpse permits complete movement")
		actor.hp=250;actor.cell=[2,0];world.player.reset(Vector2i.ZERO)
		var motion: ClassicPlayer=world.actors.mover(actor)
		motion.destination=Vector2i(1,0);motion.progress=0.5
		expect(not world.actors.player_can_step(Vector2i(1,0)) and not world.actors.player_can_step(Vector2i(2,0)),"moving actor reserves origin and destination")
		actor.kind="monster"
		expect(not world.actors.player_can_step(Vector2i(1,0)),"monster reserves incoming step too")
		world.entities.clear();world.player.reset(Vector2i.ZERO)
		world.player.go_to(Vector2i(4,0));messages=app.chat_history.size()
		world.player.update(1.0/fps,Vector2i(1,0),false)
		expect(app.chat_history.size()==messages,"manual cancellation is not reported as obstruction")
	world.navigation.configure({"size":[5,5],"walkable":[[1,1,1,1,1],[1,1,1,1,1],[1,1,1,1,1],[1,1,1,1,1],[1,1,1,1,1]]})
	world.actors.reset();world.player.reset(Vector2i(0,2))
	world.entities=[{"id":"target","kind":"monster","cell":[2,2],"hp":100},{"id":"neighbor","kind":"traveler","cell":[1,2],"hp":250}]
	expect(world.approach(Vector2i(2,2)),"occupied target uses reachable free neighbor")
	expect(not world.player.route.is_empty() and Vector2i(1,2) not in world.player.route and Vector2i(2,2) not in world.player.route,"approach avoids target and other living entity")
	for i in range(180):world.player.update(1.0/60,Vector2i.ZERO,false)
	expect(Vector2(world.player.cell-Vector2i(2,2)).length()<=1.5 and world.player.cell!=Vector2i(2,2),"actual approach reaches interaction range without overlap")
	expect(world.player.path_avoid.is_empty(),"actor snapshot does not become permanent door avoidance")
	world.player.reset(Vector2i.ZERO)
	var occupied: Array[Vector2i]=[Vector2i(2,2)];world.navigation.set_occupied(occupied)
	world.entities.clear()
	for direction in ClassicNavigation.DIRECTIONS:
		var cell: Vector2i=Vector2i(2,2)+direction
		world.entities.append({"id":str(cell),"kind":"traveler","cell":[cell.x,cell.y],"hp":250})
	world.player.go_to(Vector2i(4,4))
	expect(not world.approach(Vector2i(2,2)) and world.player.route.is_empty(),"fully surrounded NPC refuses approach and clears stale route")
	world.entities.clear()
	expect(world.approach(Vector2i(2,2)),"retry after crowd clears uses fresh occupancy")
	for y in range(5):
		for x in range(5):
			var cell:=Vector2i(x,y)
			expect(world.navigation.grid.is_point_solid(cell)==not world.navigation.walkable(cell),"temporary occupancy restores navigation")
	expect(app.rules.state==before,"movement feedback does not modify task rewards or persistence")
	var report:={"checks":checks,"failures":failures,"scope":"actual player and actor reservation functions, native chat delivery at 30/60/120; synthetic corridor and controlled blockers, no combat or full-map travel"}
	FileAccess.open("res://../artifacts/world-story/player-route-blocked-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
