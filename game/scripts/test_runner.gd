extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var nav := ClassicNavigation.new()
	nav.configure({"size":[5,5],"walkable":[[0,0,0,0,0],[0,1,0,1,0],[0,1,1,1,0],[0,1,1,1,0],[0,0,0,0,0]]})
	check(not nav.walkable(Vector2i(-1,1)),"outside map blocked")
	check(not nav.can_step(Vector2i(1,1),Vector2i(2,2)),"diagonal wall corner blocked")
	check(nav.can_step(Vector2i(1,2),Vector2i(2,3)),"clear diagonal allowed")
	check(not nav.can_step(Vector2i(1,1),Vector2i(1,3)),"cannot jump across cells")
	check(nav.path(Vector2i(1,1),Vector2i(2,1)).is_empty(),"blocked click rejected")
	var route := nav.path(Vector2i(1,1),Vector2i(3,1))
	check(route.size() > 3,"route goes around barrier")
	for i in range(1,route.size()):
		check(nav.can_step(route[i-1],route[i]),"every planned step respects corner rule")
	var player := ClassicPlayer.new()
	player.nav = nav
	player.reset(Vector2i(1,1))
	check(player.go_to(Vector2i(3,1)),"click creates route")
	for i in range(500):
		player.update(1.0/60.0,Vector2i.ZERO,false)
		check(nav.walkable(player.cell),"player remains walkable")
	check(player.cell == Vector2i(3,1),"player reaches target")
	player.reset(Vector2i(1,1))
	player.update(0,Vector2i(1,1),false)
	check(player.destination == Vector2i(1,1),"manual movement cannot cut corner")
	player.reset(Vector2i(1,2))
	player.update(0,Vector2i(1,0),true)
	check(player.action == "run" and is_equal_approx(player.step_seconds,0.16),"shift enables run")
	player.update(0.17,Vector2i.ZERO,true)
	check(player.cell == Vector2i(2,2),"run moves one checked cell at a time")
	# Validate indexing using a completely open grid for every direction.
	var open_nav := ClassicNavigation.new()
	open_nav.configure({"size":[3,3],"walkable":[[1,1,1],[1,1,1],[1,1,1]]})
	player.nav = open_nav
	for d in range(8):
		player.reset(Vector2i(1,1))
		check(player.begin_step(Vector2i(1,1)+ClassicNavigation.DIRECTIONS[d],false),"eight directions available")
		check(player.direction == d,"correct direction frame index")
	var save := ClassicSave.new()
	save.directory = "user://unit-tests-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(save.directory)
	check(save.save_state("test",Vector2i(1,1),3,7),"save writes atomically")
	var state := save.load_state(nav,"test",Vector2i(1,2))
	check(state.cell == Vector2i(1,1) and state.zoom == 3 and state.direction == 7,"save round trip")
	var file := FileAccess.open(save.directory.path_join("save.json"),FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	state = save.load_state(nav,"test",Vector2i(1,2))
	check(state.cell == Vector2i(1,2),"corrupt save returns to spawn")
	check(not save.message.is_empty(),"corruption reported")
	var found_backup := false
	for name in DirAccess.get_files_at(save.directory):
		if name.begins_with("save.corrupt-"):
			found_backup = true
			check(FileAccess.get_file_as_string(save.directory.path_join(name)) == "{broken","corrupt bytes preserved")
	check(found_backup,"backup exists")
	for data in [{"version":1,"map_id":"test","cell":[1.5,2],"zoom":2,"direction":4}, {"version":1,"map_id":"test","cell":[-1,2],"zoom":2,"direction":4}]:
		file = FileAccess.open(save.directory.path_join("save.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(save.load_state(nav,"test",Vector2i(1,2)).cell == Vector2i(1,2),"invalid save position rejected")
	var resources := ClassicResources.new()
	check(not resources.load_all("res://missing-test-resources"),"missing resources fail clearly")
	check(resources.error_message.contains("manifest.json"),"missing resource filename reported")
	print("TEST_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
