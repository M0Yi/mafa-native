extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/ore-sale-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for ore_type in preload("res://scripts/edition2011/mining.gd").ORES:
		app.start_character({"id":"ore-sale-"+ore_type,"name":"矿石出售","job":"战士","gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.items=[]
		var low:=EditionInventory.make_item(ore_type,2,"inventory",0);low.purity=3
		var high:=EditionInventory.make_item(ore_type,1,"inventory",1);high.purity=20
		var unknown:=EditionInventory.make_item(ore_type,1,"warehouse",0)
		next.items=[low,high,unknown];EditionInventory.mirror(next)
		expect(app.rules.apply(next,"ore_sale_fixture"),"prepare different grades")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.inventory_action("move",{"uid":high.uid,"container":"warehouse","slot":1}) and app.rules.state==before,"failed storage preserves selected grade "+ore_type)
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.inventory_action("move",{"uid":high.uid,"container":"warehouse","slot":1}),"store selected high grade "+ore_type)
		expect(EditionInventory.find_item(app.rules.state,high.uid).purity==20 and EditionInventory.find_item(app.rules.state,unknown.uid).get("purity",-1)==-1,"warehouse keeps unknown and high grade separate")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(EditionInventory.find_item(app.rules.state,high.uid).container=="warehouse","stored ore survives reload")
		expect(app.rules.inventory_action("move",{"uid":high.uid,"container":"inventory","slot":1}),"withdraw same instance")
		expect(EditionInventory.find_item(app.rules.state,high.uid).purity==20,"withdraw retains pure grade")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.reference_trade("server:merchant:56",ore_type,false,0) and app.rules.state==before,"ambiguous ore sale rejected")
		expect(not app.rules.reference_trade("server:merchant:56",ore_type,false,0,unknown.uid) and app.rules.state==before,"warehouse instance cannot be sold")
		expect(not app.rules.reference_trade("server:merchant:56","potion",false,0,low.uid) and app.rules.state==before,"wrong type cannot select gold ore")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.reference_trade("server:merchant:56",ore_type,false,0,low.uid) and app.rules.state==before,"failed sale preserves all grades and money")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.reference_trade("server:merchant:56",ore_type,false,0,low.uid),"sell selected low grade")
		expect(EditionInventory.find_item(app.rules.state,low.uid).count==1 and EditionInventory.find_item(app.rules.state,high.uid).purity==20,"sell one low grade and retain high grade")
		expect(app.rules.state.gold==before.gold+maxi(1,int(EditionRules.ITEMS[ore_type].price)/2),"sale uses existing price once")
		expect(app.rules.reference_trade("server:merchant:56",ore_type,false,0,low.uid),"sell remaining selected stack")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.reference_trade("server:merchant:56",ore_type,false,0,low.uid) and app.rules.state==before,"stale UID cannot consume another grade")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(EditionInventory.find_item(app.rules.state,low.uid).is_empty() and EditionInventory.find_item(app.rules.state,high.uid).purity==20 and app.rules.state.gold==before.gold,"selected sale and retained ore persist")
	var report:={"checks":checks,"failures":failures,"scope":"all four mining ore types: instance storage, withdrawal, sale, readonly rollback and reload; prepared grades; no physical UI"}
	FileAccess.open("res://../artifacts/world-story/ore-sale-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
