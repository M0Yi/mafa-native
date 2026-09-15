extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var store:=EditionStore.new();store.path=OS.get_environment("TMPDIR")+"mafa-novice-test-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	check(store.open(),"isolated database")
	var rules:=EditionRules.new();rules.store=store
	var profile:={"id":"novice-test","name":"新手测试","job":"战士","gender":"男"}
	check(rules.attach(profile),"new world")
	check(rules.state.cell==[289,618],"new characters spawn in border village")
	check(not rules.novice_quest("nv_hunt"),"quest prerequisite")
	check(rules.novice_quest("nv_arrival"),"accept arrival")
	check(rules.novice_quest("nv_arrival"),"receive starting gear")
	var before:=JSON.stringify(rules.state)
	check(not rules.novice_quest("nv_arrival") and JSON.stringify(rules.state)==before,"cannot claim starting gear twice")
	check(rules.novice_quest("nv_equip"),"accept equipment quest")
	check(not rules.novice_quest("nv_equip"),"cannot report equipment before wearing it")
	check(rules.use_item("wood_sword") and rules.use_item("robe"),"wear reward instances")
	check(rules.attack()==10 and rules.defense()==3,"equipment affects combat stats")
	check(rules.novice_quest("nv_equip"),"complete equipment quest")
	check(rules.novice_quest("nv_hunt"),"accept hunt")
	for i in range(3):check(rules.reward_kill("chicken-"+str(i),"village_chicken"),"chicken reward "+str(i))
	before=JSON.stringify(rules.state)
	check(not rules.reward_kill("chicken-2","village_chicken") and JSON.stringify(rules.state)==before,"kill event idempotent")
	check(rules.state.novice.chickens==3 and rules.state.inventory.chicken_meat==3,"hunt tracks accepted kills and meat")
	check(rules.novice_quest("nv_hunt"),"deliver meat")
	check(not rules.state.inventory.has("chicken_meat"),"meat consumed in same reward transaction")
	check(rules.novice_quest("nv_patrol"),"accept patrol")
	check(not rules.novice_patrol("1",EditionVillage.PATROL),"same coordinates wrong map rejected")
	check(not rules.novice_patrol("0",EditionVillage.SPAWN),"must reach patrol")
	check(rules.novice_patrol("0",EditionVillage.PATROL),"reach patrol")
	check(not rules.novice_patrol("0",EditionVillage.PATROL),"patrol event fires once")
	check(rules.novice_quest("nv_patrol"),"final reward")
	check(rules.state.inventory.sword==1 and EditionVillage.current(rules.state).is_empty(),"all four quests complete")
	before=JSON.stringify(rules.state)
	check(rules.attach(profile) and JSON.parse_string(before)==JSON.parse_string(JSON.stringify(rules.state)),"quests and equipment survive reload")
	check(rules.shop("ring",2),"buy two identical rings")
	check(rules.use_item("ring") and rules.use_item("ring"),"equip both hands")
	check(rules.state.equipment.has("ring_left") and rules.state.equipment.has("ring_right"),"distinct ring slots")
	var next:=rules.state.duplicate(true)
	var rings: Array=next.items.filter(func(i):return i.type=="ring")
	rings[0].durability=70;rings[1].durability=90;EditionInventory.mirror(next)
	check(rules.apply(next,"test_wear"),"independent durability persisted")
	var gold:=int(rules.state.gold)
	check(rules.repair() and int(rules.state.gold)==gold-40,"repair charges every individual ring")
	# Full bag rollback: use weight-one equipment to fill all 48 slots.
	var full:=EditionRules.new();full.store=store;check(full.attach({"id":"full-bag","name":"满包","job":"战士","gender":"女"}),"full bag profile")
	check(full.novice_quest("nv_arrival"),"full bag accept")
	next=full.state.duplicate(true);next.items=[]
	for i in range(48):next.items.append(EditionInventory.make_item("ring",1,"inventory",i))
	EditionInventory.mirror(next);check(full.apply(next,"fill_fixture"),"48 occupied slots")
	before=JSON.stringify(full.state)
	check(not full.novice_quest("nv_arrival") and JSON.stringify(full.state)==before,"full bag does not consume quest or award partial items")
	check(not full.reward_kill("full-kill","village_chicken") and JSON.stringify(full.state)==before,"full bag kill reward rolls back")
	check(not full.inventory_action("move",{"uid":full.state.items[0].uid,"container":"equipment","slot":0}),"ring cannot drop on weapon")
	# An older writer must not discard a concurrently saved quest.
	next=full.state.duplicate(true);check(store.commit(full.character.id,next,"external_fixture"),"external revision")
	check(not full.recover_at_village() and JSON.stringify(full.state)==before,"stale save keeps memory and rewards unchanged")
	var res:=EditionResources.new();check(res.initialize(),"resource catalog")
	var world:=EditionWorld.new();world.resources=res;root.add_child(world)
	check(world.enter_map("0",EditionVillage.SPAWN),"original village map loads")
	var destinations: Array=[EditionVillage.PATROL]
	for e in EditionVillage.entities():destinations.append(Vector2i(e.cell[0],e.cell[1]))
	for cell in destinations:
		var route:=world.navigation.path(EditionVillage.SPAWN,cell)
		check(not route.is_empty(),"reachable village destination "+str(cell))
		var safe:=true
		for i in range(1,route.size()):safe=safe and world.navigation.can_step(route[i-1],route[i])
		check(safe,"route obeys walls and diagonal corners "+str(cell))
	for direction in range(8):
		for frame in range(4):check(not res.frame("mon17",direction*10+frame).is_empty(),"chicken idle frame")
		for frame in range(2):check(not res.frame("mon17",240+direction*2+frame).is_empty(),"chicken hurt frame")
		for frame in range(10):check(not res.frame("mon17",260+direction*10+frame).is_empty(),"chicken death frame")
		check(not res.frame("mon17",340+direction).is_empty(),"chicken corpse frame")
	for id in [1,2,51,52,57,105,106,107,111,112,113,114,116,118,1804,1805]:check(res.sound_id(id)!=null,"sound "+str(id))
	for id in [30,36,60,80,100]:check(not res.frame("stateitem",id).is_empty(),"paperdoll frame "+str(id))
	check(res.errors.is_empty(),"no missing referenced assets")
	world.queue_free();store.close()
	var result:={"checks":checks,"failures":failures}
	FileAccess.open("res://../artifacts/novice-village/rules-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
