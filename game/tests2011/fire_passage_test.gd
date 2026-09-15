extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/fire-passage-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"passage","name":"侧门凭证","gender":"男","job":"战士"});app.world.paused=false
	var route: Dictionary={}
	for row in app.resources.connections.by_map["d2082"]:
		if row.map=="d2082" and row.target_map==EditionFireDragon.MAP:route=row;break
	expect(not route.is_empty(),"actual Lei Yan side entrance registered")
	if route.is_empty():quit(1);return
	var door:=Vector2i(route.cell[0],route.cell[1])
	expect(app.enter_map(route.map,door),"load actual side doorway")
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.cross_passage(route) and app.world.metadata.id==route.map and app.rules.state==before,"no permit cannot enter via walking door")
	expect("凭证" in app.pending_message,"door explains entry requirement")
	app.enter_map("3",Vector2i(338,333));var next: Dictionary=app.rules.state.duplicate(true);next.gold=3000;app.rules.apply(next,"funds_fixture")
	expect(app.fire_dragon.buy_permit(),"purchase through actual entrance NPC")
	app.enter_map(route.map,door);expect(app.rules.save_location(route.map,door,app.elapsed),"save side doorway")
	before=app.rules.state.duplicate(true)
	app.world.paused=true;expect(not app.cross_passage(route) and app.rules.state==before,"paused entry refused");app.world.paused=false
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.cross_passage(route),"failed entry commit refused")
	expect(app.rules.state==before and app.world.metadata.id==route.map and app.world.player.cell==door,"failed entry restores source doorway and full state")
	expect("凭证未扣除" in app.pending_message,"rollback error remains visible")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.cross_passage(route),"retry enters with purchased permit")
	expect(app.world.metadata.id==EditionFireDragon.MAP and app.rules.state.fire_dragon.permits==0 and app.rules.state.fire_dragon.active,"side entry consumes once and starts session")
	expect(app.world.navigation.mobile(app.world.player.cell),"side arrival can move")
	expect(app.rules.state.fire_dragon.deadline==app.elapsed+1200,"same twenty minute deadline")
	before=app.rules.state.duplicate(true);expect(not app.cross_passage(route) and app.rules.state==before,"stale repeated door cannot consume twice")
	var loaded: Dictionary=app.store.load_world(app.rules.character.id)
	expect(loaded.map==EditionFireDragon.MAP and loaded.fire_dragon.permits==0 and loaded.fire_dragon.active,"side entry and debit persisted together")
	var report:={"checks":checks,"failures":failures,"scope":"actual side route and arrival, original NPC purchase, cross_passage, no permit, pause, SQLite failure and retry; funds and doorway placement are fixtures"}
	FileAccess.open("res://../artifacts/world-story/fire-passage-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
