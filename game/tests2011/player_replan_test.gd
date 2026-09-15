extends SceneTree
var checks:=0
var failures: Array=[]
var blocked: Array[Vector2i]=[]
var replans:=0
var stops:=0
var player:=ClassicPlayer.new()
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func replacement(goal: Vector2i) -> Array[Vector2i]:
	replans+=1
	if goal in blocked:return []
	var path:=player.nav.path_avoiding(player.cell,goal,blocked)
	if not path.is_empty():path.pop_front()
	return path
func run() -> void:
	var cells: Array=[]
	for y in range(7):cells.append([1,1,1,1,1,1,1,1,1])
	player.nav=ClassicNavigation.new();player.nav.configure({"size":[9,7],"walkable":cells})
	player.step_filter=func(at):return at not in blocked
	player.route_replanner=replacement
	player.route_blocked.connect(func(_at):stops+=1)
	player.reset(Vector2i(2,2));expect(player.go_to(Vector2i(6,2)),"initial route")
	blocked=[Vector2i(3,2)]
	player.update(1.0/60,Vector2i.ZERO,false)
	expect(replans==1 and stops==0 and not player.route.is_empty(),"new occupant triggers alternate route without failure")
	var overlap:=false
	for i in range(300):
		player.update(1.0/60,Vector2i.ZERO,false)
		if player.cell in blocked or player.destination in blocked:overlap=true
	expect(player.cell==Vector2i(6,2) and not overlap,"detour arrives without entering occupied cell")
	blocked.clear();player.reset(Vector2i(2,2));player.go_to(Vector2i(6,2));blocked=[Vector2i(3,2)]
	player.update(1.0/60,Vector2i.ZERO,false)
	var before:=replans
	player.update(1.0/60,Vector2i.DOWN,false)
	expect(player.route.is_empty() and player.destination==Vector2i(2,3),"manual movement takes over replanned path")
	for i in range(100):player.update(1.0/60,Vector2i.ZERO,false)
	expect(player.cell==Vector2i(2,3) and replans==before,"old goal never resumes after manual input")
	blocked.clear();player.reset(Vector2i(2,2));player.go_to(Vector2i(6,2))
	for y in range(7):blocked.append(Vector2i(3,y))
	player.update(1.0/60,Vector2i.ZERO,false)
	expect(not player.route.is_empty() and stops==0,"closed corridor briefly waits for dynamic occupant")
	before=replans
	for i in range(100):player.update(1.0/60,Vector2i.ZERO,false)
	expect(replans==before+2 and stops==1 and player.route.is_empty(),"unreachable goal stops after bounded retries")
	blocked.clear();player.go_to(Vector2i(6,2));blocked=[Vector2i(3,2)];player.update(1.0/60,Vector2i.ZERO,false)
	player.reset(Vector2i(1,1));before=replans
	for i in range(100):player.update(1.0/60,Vector2i.ZERO,false)
	expect(player.cell==Vector2i(1,1) and player.route.is_empty() and replans==before,"reset clears any replanned destination")
	for fps in [30,60,120]:
		blocked.clear();player.reset(Vector2i(2,2));player.go_to(Vector2i(6,2))
		for y in range(7):blocked.append(Vector2i(3,y))
		var old_stops:=stops;var entered:=false
		for frame in range(fps*4):
			if frame>=int(fps*0.3):blocked.clear()
			player.update(1.0/fps,Vector2i.ZERO,false)
			if player.cell in blocked or player.destination in blocked:entered=true
		expect(player.cell==Vector2i(6,2) and stops==old_stops and not entered,"moving obstruction clears safely at "+str(fps)+" FPS")
	var report:={"checks":checks,"failures":failures,"scope":"controlled movement grid: new dynamic blocker, detour, manual takeover, closed corridor and reset; no world combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/player-replan-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
