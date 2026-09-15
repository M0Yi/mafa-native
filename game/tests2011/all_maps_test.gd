extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var resources:=EditionResources.new()
	if not resources.initialize():printerr(resources.errors);quit(1);return
	var world:=EditionWorld.new();world.resources=resources;root.add_child(world);world.visible=false
	var errors: Array=[];var count:=0;var start:=Time.get_ticks_msec()
	for m in resources.maps:
		if not world.enter_map(m.id):errors.append({"id":m.id,"error":"enter_map_failed"})
		else:
			var target:=Vector2i(m.service_spots[0][0],m.service_spots[0][1])
			if world.navigation.path(world.player.cell,target).is_empty():errors.append({"id":m.id,"error":"unreachable_guide"})
			var data:=world.cell_data(world.player.cell.x,world.player.cell.y)
			if data.size()!=int(m.stride):errors.append({"id":m.id,"error":"invalid_chunk_read"})
		count+=1
		if count%100==0:print("Loaded ",count," maps")
		await process_frame
	var report={"maps_loaded":count,"errors":errors,"seconds":(Time.get_ticks_msec()-start)/1000.0,"scope":"native Godot map load, spawn-to-guide path, chunk read; visuals and complete world content not certified"}
	var file:=FileAccess.open("res://../artifacts/client-10th-audit/native-maps.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
