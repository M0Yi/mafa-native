extends "res://tests2011/mining_journey_test.gd"
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mining-sources-regions-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"regions","name":"矿区指引","job":"战士","gender":"男"});app.world.hide()
	for mid in Mining.MAPS:
		expect(app.enter_map(mid,Vector2i(-1,-1),false),mid+" initial region fixture")
		app.world.paused=false;clear_encounters()
		var spot: Dictionary=Mining.nearby_wall(app.world.navigation,app.world.player.cell,mid,app.rules.state.get("mining",{}),app.elapsed)
		expect(not spot.is_empty(),mid+" reachable wall exists")
		preload("res://scripts/edition2011/peach_crafting.gd").sources_panel(app,{"name":"金矿来源","materials":{"ref:132":5}})
		await settle()
		var buttons: Array=app.panel.find_children("*","Button",true,false).filter(func(b):return b.text=="前往废矿寻找矿壁")
		expect(buttons.size()==1,mid+" source action exists")
		if buttons.size()==1:buttons[0].pressed.emit()
		walk()
		expect(app.world.metadata.id==mid and app.world.player.cell==spot.get("cell",Vector2i(-1,-1)),mid+" stays in current mine and reaches wall")
		expect(not app.windows.windows.has("合成材料来源"),mid+" source window closes after navigation")
	var report={"checks":checks,"failures":failures,"movement_frames":frames,"gates":gates,"scope":"six real mining maps, initial map fixtures, source button signals and actual player movement; no physical input or combat"}
	FileAccess.open("res://../artifacts/world-story/mining-sources-regions-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
