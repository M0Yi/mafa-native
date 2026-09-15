extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/stone-status-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"stone","name":"石化检查","gender":"男","job":"战士"})
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.receive_damage(1,false,10,true) and app.rules.state==before,"failed hit cannot apply stone")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.receive_damage(1,false,10,true) and app.rules.stoned(10),"hit and stone saved together")
	expect(app.store.load_world(app.rules.character.id).stone_until==15,"stone deadline persists")
	expect(app.rules.stoned(14.99) and not app.rules.stoned(15),"exact five-second boundary")
	app.elapsed=11;before=app.rules.state.duplicate(true)
	app.attack_target();expect(app.pending_attack.is_empty() and app.rules.state==before,"stone blocks ordinary attack")
	expect(not app.gameplay.cast("fireball") and app.rules.state==before,"stone blocks casting before costs")
	var rows: Array=[]
	for y in range(9):rows.append(PackedByteArray([1,1,1,1,1,1,1,1,1]))
	app.world.entities=[];app.world.actors.reset();app.world.navigation.configure({"size":[9,9],"walkable":rows});app.world.player.reset(Vector2i(4,4));app.world.player.path_avoid.clear()
	app.world.player.go_to(Vector2i(6,4));app.world.player.update(0.01,Vector2i.ZERO,false);app.world.player.update(0.05,Vector2i.ZERO,false)
	var anchor: Vector2=app.world.player.anchor;var progress: float=app.world.player.progress
	app.world.player_stoned=true;app.world.paused=false;app.world.elapsed=11
	app.world.update_world(0.2,Vector2(800,600),false,false)
	expect(app.world.player.anchor==anchor and app.world.player.progress==progress,"stone freezes an ongoing step without snapping")
	app.world.paused=true;var elapsed: float=app.world.elapsed;app.world.update_world(1,Vector2(800,600),false,false)
	expect(app.world.elapsed==elapsed,"pause freezes stone game clock")
	app.world.paused=false;app.world.player_stoned=false;app.world.update_world(0.2,Vector2(800,600),false,false)
	expect(app.world.player.anchor!=anchor,"movement resumes from existing progress")
	var ally: Dictionary={"id":"stone-ally","kind":"traveler","name":"青禾","hp":250,"generation":0,"cell":[2,2],"direction":0}
	app.world.entities=[ally];app.elapsed=20;app.gameplay.hit_traveler(ally,{"damage":1,"stone":true})
	expect(ally.stone_until==25 and app.rules.state.traveler_health[ally.id].stone_until==25,"ally stone persists and reaches scene")
	var motion: ClassicPlayer=app.world.actors.mover(ally);motion.go_to(Vector2i(3,2));motion.update(0.01,Vector2i.ZERO,false);motion.update(0.05,Vector2i.ZERO,false)
	anchor=motion.anchor;app.world.elapsed=21;app.world.actors.update(0.2,[])
	expect(motion.anchor==anchor,"stoned traveler stops movement")
	app.world.elapsed=25;app.world.actors.update(0.2,[])
	expect(motion.anchor!=anchor,"traveler resumes after expiry")
	var report:={"checks":checks,"failures":failures,"scope":"atomic stone hit/deadline, failure rollback, attacks/casts blocked, midstep player/traveler freeze and expiry, pause clock; controlled navigation and status fixtures, grayscale art and natural chance unverified"}
	FileAccess.open("res://../artifacts/world-story/stone-status-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
