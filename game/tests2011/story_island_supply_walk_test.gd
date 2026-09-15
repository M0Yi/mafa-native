extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/island-supply-walk-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"islandwalk","name":"海岛补给","gender":"男","job":"战士"});app.world.hide()
	expect(app.enter_map("5",Vector2i(139,327)),"single initial position near island veteran")
	app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_island_shops="done";next.gold=1000
	expect(app.rules.apply(next,"island_prerequisite_budget_fixture") and app.save_world(),"save prerequisite and island location")
	var q: Dictionary=EditionRules.Story.quest("story_island_storage")
	expect(app.rules.story_action(q.id,"accept",q.start_npc,"5",app.world.player.cell),"accept storage task at veteran")
	var supply_done:=false
	var stops: Array=[]
	for id in [146,149,153,145,151,153,147,150,153]:
		var npc: Dictionary=app.rules.story_npc("server:merchant:"+str(id));var target:=Vector2i(npc.cell[0],npc.cell[1])
		expect(app.world.approach(target),"supplier route available "+npc.name)
		for frame in range(3600):
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
		expect(app.world.player.cell.distance_to(target)<2,"continuous walk reaches supplier neighbor "+npc.name)
		expect(app.world.player.cell!=target,"NPC tile stays occupied")
		if not supply_done:
			expect(app.save_world(),"persist actual walked supplier position")
			if id==146:
				var count: int=app.rules.state.inventory.get("potion",0);var gold: int=app.rules.state.gold
				expect(app.rules.reference_trade(npc.id,"potion",true,app.elapsed),"purchase at reached island pharmacy")
				expect(app.rules.state.inventory.get("potion",0)==count+1 and app.rules.state.gold==gold-int(EditionRules.ITEMS.potion.price),"one potion at actual price")
			elif id==149:
				var count: int=app.rules.state.inventory.get("potion",0)
				expect(app.rules.warehouse("potion",true),"deposit at reached warehouse")
				expect(not EditionRules.Story.ready(app.rules.state,q),"deposit alone not ready")
				expect(app.rules.warehouse("potion",false),"withdraw after deposit")
				expect(EditionRules.Story.ready(app.rules.state,q) and app.rules.state.inventory.get("potion",0)==count,"withdraw completes practice without losing potion")
			elif id==153:
				expect(app.rules.story_action(q.id,"submit",q.end_npc,"5",app.world.player.cell),"walked back to veteran and submitted")
				expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","storage quest completion persisted")
				supply_done=true
		stops.append({"npc":npc.id,"cell":[app.world.player.cell.x,app.world.player.cell.y]})
	var report:={"checks":checks,"failures":failures,"stops":stops,"scope":"one initial arrival fixture, continuous walking among island suppliers and veteran without intermediate reset; real NPC collision and purchase/deposit/withdraw/delivery rules; prerequisite and budget fixtures, other entities stationary, no combat or physical input"}
	FileAccess.open("res://../artifacts/world-story/island-supply-walk-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
