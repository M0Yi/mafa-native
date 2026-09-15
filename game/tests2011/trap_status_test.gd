extends SceneTree
const Trap=preload("res://scripts/edition2011/trap_status.gd")
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize() -> void:
	var monster:={"id":"deer:1","kind":"monster","hp":25,"level":12,"generation":1}
	for rank in [1,2,3]:
		var status:=Trap.create(monster,28,rank,10)
		expect(not status.is_empty(),"eligible monster receives status")
		expect(Trap.active(status,monster,10),"active immediately")
		expect(Trap.active(status,monster,status.expires-0.001),"active until deadline")
		expect(not Trap.active(status,monster,status.expires),"expires exactly at deadline")
		var changed:=monster.duplicate();changed.hp-=1
		expect(not Trap.active(status,changed,11),"damage breaks control")
		changed=monster.duplicate();changed.generation=2
		expect(not Trap.active(status,changed,11),"respawn does not inherit control")
		changed=monster.duplicate();changed.hp=0
		expect(not Trap.active(status,changed,11),"death ends control")
	for change in [{"boss":true},{"catalog_group":"boss_elite"},{"catalog_group":"boss"},{"trap_immune":true},{"kind":"npc"},{"kind":"traveler"},{"level":28},{"hp":0}]:
		var blocked:=monster.duplicate();blocked.merge(change,true)
		expect(Trap.create(blocked,28,1,10).is_empty(),"exclude "+str(change))
	expect(Trap.create(monster,28,1,NAN).is_empty(),"invalid time rejected")
	var controlled:=monster.duplicate()
	controlled.trap_status=Trap.create(controlled,28,1,10);controlled.motion="attack";controlled.strike_done=false
	expect(Trap.update_entity(controlled,11) and controlled.motion=="stand" and controlled.strike_done,"control cancels pending attack")
	controlled.hp-=1
	expect(not Trap.update_entity(controlled,12) and not controlled.has("trap_status"),"damage permanently removes trap")
	controlled.hp=25
	expect(not Trap.update_entity(controlled,13),"healing cannot reactivate broken trap")
	controlled.trap_status=Trap.create(controlled,28,1,10)
	expect(not Trap.update_entity(controlled,18) and not controlled.has("trap_status"),"expiry removes stored status")
	monster.spawn_id="spawn:1";monster.max_hp=25;monster.trap_status=Trap.create(monster,28,1,10)
	var saved:=Trap.snapshot(monster,12)
	var restored:=monster.duplicate();restored.erase("trap_status")
	expect(Trap.restore(restored,saved,12) and restored.trap_status.expires==18,"snapshot restores original deadline")
	expect(not Trap.restore(restored,saved,18),"expired snapshot ignored")
	restored.generation=2
	expect(not Trap.restore(restored,saved,12),"new generation rejects old snapshot")
	saved.hp=-1
	expect(not Trap.valid_snapshot(saved),"invalid snapshot rejected")
	var report:={"checks":checks,"failures":failures,"scope":"pure reconstructed trap status lifecycle only; AI consumer added separately; this test covers pure lifecycle only, not casting, persistence, graphics or audio"}
	FileAccess.open("res://../artifacts/world-story/trap-status-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
