extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:
	var store:=EditionStore.new();store.path=OS.get_environment("TMPDIR")+"mafa-items-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	check(store.open(),"open isolated database")
	var rules:=EditionRules.new();rules.store=store
	check(rules.attach({"id":"items-test","name":"测试","job":"战士","gender":"男"}),"create and migrate")
	check(EditionInventory.validate(rules.state),"valid instance IDs and slots")
	var potion: Dictionary=rules.state.items.filter(func(i):return i.type=="potion")[0]
	var original_uid: String=potion.uid
	check(rules.inventory_action("split",{"uid":original_uid,"count":2}),"split stack")
	check(rules.state.inventory.potion==5,"split preserves total")
	check(EditionInventory.find_item(rules.state,original_uid).count==3,"source identity preserved")
	var revision: int=rules.state.revision
	check(not rules.inventory_action("split",{"uid":original_uid,"count":999}),"invalid split rejected")
	check(rules.state.revision==revision and rules.state.inventory.potion==5,"failure has no partial write")
	check(rules.inventory_action("move",{"uid":original_uid,"container":"warehouse","slot":0}),"deposit whole stack")
	check(rules.state.warehouse.potion==3 and rules.state.inventory.potion==2,"deposit balances")
	check(rules.inventory_action("move",{"uid":original_uid,"container":"inventory","slot":0}),"withdraw preserving UID")
	var funded: Dictionary=rules.state.duplicate(true)
	funded.gold=int(EditionRules.ITEMS.sword.price)+500
	funded.level=maxi(int(funded.level),int(EditionRules.ITEMS.sword.get("need_level",0)))
	check(rules.apply(funded,"inventory_test_budget"),"fund catalog equipment price")
	check(rules.shop("sword",1),"buy equipment: "+rules.message)
	check(rules.state.gold==500,"purchase deducts current catalog price")
	var swords: Array=rules.state.items.filter(func(i):return i.type=="sword")
	if swords.is_empty():
		store.close();print(JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
	var sword: Dictionary=swords[0]
	check(rules.inventory_action("use",{"uid":sword.uid}),"equip exact instance")
	check(EditionInventory.find_item(rules.state,sword.uid).container=="equipment","equipment identity survives")
	check(not rules.inventory_action("move",{"uid":original_uid,"container":"equipment","slot":0}),"potion cannot replace weapon")
	check(rules.inventory_action("move",{"uid":sword.uid,"container":"inventory","slot":EditionInventory.free_slot(rules.state.items,"inventory")}),"unequip exact instance")
	check(rules.inventory_action("sort",{}),"sort instances")
	check(EditionInventory.find_item(rules.state,sword.uid).durability==100,"sort preserves durability")
	var snapshot:=rules.state.duplicate(true)
	check(rules.attach({"id":"items-test","name":"测试","job":"战士","gender":"男"}),"load migrated save")
	check(JSON.parse_string(JSON.stringify(rules.state)).recursive_equal(JSON.parse_string(JSON.stringify(snapshot)),10),"save round-trip preserves items")
	var corrupted:=rules.state.duplicate(true);corrupted.items.append(corrupted.items[0].duplicate())
	check(not EditionInventory.validate(corrupted),"duplicate UID and slot rejected")
	var legacy:=rules.new_world({},"classic");legacy.gold=789;legacy.inventory={"sword":2};legacy.equipment={"armor":"robe"};legacy.durability={"sword":63,"robe":47}
	EditionInventory.migrate(legacy)
	check(EditionInventory.validate(legacy) and legacy.items.size()==3,"legacy equipment and duplicates retained")
	check(legacy.items[0].uid!=legacy.items[1].uid and legacy.gold==789,"migration unique IDs and wealth preserved")
	store.close()
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
