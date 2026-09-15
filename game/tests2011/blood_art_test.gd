extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func run() -> void:
	root.size=Vector2i(1280,800);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/blood-art-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"blood-art","name":"祭坛核验","gender":"男","job":"战士"});expect(app.enter_map("d10061",Vector2i(20,21)),"altar loads")
	app.world.paused=true;var boss: Dictionary={}
	for e in app.world.entities:
		if e.get("reference_name","")=="双头血魔":boss=e;break
	expect(not boss.is_empty(),"reconstructed boss actually loaded")
	if boss.is_empty():quit(1);return
	for action in boss.profile.actions.values():
		for direction in range(8):
			for i in range(int(action.count)):
				var frame: int=boss.profile.base+action.start+direction*(action.count+action.skip)+i
				expect(not app.resources.frame(boss.bank,frame).is_empty(),"body frame "+str(frame))
	for event in ["idle","attack","weapon","hurt","die"]:
		expect(app.resources.sound_id(EditionCreatures.sound_id(boss,event))!=null,"mapped sound decodes "+event)
	boss.hp=0;boss.motion_time=app.world.elapsed-2.0
	for direction in range(8):
		boss.direction=direction
		var frame: int=app.world.actor_frame(boss)
		expect(frame==int(boss.profile.base)+269+direction*10,"corpse uses final directional death frame")
		var image: Image=app.resources.frame(boss.bank,frame).texture.get_image()
		expect(image.get_used_rect().get_area()>0,"corpse has visible pixels in direction "+str(direction))
	boss.direction=0
	await settle();app.world.queue_redraw();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/blood-boss-corpse.png")
	var report:={"checks":checks,"failures":failures,"scope":"actual altar entity, every configured directional body frame and sound resource decode, visible corpse after death for all eight directions, native corpse screenshot; combat balance and audio listening pending"}
	FileAccess.open("res://../artifacts/world-story/blood-art-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
