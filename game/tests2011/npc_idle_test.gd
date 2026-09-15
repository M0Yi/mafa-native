extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/npc-idle-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(6):await process_frame
	app.set_process(false)
	var count:=0
	for npc in EditionRegion.data().npcs:
		if not npc.enabled or not npc.has("idle_source"):continue
		count+=1
		expect(int(npc.frames)==4 and int(npc.frame_ms)==200,"reference four-frame 200ms stand "+npc.id)
		var start: int=npc.frame
		for sample in range(12):
			# Sample inside each frame interval to avoid float boundary ambiguity.
			app.world.elapsed=sample*0.2+0.01
			var actual: int=app.world.actor_frame(npc)
			expect(actual==start+sample%4,"three cycles use expected frame "+npc.id)
			var image: Dictionary=app.resources.frame("npc",actual)
			expect(not image.is_empty() and image.get("body_visible",false),"decoded stand frame is visible "+npc.id+":"+str(actual))
		if int(npc.raw.body) in [24,25,27,32]:expect(int(npc.idle_source.start)==30,"special stand offset retained")
	expect(count==190,"all currently enabled reference NPCs covered")
	var fallback: Dictionary={"kind":"npc","frame":900,"frames":4}
	app.world.elapsed=0.26;expect(app.world.actor_frame(fallback)==901,"local NPC without timing metadata keeps existing cadence")
	var report:={"checks":checks,"npcs":count,"failures":failures,"scope":"actual frame selector and decoded visibility for three stand cycles per enabled reference NPC; no hardware screenshots, attack, turn or special-effect verification"}
	FileAccess.open("res://../artifacts/world-story/npc-idle-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(6):await process_frame
	call_deferred("quit",0 if failures.is_empty() else 1)
