extends SceneTree
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var world=load("res://scripts/edition2011/world.gd").new()
	world.navigation.configure({"size":[7,5],"walkable":[[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1]]})
	world.player.nav=world.navigation;world.actors.world=world
	var npc:=Vector2i(4,2);var gate:=Vector2i(3,3)
	var occupied: Array[Vector2i]=[npc];var gates: Array[Vector2i]=[gate]
	world.navigation.set_occupied(occupied);world.player.path_avoid=gates
	world.player.reset(Vector2i(2,3))
	expect(world.approach(npc),"NPC beside a gate has another approach")
	expect(not world.player.route.is_empty() and gate not in world.player.route,"NPC approach does not target or traverse the gate")
	for i in range(200):world.player.update(1.0/60,Vector2i.ZERO,false)
	expect(world.player.cell!=gate and Vector2(world.player.cell-npc).length()<=1.5,"actual movement ends beside NPC without teleport")
	expect(world.approach(npc) and world.player.route.is_empty(),"already adjacent player stays in place")
	expect(not world.navigation.grid.is_point_solid(gate),"temporary route query leaves gate traversable")
	world.player.reset(Vector2i(2,3))
	expect(world.approach(gate),"explicitly targeting a gate still works")
	expect(world.player.route.back()==gate,"explicit gate target is preserved")
	world.labels.free();world.light_layer.free();world.free()
	var report:={"checks":checks,"failures":failures,"scope":"NPC beside teleporter, alternate adjacent endpoint, actual steps and intentional gate targeting in synthetic geometry"}
	FileAccess.open("res://../artifacts/world-story/npc-gate-approach-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
