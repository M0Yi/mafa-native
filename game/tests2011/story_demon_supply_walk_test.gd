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
	app.store.path="/tmp/demon-supply-walk-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"demonwalk","name":"魔龙补给","gender":"男","job":"战士"});app.world.hide()
	expect(app.enter_map("6",Vector2i(125,158)),"single initial position near demon veteran")
	app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_demon_supplies="done";next.gold=1000
	expect(app.rules.apply(next,"demon_prerequisite_budget_fixture") and app.save_world(),"save prerequisite and demon location")
	var q: Dictionary=EditionRules.Story.quest("story_demon_storage")
	expect(app.rules.story_action(q.id,"accept",q.start_npc,"6",app.world.player.cell),"accept storage task at veteran")
	var supply_done:=false
	var stops: Array=[]
	for id in [157,160,162]:
		var npc: Dictionary=app.rules.story_npc("server:merchant:"+str(id));var target:=Vector2i(npc.cell[0],npc.cell[1])
		expect(app.world.approach(target),"supplier route available "+npc.name)
		for frame in range(3600):
			if app.world.player.route.is_empty() and app.world.player.progress>=1:break
			app.world.player.update(1.0/60,Vector2i.ZERO,false)
		expect(app.world.player.cell.distance_to(target)<2,"continuous walk reaches supplier neighbor "+npc.name)
		expect(app.world.player.cell!=target,"NPC tile stays occupied")
		if not supply_done:
			expect(app.save_world(),"persist actual walked supplier position")
			if id==157:
				var count: int=app.rules.state.inventory.get("ref:96",0);var gold: int=app.rules.state.gold
				expect(app.rules.reference_trade(npc.id,"ref:96",true,app.elapsed),"purchase at reached demon pharmacy")
				expect(app.rules.state.inventory.get("ref:96",0)==count+1 and app.rules.state.gold==gold-int(EditionRules.ITEMS["ref:96"].price),"one potion at actual price")
			elif id==160:
				app.show_reference_npc(npc);await settle()
				var open: Button=null
				for button in app.panel.navigation_buttons(app.panel.body):
					if button.text=="仓库":open=button;break
				expect(open!=null,"reconstructed keeper offers warehouse button")
				if open!=null:
					var parent: Node=open.get_parent()
					while parent!=null:
						if parent is ScrollContainer:parent.ensure_control_visible(open)
						parent=parent.get_parent()
					await settle()
					var e:=InputEventMouseButton.new();e.position=open.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
					e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
				expect(app.windows.windows.has("个人仓库"),"mouse opens actual personal warehouse")
				app.windows.close_all()
				var count: int=app.rules.state.inventory.get("ref:96",0)
				expect(app.rules.warehouse("ref:96",true),"deposit at reached warehouse")
				expect(not EditionRules.Story.ready(app.rules.state,q),"deposit alone not ready")
				expect(app.rules.warehouse("ref:96",false),"withdraw after deposit")
				expect(EditionRules.Story.ready(app.rules.state,q) and app.rules.state.inventory.get("ref:96",0)==count,"withdraw completes practice without losing potion")
			elif id==162:
				expect(app.rules.story_action(q.id,"submit",q.end_npc,"6",app.world.player.cell),"walked back to veteran and submitted")
				expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","storage quest completion persisted")
				supply_done=true
		stops.append({"npc":npc.id,"cell":[app.world.player.cell.x,app.world.player.cell.y]})
	var report:={"checks":checks,"failures":failures,"stops":stops,"scope":"one initial arrival fixture, continuous walking among demon suppliers and veteran without intermediate reset; real NPC collision and purchase/deposit/withdraw/delivery rules; prerequisite and budget fixtures, other entities stationary, warehouse opening via viewport mouse; no combat or physical controller input"}
	FileAccess.open("res://../artifacts/world-story/demon-supply-walk-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
