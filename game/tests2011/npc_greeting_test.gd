extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func texts(node: Node) -> String:
	var value: String=node.text if node is Label else ""
	for child in node.get_children():value+="\n"+texts(child)
	return value
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/greeting-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(6):await process_frame
	app.set_process(false);app.start_character({"id":"greeting","name":"人物问候","job":"战士","gender":"男"});app.world.hide()
	for id in ["server:merchant:50","server:merchant:103","server:merchant:104"]:
		var npc: Dictionary=app.rules.story_npc(id);var before: Dictionary=app.rules.state.duplicate(true)
		app.show_reference_npc(npc)
		var rendered:=texts(app.form)
		expect(rendered.contains(npc.dialogue),"ordinary greeting visible despite empty shop definition "+id)
		expect(not rendered.contains("goto @") and not rendered.contains("random 2"),"no script control text "+id)
		expect(app.rules.state==before,"opening greeting does not execute script rewards "+id)
		app.windows.close_all()
	var result:={"checks":checks,"failures":failures,"scope":"constructed NPC panel label contents and unchanged rule state; no mouse input, visual screenshot or conditional script execution"}
	FileAccess.open("res://../artifacts/world-story/npc-greeting-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));app.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
