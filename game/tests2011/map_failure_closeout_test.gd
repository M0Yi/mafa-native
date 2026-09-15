extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-map-failure-"+Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.path=path+".sqlite";root.add_child(app);app.set_process(false)
	app.start_character({"id":"failure","name":"切图恢复","job":"战士","gender":"女"})
	app.world.entities.append({"id":"closeout_spawn","spawn_id":"closeout_spawn","dragon_warning":true})
	var old_metadata: Dictionary=app.world.metadata.duplicate(true)
	var old_file=app.world.map_file
	var old_cells: Array=app.world.navigation.cells.duplicate(true)
	var old_cell: Vector2i=app.world.player.cell
	var old_entities: Array=app.world.entities.duplicate(true)
	app.pending_attack={"fixture":true};app.death_return_at=123
	var base: String=EditionResources.BASE
	DirAccess.make_dir_recursive_absolute(path+"/maps")
	EditionResources.BASE=path+"/"
	app.resources.map_by_id["closeout_missing"]={"id":"closeout_missing","width":1,"height":1,"stride":12,"spawn":[0,0]}
	# Missing files, truncated payload, bad magic, mismatched dimensions/stride.
	for stage in range(6):
		if stage==1:
			var mask:=FileAccess.open(path+"/maps/closeout_missing.walk",FileAccess.WRITE);mask.store_8(1);mask.close()
		if stage>=2:
			var packet:=FileAccess.open(path+"/maps/closeout_missing.mapbin",FileAccess.WRITE)
			packet.store_buffer(("BAD!" if stage==3 else "M211").to_ascii_buffer())
			packet.store_16(2 if stage==4 else 1);packet.store_16(1);packet.store_32(16 if stage==5 else 12)
			packet.store_buffer(PackedByteArray([0]) if stage==2 else PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0]));packet.close()
		assert(not app.enter_map("closeout_missing",Vector2i.ZERO))
		assert(app.world.metadata==old_metadata and app.world.map_file==old_file)
		assert(app.world.navigation.cells==old_cells and app.world.player.cell==old_cell)
		assert(app.world.entities==old_entities)
		assert(app.pending_attack=={"fixture":true} and app.death_return_at==123)
		assert(not app.region.remembered.has("closeout_spawn"))
		var route:={"map":old_metadata.id,"cell":[old_cell.x,old_cell.y],"target_map":"closeout_missing","target_cell":[0,0]}
		assert(not app.cross_passage(route))
		assert(app.world.map_file==old_file and app.world.entities==old_entities and app.pending_attack=={"fixture":true})
		assert(not app.changing_map and not app.resources.connections.armed and app.pending_message.contains("无法读取"))
		var npc:={"id":"closeout_npc","map":old_metadata.id,"cell":[old_cell.x,old_cell.y]}
		route.merge({"npc":"closeout_npc","enabled":true,"cost":0,"min_level":1})
		var gold: int=app.rules.state.gold
		assert(not app.teleport_with_npc(npc,route))
		assert(app.world.map_file==old_file and app.world.entities==old_entities and app.rules.state.gold==gold)
	EditionResources.BASE=base
	assert(app.enter_map("1"))
	assert(app.world.metadata.id=="1" and app.pending_attack.is_empty() and app.death_return_at==-1)
	assert(app.region.remembered.has("closeout_spawn") and not app.region.remembered.closeout_spawn.has("dragon_warning"))
	print("PASS: six missing/corrupt map cases preserve scene, collision, player and pending state; valid retry enters map")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	DirAccess.remove_absolute(path+"/maps/closeout_missing.walk")
	DirAccess.remove_absolute(path+"/maps/closeout_missing.mapbin")
	DirAccess.remove_absolute(path+"/maps");DirAccess.remove_absolute(path)
	for suffix in [".sqlite",".sqlite-wal",".sqlite-shm",".sqlite.backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
