extends SceneTree
func _initialize() -> void:
	var store:=EditionStore.new()
	store.path="/tmp/mafa-quickbar-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	assert(store.open())
	var rules:=EditionRules.new();rules.store=store
	var profile:={"id":"quickbar-check","name":"快捷栏检查","job":"战士","gender":"女"}
	assert(rules.attach(profile))
	var original: Dictionary=JSON.parse_string(JSON.stringify(rules.state))
	for malformed in [null,{},"potion",[],["potion"],["potion","mana","","","",12],["unknown-item","","","","",""]]:
		var corrupt:=original.duplicate(true);corrupt.quickbar=malformed
		assert(not EditionInventory.validate(corrupt))
		assert(store.db.query_with_bindings("UPDATE worlds SET state=? WHERE character_id=?;",[JSON.stringify(corrupt),profile.id]))
		var before:=store.load_world(profile.id)
		assert(not rules.attach(profile))
		assert(store.load_world(profile.id)==before)
	assert(store.commit(profile.id,original,"test_restore"))
	assert(rules.attach(profile) and rules.state.quickbar==original.quickbar)
	assert(rules.state.items==original.items and rules.state.gold==original.gold)
	print("PASS: malformed quickbar rejected on load without overwriting save; valid bindings and items preserved")
	var legacy:=rules.state.duplicate(true);legacy.erase("quickbar")
	assert(store.commit(profile.id,legacy,"test_legacy"))
	assert(rules.attach(profile) and not rules.state.has("quickbar"))
	assert(EditionInventory.quick_bindings(rules.state)==["potion","mana","","","",""])
	var potion: Dictionary=rules.state.items.filter(func(i):return i.type=="potion" and i.container=="inventory")[0]
	var holdings: Array=rules.state.items.duplicate(true)
	assert(store.db.query("PRAGMA query_only=ON;"))
	assert(not rules.inventory_action("bind",{"uid":potion.uid,"slot":5}))
	assert(not rules.state.has("quickbar") and rules.state.items==holdings)
	assert(store.db.query("PRAGMA query_only=OFF;"))
	assert(rules.inventory_action("bind",{"uid":potion.uid,"slot":5}))
	assert(rules.attach(profile))
	assert(rules.state.quickbar==["potion","mana","","","","potion"] and rules.state.items==holdings)
	print("PASS: legacy missing quickbar defaults agree; binding rollback and restart preserve inventory")
	var path:=store.path;store.close()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
