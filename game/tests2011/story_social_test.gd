extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-social-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"social-story","name":"同行验收","gender":"男","job":"战士"});app.world.paused=true
	var next: Dictionary=app.rules.state.duplicate(true);next.novice={"chickens":0,"patrol":true};next.quests.nv_patrol="done";next.quests.story_valley="done";expect(app.rules.apply(next,"prior_travel_fixture"),"fixture "+app.rules.message)
	var elder: Dictionary=app.rules.story_npc("border:elder");var at:=Vector2i(elder.cell[0],elder.cell[1])
	var q: Dictionary=Story.quest("story_traveler_friend")
	expect(app.rules.story_action(q.id,"accept",elder.id,elder.map,at),"accept friendship task "+app.rules.message)
	var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.social("friends","云游客") and app.rules.state==before,"failed friendship save no progress")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.social("friends","云游客") and Story.ready(app.rules.state,q),"actual friend operation completes condition")
	expect(app.rules.social("friends","云游客") and not Story.ready(app.rules.state,q),"removing friend invalidates pending condition")
	app.rules.social("friends","云游客")
	expect(app.rules.story_action(q.id,"submit",elder.id,elder.map,at),"submit friend task")
	q=Story.quest("story_traveler_journey")
	expect(app.rules.story_action(q.id,"accept",elder.id,elder.map,at),"accept shared journey")
	expect(app.rules.save_location("2",Vector2i(499,484),1.0) and Story.progress(app.rules.state,q,1)==0,"arrival without party does not count")
	expect(app.rules.social("party","云游客"),"invite traveler")
	expect(Story.progress(app.rules.state,q,1)==0,"joining after arrival does not retroactively credit")
	expect(app.rules.save_location("2",Vector2i(499,484),2.0) and not Story.ready(app.rules.state,q),"stationary autosave cannot simulate arrival")
	expect(app.enter_map("2",Vector2i(499,484)) and Story.ready(app.rules.state,q),"real map entry while grouped credits condition");app.world.paused=true
	app.rules.social("party","云游客")
	expect(not Story.ready(app.rules.state,q),"leaving before submission invalidates party requirement")
	app.rules.social("party","云游客")
	var recipient: Dictionary=app.rules.story_npc(q.end_npc)
	expect(app.rules.story_action(q.id,"submit",recipient.id,recipient.map,Vector2i(recipient.cell[0],recipient.cell[1])),"submit joined arrival")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.story_action(q.id,"submit",recipient.id,recipient.map,Vector2i(recipient.cell[0],recipient.cell[1])) and app.rules.state==before,"rejoin cannot duplicate reward")
	expect(app.store.load_world(app.rules.character.id).quests.get(q.id)=="done","social task completion persists")
	var report:={"checks":checks,"failures":failures,"scope":"real social rule operations, relationship removal, arrival condition and transaction persistence; travel locations are fixtures, not escort or siege simulation"}
	FileAccess.open("res://../artifacts/world-story/social-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
