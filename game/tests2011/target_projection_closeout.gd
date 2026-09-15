extends SceneTree
class Probe extends Node2D:
	var world
	func _process(_delta):queue_redraw()
	func _draw():
		for e in world.entities:
			if e.kind!="monster" or e.name!="鸡":continue
			var bounds: Rect2=world.resources.frame_bounds(e.bank,world.actor_frame(e))
			var box:=Rect2((world.actors.anchor(e)+bounds.position-world.camera)*world.zoom,bounds.size*world.zoom)
			if not box.intersects(Rect2(Vector2.ZERO,Vector2(1280,800))):continue
			draw_rect(box,Color.RED,false,2)
			draw_rect(world.labels.layout(e).name_rect,Color.GREEN,false,2)
func _initialize():call_deferred("run")
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	root.size=Vector2i(1280,800)
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-projection-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app)
	app.start_character({"id":"projection","name":"投影诊断","job":"战士","gender":"女"})
	app.enter_map("0",Vector2i(300,614));app.world.paused=false
	var probe:=Probe.new();probe.world=app.world;root.add_child(probe)
	for i in range(120):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/closeout-target-projection.png")
	print("TARGET_PROJECTION_CAPTURED live simulation; red body hit rectangle, green name rectangle")
	probe.queue_free();app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
