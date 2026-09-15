extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var store:=EditionStore.new();store.path="/tmp/novice-gender-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	check(store.open(),"isolated store")
	var rules:=EditionRules.new();rules.store=store
	for job in ["战士","法师","道士"]:
		for gender in ["男","女"]:
			var profile:={"id":job+gender,"name":"新手测试","job":job,"gender":gender}
			check(rules.attach(profile),"attach "+profile.id)
			var robe: String="ref:5" if gender=="女" else "robe"
			check(rules.novice_reward_items(EditionVillage.quest("nv_arrival")).get(robe)==1,"preview matches gender")
			check(rules.novice_quest("nv_arrival"),"accept arrival")
			var before: Dictionary=rules.state.duplicate(true)
			store.db.query("PRAGMA query_only=ON;")
			check(not rules.novice_quest("nv_arrival") and rules.state==before,"failed award preserves all state")
			store.db.query("PRAGMA query_only=OFF;")
			check(rules.novice_quest("nv_arrival"),"receive starter reward")
			check(rules.state.inventory.get(robe)==1 and rules.state.quest_receipts.nv_arrival.items.get(robe)==1,"actual award and receipt match")
			check(EditionRules.ITEMS[robe].gender==gender,"catalog gender correct")
			check(rules.novice_quest("nv_equip"),"accept equipment task")
			check(not EditionVillage.ready(rules.state,"nv_equip"),"equipment still required")
			check(rules.use_item("wood_sword") and rules.use_item(robe),"both starter items wearable")
			check(EditionVillage.ready(rules.state,"nv_equip") and rules.novice_quest("nv_equip"),"second task completes")
			check(rules.attach(profile) and rules.state.equipment.armor==robe and rules.state.quests.nv_equip=="done","completion persists")
			before=rules.state.duplicate(true)
			check(not rules.novice_quest("nv_arrival") and rules.state==before,"reward cannot repeat")
	for container in ["inventory","warehouse"]:
		var profile:={"id":"legacy-"+container,"name":"领错布衣","job":"法师","gender":"女"}
		check(rules.attach(profile),"legacy base")
		var old: Dictionary=rules.state.duplicate(true)
		old.quests={"nv_arrival":"done","nv_equip":"accepted"};old.novice={"chickens":0,"patrol":false};old.erase("novice_clothing_version")
		old.items.append(EditionInventory.make_item("wood_sword",1,"inventory",EditionInventory.free_slot(old.items,"inventory")))
		var item:=EditionInventory.make_item("robe",1,container,EditionInventory.free_slot(old.items,container),67)
		old.items.append(item);EditionInventory.mirror(old)
		check(rules.apply(old,"legacy_wrong_clothing_fixture"),"legacy wrong robe fixture")
		var before: Dictionary=rules.state.duplicate(true)
		store.db.query("PRAGMA query_only=ON;")
		check(not rules.attach(profile),"migration reports failed write")
		check(EditionInventory.find_item(rules.state,item.uid).type=="robe","failed migration leaves original item")
		store.db.query("PRAGMA query_only=OFF;")
		check(rules.attach(profile),"migration retry")
		var fixed:=EditionInventory.find_item(rules.state,item.uid)
		check(fixed.type=="ref:5" and fixed.container==container and int(fixed.slot)==int(item.slot) and int(fixed.durability)==67,"same instance position and durability")
		check(rules.state.gold==before.gold and rules.state.xp==before.xp and rules.state.quests==before.quests and rules.state.items.size()==before.items.size(),"no wealth reward or progress duplication")
		var revision:=int(rules.state.revision)
		check(rules.attach(profile) and int(rules.state.revision)==revision,"migration idempotent")
		if container=="warehouse":check(rules.warehouse("ref:5",false),"corrected warehouse robe withdrawable")
		check(rules.use_item("ref:5"),"old corrected robe wearable")
		check(rules.use_item("wood_sword") and rules.novice_quest("nv_equip"),"legacy character can finish blocked second task")
	store.close()
	var report:={"checks":checks,"failures":failures,"scope":"six job/gender starter reward and second-task flows; old inventory/warehouse correction, write rollback/retry and reload; isolated fixtures, no hardware input"}
	FileAccess.open("res://../artifacts/world-story/novice-gender-reward-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
