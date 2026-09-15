extends SceneTree
var app
var failures: Array=[]
var lights:=0
func check(ok: bool,note: String) -> void:
	if not ok:failures.append(note)
func settle() -> void:
	for i in range(8):await process_frame
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/map-light-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"map-light","name":"灯光检查","job":"战士","gender":"女"})
	var world=app.world
	for y in range(590,646):
		for x in range(265,313):
			var cell: PackedByteArray=world.cell_data(x,y)
			if cell.size()<12 or (cell[8]&0x80)==0:continue
			var first: int=(cell.decode_u16(4)&0x7fff)-1
			if first<0:continue
			var bank: String="objects"+str(int(cell[10])+1) if cell[10]>0 else "objects"
			lights+=1
			for i in range(maxi(1,cell[8]&0x7f)):
				var frame: Dictionary=app.resources.frame(bank,first+i)
				check(not frame.is_empty(),"light frame available")
				if frame.is_empty():continue
				var at: Vector2=world.front_position(Vector2i(x,y),frame,true)
				check(at==Vector2(x*48,y*32)+frame.offset-Vector2(2,68),"reference light hotspot")
				check(world.front_position(Vector2i(x,y),frame,false)==Vector2(x*48,(y+1)*32-frame.size.y),"ordinary object anchoring preserved")
	check(lights>0,"real village lights covered")
	world.player.reset(EditionVillage.SPAWN)
	for zoom in [1,2,3]:
		world.preferred_zoom=zoom;world.update_world(0,Vector2(root.size),false);world.queue_redraw();await settle();RenderingServer.force_draw()
		if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://../artifacts/world-story/map-lights-"+str(zoom)+"x.png")
	print(JSON.stringify({"lights":lights,"failures":failures,"scope":"village blend cells and all their animation frames, three map zooms; screenshots only when a graphical renderer is available; isolated save"}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
