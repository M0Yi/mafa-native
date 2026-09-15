extends SceneTree
const Cinema=preload("res://scripts/edition2011/ui/story_cinematic.gd")
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(800,600)
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/cinema-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"cinema","name":"行者","job":"道士","gender":"男"});app.world.paused=false
	var failures: Array=[]
	var original: Dictionary=app.rules.state.duplicate(true)
	Cinema.play(app,EditionRules.Story.quest("story_letter"),"accept")
	var nodes=get_nodes_in_group("story_cinematic")
	if nodes.size()!=1 or not app.world.paused or not app.windows.has_modal():failures.append("blocks and pauses")
	if nodes.size()==1:
		var scene=nodes[0];scene.elapsed=5
		for i in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/story-cinematic.png")
		if not scene.caption.text.contains("道士") or not scene.caption.text.contains("符药"):failures.append("profession narrative")
		scene.finish();scene.finish()
	for i in range(4):await process_frame
	if app.world.paused or app.windows.has_modal() or app.rules.state!=original:failures.append("skip restores world without changing rewards")
	app.world.paused=true;Cinema.play(app,EditionRules.Story.quest("story_letter"),"accept")
	nodes=get_nodes_in_group("story_cinematic")
	if nodes.size()==1:nodes[0].finish()
	if not app.world.paused:failures.append("preserves preexisting pause")
	print(JSON.stringify({"failures":failures,"scope":"native cinematic render, profession text, skip and pause preservation; no physical input"}))
	app.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
