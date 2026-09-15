extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func cloud() -> Dictionary:return app.world.entities.filter(func(e):return e.kind=="traveler" and e.name=="云游客")[0]
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/traveler-identity-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var profile: Dictionary={"id":"identity","name":"同行身份","gender":"男","job":"战士"};app.start_character(profile);app.world.paused=false;app.elapsed=0
	var id: String=cloud().id;app.gameplay.hit_traveler(cloud(),{"damage":100})
	app.enter_map("3");expect(cloud().id==id and cloud().hp==150,"wounds follow traveler to town")
	app.enter_map("0");expect(cloud().id==id and cloud().hp==150,"return does not create fresh villager")
	app.gameplay.hit_traveler(cloud(),{"damage":1000});app.enter_map("3")
	expect(cloud().hp==0,"map change does not resurrect traveler")
	var next: Dictionary=app.rules.state.duplicate(true);next.erase("traveler_identity_version")
	next.traveler_health={"border:traveler:0":{"hp":180,"generation":0,"respawn":0},"3:traveler":{"hp":0,"generation":1,"respawn":30},"enemy":{"hp":120,"generation":0,"respawn":0}}
	expect(app.rules.apply(next,"legacy_identity_fixture"),"legacy profile fixture saved")
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.attach(profile),"migration write failure rejects attach")
	var original: Dictionary=app.store.load_world(profile.id)
	expect(original.traveler_health.has("3:traveler") and not original.has("traveler_identity_version"),"failed migration preserves original database")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.attach(profile),"legacy identity migration commits")
	expect(app.rules.state.traveler_health[id].hp==0 and app.rules.state.traveler_health[id].generation==1,"migration conservatively selects later death")
	expect(app.rules.state.legacy_traveler_health.size()==2,"original per-map records preserved")
	expect(app.rules.state.traveler_health.enemy.hp==120 and not app.rules.state.traveler_health.has("3:traveler"),"unrelated identities preserved and aliases retired")
	var revision: int=app.rules.state.revision
	expect(app.rules.attach(profile) and app.rules.state.revision==revision,"migration does not repeat")
	app.enter_map("0");expect(cloud().hp==0,"migrated death reflected on village entity")
	app.elapsed=30;app.gameplay.sync_travelers();expect(cloud().hp==250,"canonical traveler recovers on schedule")
	app.enter_map("3");expect(cloud().hp==250 and app.store.load_world(profile.id).traveler_health[id].hp==250,"canonical recovery follows across map and DB")
	var report:={"checks":checks,"failures":failures,"scope":"actual traveler damage and cross-map recreation, persisted legacy profile migration with archive and idempotence, recovery; initial damage/time and legacy records fixtures, continuous travel untested"}
	FileAccess.open("res://../artifacts/world-story/traveler-identity-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
