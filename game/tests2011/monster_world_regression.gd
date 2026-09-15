extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(3):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-regional-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	expect(app.mode!="error","application initializes regional resources")
	if app.mode=="error":printerr(app.resources.errors);quit(1);return
	app.start_character({"id":"regional","name":"区域核查","gender":"男","job":"战士"});app.world.hide()
	var data:=EditionRegion.data()
	expect(data.npcs.size()==202 and data.spawns.size()==3402 and data.items.size()==686,"all source records retained")
	for z in data.safe_zones:
		if not z.enabled:continue
		var p:=Vector2i(z.cell[0],z.cell[1]);var radius:=int(z.radius)
		expect(EditionRegion.safe(z.map,p) and EditionRegion.safe(z.map,p+Vector2i(radius,radius)),"square safe-zone edge "+z.map)
		expect(not EditionRegion.safe(z.map,p+Vector2i(radius+1,radius+1)),"outside reference safety "+z.map)
	expect(EditionRegion.destination("3")==Vector2i(330,330),"province default uses reference safety center")
	var runtime: Dictionary={};var maps:=0
	for m in app.resources.maps:
		expect(app.enter_map(m.id),"map with regional NPCs loads "+m.id)
		var npcs: Array=app.world.entities.filter(func(e):return e.kind=="npc")
		for n in npcs:
			if n.get("fixed_reference_position",false):
				expect(n.cell==[n.raw.x,n.raw.y],"NPC retains reference coordinate "+n.id)
				expect(not app.world.navigation.walkable(Vector2i(n.cell[0],n.cell[1])),"NPC collision "+n.id)
		expect(app.world.navigation.mobile(app.world.player.cell),"spawn can physically move "+m.id)
		for route in app.resources.connections.by_map[m.id]:
			expect(app.world.navigation.mobile(Vector2i(route.cell[0],route.cell[1])),"exit can physically move "+str(route.id))
		for arrival in app.resources.connections.landing_cells.get(m.id,[]):
			expect(app.world.navigation.mobile(arrival),"arrival can physically move "+m.id+str(arrival))
		var exits: Array=app.resources.connections.routes
		expect(exits.any(func(r):return not app.world.navigation.path(app.world.player.cell,Vector2i(r.cell[0],r.cell[1])).is_empty()),"regional spawn reaches exit "+m.id)
		for monster in app.world.entities:
			if monster.kind!="monster":continue
			expect(monster.has("spawn_id") and monster.name==data.spawns[monster.spawn_index].name,"monster from this map's source table")
			expect(not EditionRegion.safe(m.id,Vector2i(monster.cell[0],monster.cell[1])),"spawn outside safe zone")
			if monster.name=="弓箭守卫":expect(monster.passive and monster.stationary,"guard does not hunt players or patrol")
			if int(monster.profile.actions.walk.count)==0:expect(monster.stationary,"no-walk creature stays rooted")
		runtime[m.id]={"spawn":[app.world.player.cell.x,app.world.player.cell.y],"npcs":npcs.map(func(n):return n.cell)}
		maps+=1
		if maps%100==0:print("Regional maps ",maps);await process_frame
	app.enter_map("0",Vector2i(289,615));app.world.paused=false
	var npc: Dictionary=app.world.entities.filter(func(n):return n.id=="server:npc:6")[0]
	expect(Vector2i(npc.cell[0],npc.cell[1])==Vector2i(287,614) and int(npc.frame)==900,"village teleporter has source position and 60-frame appearance stride")
	var route: Dictionary=EditionRegion.teleports(npc.id).filter(func(r):return r.target_map=="3")[0]
	expect(Vector2i(route.target_cell[0],route.target_cell[1])==Vector2i(333,333) and int(route.cost)==2000,"NPC landing differs from safety center and retains fee")
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=10000;next.level=30;expect(app.rules.apply(next,"fixture"),"funded isolated fixture")
	app.world.player.reset(Vector2i(300,630));var gold:=int(app.rules.state.gold)
	expect(not app.teleport_with_npc(npc,route) and app.rules.state.gold==gold,"remote teleport refused without charge")
	app.world.player.reset(Vector2i(289,615));app.world.paused=true
	expect(not app.teleport_with_npc(npc,route),"paused teleport refused");app.world.paused=false
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.teleport_with_npc(npc,route) and app.rules.state.gold==gold and app.world.metadata.id=="0","failed write rolls back teleport and gold")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.teleport_with_npc(npc,route),"nearby teleporter succeeds")
	expect(app.world.metadata.id=="3" and app.world.player.cell==Vector2i(333,333) and app.rules.state.gold==gold-2000,"exact paid landing commits once")
	expect(not app.teleport_with_npc(npc,route) and app.rules.state.gold==gold-2000,"stale NPC submission cannot double charge")
	var stored: Dictionary=app.store.load_world(app.rules.character.id)
	expect(stored.map=="3" and Vector2i(stored.cell[0],stored.cell[1])==Vector2i(333,333) and stored.gold==gold-2000,"teleport location and price stored atomically")
	app.world.player.reset(Vector2i(330,330));var hp=app.rules.state.hp;app.world.monster_hit.emit({},999)
	expect(app.rules.state.hp==hp,"safe-zone monster damage rejected");app.attack_target();expect(app.pending_attack.is_empty(),"safe-zone player attack rejected")
	var smith: Dictionary=data.npcs.filter(func(n):return n.map=="0159" and n.name=="铁匠铺老板")[0]
	var tailor: Dictionary=data.npcs.filter(func(n):return n.map=="0149" and n.name=="张家布店老板")[0]
	expect(EditionRegion.shop(smith.id).goods.map(func(g):return g.name)!=EditionRegion.shop(tailor.id).goods.map(func(g):return g.name),"blacksmith and tailor have distinct source goods")
	gold=int(app.rules.state.gold);var inventory: Dictionary=app.rules.state.inventory.duplicate(true)
	expect(not app.rules.reference_trade(tailor.id,"wood_sword",true,20) and app.rules.state.gold==gold and app.rules.state.inventory==inventory,"wrong shop cannot sell weapon")
	var price:=int(EditionRules.ITEMS.wood_sword.price)*int(EditionRegion.shop(smith.id).price_rate)/100
	expect(app.rules.reference_trade(smith.id,"wood_sword",true,20) and int(app.rules.state.gold)==gold-price,"source shop price is charged")
	var key: String=smith.id+":wood_sword";var stock: Dictionary=app.rules.state.merchant_stock[key]
	expect(int(stock.count)==49,"per-NPC stock decremented")
	var changed: Dictionary=app.rules.state.duplicate(true);changed.merchant_stock[key].count=0;app.rules.apply(changed,"stock_fixture")
	gold=int(app.rules.state.gold);expect(not app.rules.reference_trade(smith.id,"wood_sword",true,21) and app.rules.state.gold==gold,"empty stock doesn't charge")
	expect(app.rules.reference_trade(smith.id,"wood_sword",true,1000),"reference stock timer replenishes")
	for type in EditionRules.ITEMS:
		var spec: Dictionary=EditionRules.ITEMS[type]
		if not spec.has("reference_index"):continue
		expect(int(spec.icon)==int(spec.raw.looks) and int(spec.price)==int(spec.raw.price),"source item icon and base price "+type)
		expect(EditionItemAudio.sound(type,"select")>=0,"item category audio exists "+type)
	app.enter_map("0",Vector2i(300,600));app.world.player_alive=true
	var generated: Array=app.world.entities.filter(func(e):return e.kind=="monster")
	expect(not generated.is_empty(),"regional monsters materialize near player")
	if not generated.is_empty():
		var monster: Dictionary=generated[0];next=app.rules.state.duplicate(true);next.gold=100000;next.level=99;app.rules.apply(next,"kill_fixture")
		expect(app.rules.reward_kill("regional-kill",monster.species,monster,1100),"reference kill settles")
		gold=int(app.rules.state.gold)
		expect(not app.rules.reward_kill("regional-kill-retry",monster.species,monster,1100) and app.rules.state.gold==gold,"dead spawn cannot grant repeated rewards")
		app.region.remembered.clear();app.enter_map("3");app.enter_map("0",Vector2i(monster.origin[0],monster.origin[1]))
		expect(not app.world.entities.any(func(e):return e.id==monster.id),"travel cannot respawn killed monster before deadline")
	expect(app.resources.errors.is_empty(),"no missing referenced runtime frames or sounds")
	var report:={"checks":checks,"failures":failures,"maps":maps,"runtime":runtime,"resource_errors":app.resources.errors}
	FileAccess.open("res://../artifacts/gameplay-0.10.0/world-regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"checks":checks,"failures":failures,"maps":maps,"resource_errors":app.resources.errors}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
