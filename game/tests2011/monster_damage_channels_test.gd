extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/damage-channels-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"channels","name":"伤害检查","gender":"男","job":"战士"})
	var original: Dictionary=app.rules.state.duplicate(true)
	app.rules.state.items=[];app.rules.state.armor_until=20;app.rules.state.ghostshield_until=0
	expect(app.rules.incoming_monster_damage(30,false,10)==22,"physical armor mitigates physical hit")
	expect(app.rules.incoming_monster_damage(30,true,10)==30,"physical armor does not mitigate magic hit")
	app.rules.state.ghostshield_until=20;app.rules.state.armor_until=0
	expect(app.rules.incoming_monster_damage(30,true,10)==22,"ghost shield mitigates magic hit")
	expect(app.rules.incoming_monster_damage(30,false,10)==30,"ghost shield does not mitigate physical hit")
	expect(app.rules.incoming_monster_damage(30,true,20)==30,"ghost shield expires at exact deadline")
	app.rules.state.shield_until=20
	expect(app.rules.incoming_monster_damage(30,true,10)==11,"magic shield scales after magic mitigation")
	expect(app.rules.incoming_monster_damage(1,true,10)==1,"damage floor remains one")
	var chosen: String=""
	for id in EditionRules.ITEMS:
		var spec: Dictionary=EditionRules.ITEMS[id]
		if spec.get("slot","")=="armor" and int(spec.get("raw",{}).get("macMax",0))>1:chosen=id;break
	expect(not chosen.is_empty(),"actual armor has reference magic defense")
	var raw: Dictionary=EditionRules.ITEMS[chosen].raw
	app.rules.state.ghostshield_until=0;app.rules.state.shield_until=0
	app.rules.state.items=[{"container":"equipment","type":chosen,"durability":100}]
	var bounds: Vector2i=app.rules.magic_defense_range(10)
	expect(bounds==Vector2i(int(raw.mac),int(raw.macMax)),"durable equipment contributes reference MAC bounds")
	for i in range(32):
		var damage: int=app.rules.incoming_monster_damage(100,true,10)
		expect(damage>=100-bounds.y and damage<=100-bounds.x,"magic roll remains inside equipment defense bounds")
	app.rules.state.items[0].durability=0
	expect(app.rules.magic_defense_range(10)==Vector2i.ZERO,"broken armor gives no magic defense")
	app.rules.state=original
	app.enter_map("d10061",Vector2i(20,21));app.world.paused=false;app.elapsed=10
	var next: Dictionary=app.rules.state.duplicate(true);next.armor_until=20;next.ghostshield_until=20;next.hp=100
	expect(app.rules.apply(next,"damage_channel_fixture"),"prepare live signal fixture")
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	app.world.monster_hit.emit({"magic_attack":true},30)
	expect(app.rules.state==before,"failed magic hit commit preserves state")
	app.store.db.query("PRAGMA query_only=OFF;");app.world.monster_hit.emit({"magic_attack":true},30)
	expect(app.rules.state.hp==78,"live signal uses magic channel without double physical subtraction")
	expect(app.store.load_world(app.rules.character.id).hp==78,"magic damage persists")
	var report:={"checks":checks,"failures":failures,"scope":"physical/magic buff separation, actual item MAC range and broken armor, shield expiry/floor, live monster signal and read-only rollback; equipment/buff/location fixtures, not complete centipede AoE or poison"}
	FileAccess.open("res://../artifacts/world-story/monster-damage-channels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
