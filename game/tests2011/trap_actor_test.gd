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
func talk(id: String) -> void:
	var npc: Dictionary=app.rules.story_npc(id)
	app.rules.story_talk(id,npc.map,Vector2i(npc.cell[0],npc.cell[1]))
func run() -> void:
	var Trap=preload("res://scripts/edition2011/trap_status.gd")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/trap-actor-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"trap","name":"困魔状态","job":"道士","gender":"男"});app.world.hide();app.world.paused=false
	var source:={"runtime_id":"trap:deer","name":"鹿","interval":10}
	var monster: Dictionary=EditionRegion.entity_from(source,EditionRegion.data().monsters["鹿"],"trap:deer",-1,app.world.player.cell+Vector2i(2,0),0)
	app.world.entities=[monster];app.world.actors.reset()
	var motion=app.world.actors.mover(monster)
	monster.motion="attack";monster.strike_done=false;monster.aggro=true
	monster.trap_status=Trap.create(monster,28,1,10)
	var origin=motion.anchor
	app.world.elapsed=11
	for i in range(120):app.world.actors.update(1.0/60,[])
	expect(motion.anchor==origin,"controlled actor does not move")
	expect(monster.motion=="stand" and monster.strike_done,"windup canceled in actual actor loop")
	expect(monster.has("trap_status"),"status retained before game-time expiry")
	app.world.paused=true;app.world.elapsed=19;app.world.actors.update(1.0/60,[])
	expect(monster.has("trap_status"),"paused actor loop does not consume status")
	app.world.paused=false;app.world.actors.update(1.0/60,[])
	expect(not monster.has("trap_status"),"resume after test deadline removes status")
	monster.trap_status=Trap.create(monster,28,1,20);monster.hp-=1;app.world.elapsed=21;app.world.actors.update(1.0/60,[])
	expect(not monster.has("trap_status"),"actual damage releases control")
	monster.hp=monster.max_hp;app.world.actors.update(1.0/60,[])
	expect(not monster.has("trap_status"),"healing never restores old control")
	var report:={"checks":checks,"failures":failures,"scope":"actual actor loop with injected deer/status/time; no cast, damage event, persistence, sound or physical input"}
	FileAccess.open("res://../artifacts/world-story/trap-actor-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
