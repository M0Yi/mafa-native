extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func gate(id: String,source: String,at: Array,target: String) -> Dictionary:
	return {"id":id,"map":source,"cell":at,"target_map":target,"target_cell":[0,0],"component":[source,1],"target_component":[target,1]}
func _initialize():call_deferred("run")
func run() -> void:
	var nav:=ClassicNavigation.new();nav.configure({"size":[7,1],"walkable":[[1,1,1,1,1,1,1]]})
	var graph: Dictionary={"home":[gate("short","home",[5,0],"goal"),gate("blocking","home",[3,0],"trap"),gate("detour","home",[0,0],"middle")],"middle":[gate("finish","middle",[0,0],"goal")]}
	var start:=Vector2i(2,0)
	expect(not nav.path(start,Vector2i(5,0)).is_empty(),"plain geometry would select misleading shortcut")
	var route: Array=Planner.plan(graph,"home","goal",start,nav)
	expect(route.size()==2 and route[0].id=="detour","preview selects accessible detour rather than crossing trap")
	var player:=ClassicPlayer.new();player.nav=nav;player.reset(start)
	for row in graph.home:player.path_avoid.append(Vector2i(row.cell[0],row.cell[1]))
	expect(not player.go_to(Vector2i(5,0)),"execution also rejects shortcut")
	expect(player.go_to(Vector2i(route[0].cell[0],route[0].cell[1])),"execution accepts advertised first leg")
	graph.home.pop_back()
	expect(Planner.plan(graph,"home","goal",start,nav).is_empty(),"no reachable first leg reports no route")
	expect(not nav.grid.is_point_solid(Vector2i(3,0)),"query does not leave gate blocked")
	player.reset(Vector2i(2,0));expect(player.begin_step(Vector2i(3,0),false),"manual movement can intentionally enter gate")
	var report:={"checks":checks,"failures":failures,"scope":"synthetic narrow corridor with intervening teleporter, alternate route and manual gate access"}
	FileAccess.open("res://../artifacts/world-story/route-gate-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
