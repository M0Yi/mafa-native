extends SceneTree
var app
var failures: Array=[]
var checks:=0
var heard: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-interaction-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"interaction","name":"交互检查","job":"战士","gender":"男"})
	app.sound_started.connect(func(id):heard.append(id))
	var old: Dictionary=app.rules.state.duplicate(true);old.items=[]
	for type in EditionRules.ITEMS:old.items.append(EditionInventory.make_item(type,1 if EditionRules.ITEMS[type].has("slot") else 3,"inventory",old.items.size()))
	EditionInventory.mirror(old);expect(app.rules.apply(old,"fixture"),"isolated item fixture")
	var expected:={"potion":108,"mana":108,"ore":118,"sword":111,"robe":112,"wood_sword":111,"chicken_meat":118,"helmet":116,"ring":113,"bracelet":117,"boots":118,"charm":118,"poison":118}
	expect(EditionItemAudio.data().runtime.size()==EditionRules.ITEMS.size(),"every current item has an explicit audio record")
	for type in EditionRules.ITEMS:
		expect(EditionRules.item_sound(type)==expected[type],"reference category for "+type)
		for event in EditionItemAudio.data().runtime[type].events:
			var id:=EditionItemAudio.sound(type,event)
			if id>=0:expect(app.resources.sound_id(id)!=null,"event WAV readable "+type+":"+event)
		var item: Dictionary=app.rules.state.items.filter(func(i):return i.type==type and i.container=="inventory")[0]
		heard.clear()
		if EditionRules.ITEMS[type].has("slot"):
			expect(app.rules.use_item(type) and heard==[expected[type]],"equip commits one category sound "+type)
			heard.clear()
			expect(app.rules.inventory_action("move",{"uid":item.uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")}) and heard==[expected[type]],"unequip commits one category sound "+type)
		elif type in ["potion","mana"]:
			expect(app.rules.use_item(type) and heard==[108],"potion use uses StdMode 0 sound once")
		else:expect(not app.rules.use_item(type) and heard.is_empty(),"unsupported material use has no success sound")
	var potion: Dictionary=app.rules.state.items.filter(func(i):return i.type=="potion")[0]
	heard.clear();expect(not app.rules.inventory_action("move",{"uid":potion.uid,"container":"equipment","slot":0}) and heard.is_empty(),"invalid equipment drop has no success sound")
	heard.clear();app.classic_hud.use_quick(1);expect(heard==[108],"quick slot shares committed use event without duplicate sound")
	var npc: Dictionary=EditionVillage.data().npcs[0];var occupied:=Vector2i(npc.cell[0],npc.cell[1])
	expect(not app.world.navigation.walkable(occupied) and not app.world.player.go_to(occupied),"NPC cell blocks direct path")
	expect(app.world.approach(occupied),"NPC approach finds reachable neighbor")
	for i in range(240):app.world.update_world(1.0/60,Vector2(1280,800),false)
	expect(app.world.player.cell!=occupied and (app.world.player.cell-occupied).length()<2,"player stops next to NPC")
	var blocked:=false
	for d in ClassicNavigation.DIRECTIONS:
		if app.world.navigation.walkable(occupied+d):
			app.world.player.reset(occupied+d);app.world.player.update(1.0/60,-d,true);blocked=app.world.player.cell!=occupied and app.world.player.progress==1
			expect(blocked,"manual run cannot enter NPC cell")
	app.enter_map("0",occupied);expect(app.world.player.cell!=occupied and app.world.navigation.walkable(app.world.player.cell),"old overlapping save relocated to free tile")
	for i in range(600):app.world.update_world(1.0/60,Vector2(1280,800),false)
	for entity in app.world.entities:
		if entity.kind in ["traveler","hero","monster"]:expect(app.world.navigation.walkable(Vector2i(entity.cell[0],entity.cell[1])),"AI avoids NPC occupancy")
	for density in [1.0,2.0]:
		app.world.display_density=density
		var monster: Dictionary=app.world.entities.filter(func(e):return e.kind=="monster")[0]
		var label: Dictionary=app.world.labels.layout(monster)
		expect(label.font_size/density==16 and label.health_rect.size/density==Vector2(58,5),"name and health sizes are stable in display points")
	expect(app.resources.errors.is_empty(),"no missing resources")
	var report:={"checks":checks,"failures":failures};print(JSON.stringify(report));FileAccess.open("res://../artifacts/interaction-0.9.1/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
