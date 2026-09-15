extends SceneTree
const Trial=preload("res://scripts/edition2011/cook_trial_state.gd")
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():
	for job in Trial.JOB_MAPS:
		var state:={"hp":100,"map":"1","quests":{"story_feast_cook_trail":"done"}}
		var session:=Trial.begin(state,job,Vector2i(20,20),100.0)
		expect(Trial.valid(session) and session.map==Trial.JOB_MAPS[job],"valid profession attempt")
		expect(not Trial.due(session,159.999) and Trial.due(session,160.0),"deadline boundary")
		for bad in [NAN,INF,-1.0]:expect(Trial.begin(state,job,Vector2i(20,20),bad).is_empty(),"invalid start rejected")
		for pair in [["wrong",session.map,Trial.MONSTERS[job],101.0,true],[session.id,"0",Trial.MONSTERS[job],101.0,true],[session.id,session.map,"鸡",101.0,true],[session.id,session.map,Trial.MONSTERS[job],160.0,true],[session.id,session.map,Trial.MONSTERS[job],101.0,false],[session.id,session.map,Trial.MONSTERS[job],99.0,true]]:
			expect(Trial.victory(session,pair[0],pair[1],pair[2],pair[3],pair[4]).is_empty(),"wrong or late victory rejected")
		var won:=Trial.victory(session,session.id,session.map,Trial.MONSTERS[job],159.99,true)
		expect(won.won and not session.won,"victory prepares copy without mutating source")
		expect(Trial.victory(won,won.id,won.map,Trial.MONSTERS[job],159.999,true).is_empty(),"duplicate victory refused")
		state.cook_trial=won;expect(Trial.begin(state,job,Vector2i(20,20),200).is_empty(),"unclaimed victory cannot be overwritten")
		var restored=JSON.parse_string(JSON.stringify(won));expect(Trial.valid(restored),"serialized attempt preserves schema")
		for key in ["active","won","claimed"]:
			var bad:=won.duplicate(true);bad[key]=1;expect(not Trial.valid(bad),"invalid boolean rejected")
		state.erase("cook_trial");state.quests.clear();expect(Trial.begin(state,job,Vector2i(20,20),100).is_empty(),"prerequisite required")
	var report:={"checks":checks,"failures":failures,"scope":"pure attempt schema, job mapping and victory/deadline rules; runtime entry, combat, ground proof and SQLite transaction integration still pending"}
	FileAccess.open("res://../artifacts/world-story/cook-trial-state-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
