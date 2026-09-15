extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var store:=EditionStore.new();store.path="/tmp/novice-handoff-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	check(store.open(),"isolated database")
	var rules:=EditionRules.new();rules.store=store
	var profile:={"id":"handoff","name":"村外来信","job":"战士","gender":"男"}
	check(rules.attach(profile),"new character")
	var skills: Dictionary=rules.state.skills.duplicate(true)
	for id in ["nv_arrival","nv_equip","nv_hunt","nv_patrol"]:
		check(rules.novice_quest(id),"accept "+id)
		if id=="nv_equip":check(rules.use_item("wood_sword") and rules.use_item("robe"),"wear starter equipment")
		if id=="nv_hunt":
			for i in range(3):check(rules.reward_kill("chicken-"+str(i),"village_chicken"),"prepared kill event")
			check(rules.state.inventory.get("chicken_meat",0)==0,"kill drops meat on ground, not in bag")
			check(not rules.novice_quest(id),"kill count alone cannot complete delivery")
			var drops: Array=rules.state.ground_loot.duplicate(true)
			for loot in drops:
				if loot.type=="chicken_meat":check(rules.pickup(loot.uid,"0",EditionVillage.SPAWN),"explicit meat pickup")
			check(rules.state.inventory.get("chicken_meat",0)==3,"three meat collected")
		if id=="nv_patrol":check(rules.novice_patrol("0",EditionVillage.PATROL),"prepared arrival event")
		var before: Dictionary=rules.state.duplicate(true)
		store.db.query("PRAGMA query_only=ON;")
		check(not rules.novice_quest(id) and rules.state==before and not "新委托：" in rules.message,"failed delivery has no unlock or state changes")
		store.db.query("PRAGMA query_only=OFF;")
		check(rules.novice_quest(id),"complete "+id)
		var successor: String={"nv_arrival":"整装出发","nv_equip":"村外的鸡群","nv_hunt":"探访村外小路","nv_patrol":"带给城里的口信"}[id]
		check(successor in rules.message and "找边界村长" in rules.message,"delivery announces correct successor and giver")
	check(not rules.state.quests.has("story_letter"),"letter not auto-accepted")
	check(rules.state.skills==skills,"newbie rewards do not teach skills")
	check(rules.attach(profile) and rules.state.quests.nv_patrol=="done","completed patrol survives reload")
	check(EditionRules.Story.available(rules.state,EditionRules.Story.quest("story_letter")),"letter available after reload")
	var report:={"checks":checks,"failures":failures,"scope":"rule-level four novice tasks, explicit ground pickup, rollback and reload; kill/patrol events supplied by test, no natural combat, movement or UI"}
	FileAccess.open("res://../artifacts/world-story/novice-handoff-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));store.close();quit(0 if failures.is_empty() else 1)
