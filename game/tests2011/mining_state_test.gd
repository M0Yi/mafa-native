extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize() -> void:
	var Mining=preload("res://scripts/edition2011/mining.gd")
	var old:={"attempts":41,"ready":120.5}
	var preserved: Dictionary=old.duplicate(true)
	expect(Mining.valid(old) and old==preserved,"legacy record validated without mutation or reset")
	var current:={"attempts":201,"ready":700.0,"veins":{"d401:10:20":{"used":200,"restore_at":800.0},"d402:5:6":{"used":1,"restore_at":0.0}}}
	expect(Mining.valid(JSON.parse_string(JSON.stringify(current))),"current record survives JSON numeric conversion")
	for bad in [null,[],{}, {"attempts":true,"ready":0},{"attempts":1.5,"ready":0},{"attempts":-1,"ready":0},{"attempts":1,"ready":INF},{"attempts":1,"ready":NAN}]:
		expect(not Mining.valid(bad),"invalid top level record rejected")
	for key in ["d401:01:20","d401:+1:20","d401:-1:20","d401:4096:20","0:10:20","d401:10:20:30"]:
		var bad: Dictionary=old.duplicate(true);bad.veins={key:{"used":1,"restore_at":0}}
		expect(not Mining.valid(bad),"invalid or aliased wall key rejected: "+key)
	for node in [{"used":201,"restore_at":900},{"used":1,"restore_at":900},{"used":200,"restore_at":0},{"used":1.1,"restore_at":0},{"used":1,"restore_at":NAN}]:
		var bad: Dictionary=old.duplicate(true);bad.veins={"d401:1:2":node}
		expect(not Mining.valid(bad),"invalid wall timer/count combination rejected")
	var report:={"checks":checks,"failures":failures,"scope":"mining save schema and nonmutating legacy acceptance; does not exercise database corruption recovery UI"}
	FileAccess.open("res://../artifacts/world-story/mining-state-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
