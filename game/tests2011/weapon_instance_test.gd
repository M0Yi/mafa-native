extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/weapon-instance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"weapon","name":"武器保管","job":"战士","gender":"男"});app.world.hide()
	var next: Dictionary=app.rules.state.duplicate(true);next.level=100
	var weapon:=EditionInventory.make_item("ref:35",1,"inventory",EditionInventory.free_slot(next.items,"inventory"),37);weapon.blessing=3;weapon.curse=1;next.items.append(weapon);EditionInventory.mirror(next)
	check(app.rules.apply(next,"weapon_attribute_fixture"),"valid weapon attributes saved: "+app.rules.message)
	var uid: String=weapon.uid
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	check(not app.rules.warehouse("ref:35",true) and app.rules.state==before,"failed warehouse write preserves instance")
	app.store.db.query("PRAGMA query_only=OFF;")
	check(app.rules.warehouse("ref:35",true),"deposit weapon")
	var stored:=EditionInventory.find_item(app.rules.state,uid)
	check(stored.get("container")=="warehouse" and stored.get("durability")==37 and stored.get("blessing")==3 and stored.get("curse")==1,"warehouse preserves exact instance attributes")
	app.start_character(app.rules.character.duplicate(true))
	var reloaded:=EditionInventory.find_item(app.rules.state,uid)
	check(reloaded.get("container")=="warehouse" and int(reloaded.get("durability",-1))==37 and int(reloaded.get("blessing",-1))==3 and int(reloaded.get("curse",-1))==1,"database reload preserves warehouse weapon")
	check(app.rules.warehouse("ref:35",false),"withdraw weapon")
	var returned:=EditionInventory.find_item(app.rules.state,uid)
	check(returned.get("container")=="inventory" and returned.get("durability")==37 and returned.get("blessing")==3 and returned.get("curse")==1,"withdraw preserves UID and attributes")
	for field in ["blessing","curse"]:
		for value in [-1,1.5,true,INF,8 if field=="blessing" else 11]:
			var invalid: Dictionary=app.rules.state.duplicate(true);EditionInventory.find_item(invalid,uid)[field]=value
			check(not EditionInventory.validate(invalid),"reject invalid "+field+" "+str(value))
	check(EditionInventory.condition_text(returned).contains("祝福3 / 诅咒1"),"shared tooltip displays attributes")
	var legacy: Dictionary=app.rules.state.duplicate(true);var item:=EditionInventory.find_item(legacy,uid);item.erase("blessing");item.erase("curse")
	check(EditionInventory.validate(legacy),"legacy weapons without attributes remain valid")
	check(app.rules.inventory_action("use",{"uid":uid}),"equip attributed weapon")
	var rating: int=app.rules.attack()
	var limits: Vector2i=app.rules.attack_range()
	check(limits.y==rating and limits.x<limits.y,"weapon damage range retains panel maximum")
	for i in range(30):
		var damage: int=app.rules.roll_melee_damage()
		check(damage>=limits.x and damage<=limits.y and app.rules.attack()==rating,"damage rolls do not randomize equipment requirements")
	var report={"checks":checks,"failures":failures,"scope":"attribute fixture, warehouse rollback/reload, equip and rules damage rolls; oil use and actual hit timing not verified"}
	FileAccess.open("res://../artifacts/world-story/weapon-instance-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
