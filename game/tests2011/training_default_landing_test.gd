extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/training-default-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"default","name":"练习场落点","gender":"男","job":"战士"});app.world.hide()
	expect(app.enter_map("0111"),"load default research destination")
	app.world.paused=false
	var landing: Vector2i=app.world.player.cell
	expect(app.world.entities.any(func(e):return e.get("reference_name","")=="练功师"),"trainers are actually present")
	var chosen: Dictionary={}
	for gate in app.resources.connections.by_map["0111"]:
		if gate.target_map!="0":continue
		if app.world.approach(Vector2i(gate.cell[0],gate.cell[1])):chosen=gate;break
	expect(not chosen.is_empty(),"default landing is not trapped by stationary trainers")
	if not chosen.is_empty():
		# Leave the arrival tile before intentional return when it is also a doorway.
		if app.world.player.route.is_empty():
			for d in ClassicNavigation.DIRECTIONS:
				var candidate: Vector2i=landing+d
				if candidate not in app.world.player.path_avoid and app.world.approach(candidate):
					for i in range(120):app.world.player.update(1.0/60,Vector2i.ZERO,false);app.resources.connections.poll(app.world.player)
					break
			app.world.approach(Vector2i(chosen.cell[0],chosen.cell[1]))
		for frame in range(1800):
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
			var gate: Dictionary=app.resources.connections.poll(app.world.player)
			if not gate.is_empty():app.cross_passage(gate);break
		expect(app.world.metadata.id=="0","default entry can walk out without killing trainers")
	var report:={"checks":checks,"failures":failures,"landing":[landing.x,landing.y],"scope":"actual default destination and stationary trainer occupancy, continuous exit walking; no combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/training-default-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
