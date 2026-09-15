extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize() -> void:
	var Mining=preload("res://scripts/edition2011/mining.gd")
	var nav:=ClassicNavigation.new()
	nav.configure({"size":[5,5],"walkable":[[0,0,0,0,0],[0,1,1,1,0],[0,1,1,1,0],[0,1,1,1,0],[0,0,0,0,0]]})
	var start:=Vector2i(2,2)
	var spot: Dictionary=Mining.nearby_wall(nav,start,"d401",{},0)
	expect(not spot.is_empty() and not nav.path(start,spot.cell).is_empty(),"reachable wall approach")
	expect(Mining.wall(nav,spot.cell,spot.direction),"direction points to actual blocked map cell")
	var used: Dictionary={"veins":{}}
	for y in range(5):
		for x in range(5):
			if not nav.walkable(Vector2i(x,y)):used.veins["d401:%d:%d"%[x,y]]={"used":200,"restore_at":600}
	expect(Mining.nearby_wall(nav,start,"d401",used,599.99).is_empty(),"all exhausted walls excluded")
	expect(not Mining.nearby_wall(nav,start,"d401",used,600).is_empty(),"restored wall available at deadline")
	expect(Mining.nearby_wall(nav,start,"0",{},0).is_empty(),"non mining map excluded")
	nav.set_occupied([Vector2i(2,1),Vector2i(1,2),Vector2i(3,2),Vector2i(2,3)])
	expect(Mining.nearby_wall(nav,start,"d401",{},0).is_empty(),"NPC obstruction is not ore and sealed diagonal corners not crossed")
	var report:={"checks":checks,"failures":failures,"scope":"synthetic navigation geometry, exhausted walls, NPC blockers and map restrictions; no UI or real map travel"}
	FileAccess.open("res://../artifacts/world-story/mining-navigation-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
