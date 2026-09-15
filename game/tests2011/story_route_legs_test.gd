extends SceneTree
var app
var failures: Array=[]
var checks:=0
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-legs-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"legs","name":"通路核验","gender":"男","job":"战士"});app.world.hide();app.world.paused=true
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../artifacts/world-story/routes-tests.json"))
	var catalog: Dictionary={}
	for rows in app.resources.connections.by_map.values():
		for row in rows:catalog[row.id]=row
	var examined: Dictionary={}
	for ids in report.routes.values():
		for index in range(ids.size()-1):
			var arrival: Dictionary=catalog[ids[index]];var departure: Dictionary=catalog[ids[index+1]]
			var key: String=arrival.id+":"+departure.id
			if examined.has(key):continue
			examined[key]=true;checks+=1
			if not app.enter_map(arrival.target_map,Vector2i(arrival.target_cell[0],arrival.target_cell[1])):failures.append(key+" map load failed");continue
			app.world.paused=true
			var at:=Vector2i(departure.cell[0],departure.cell[1])
			if app.world.player.cell!=at and app.world.navigation.path(app.world.player.cell,at).is_empty():failures.append(key+" landing cannot reach next door in "+arrival.target_map)
			if checks%20==0:print("checked route legs ",checks);await settle()
	var result:={"checks":checks,"failures":failures,"scope":"loads each unique intermediate route landing with live NPC collision and verifies path to next door; no time-based walking, door animation or combat balance test"}
	FileAccess.open("res://../artifacts/world-story/route-legs-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
