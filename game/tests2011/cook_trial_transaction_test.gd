extends SceneTree
const Trial=preload("res://scripts/edition2011/cook_trial_state.gd")
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
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/cook-transactions-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in Trial.JOB_MAPS:
		app.start_character({"id":job,"name":"考验战果","job":job,"gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.map="1";next.quests.story_feast_cook_trail="done";app.rules.count_item(next,"ref:218",1)
		next.quests.story_feast_cook_trial="accepted"
		var session:=Trial.begin(next,job,Vector2i(20,20),100)
		next.cook_trial=session;next.map=session.map;next.cell=[12,12];next.time=100
		expect(app.rules.apply(next,"trial_fixture"),"prepare active trial and preowned helmet")
		var monster:={"id":"cook:"+session.id,"cook_attempt":session.id,"map":session.map,"cell":[10,10],"reference_name":Trial.MONSTERS[job],"exp":100}
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.reward_kill("late", "",monster,160) and app.rules.state==before,"expired kill changes nothing")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.reward_kill("win:"+session.id,"",monster,120) and app.rules.state==before,"failed kill rolls back XP proof and victory")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.reward_kill("win:"+session.id,"",monster,120),"valid kill commits")
		expect(app.rules.state.cook_trial.won and not app.rules.state.cook_trial.picked and int(app.rules.state.inventory["ref:218"])==1,"old helmet does not count as picked proof")
		var loot: Dictionary=app.rules.state.ground_loot.filter(func(l):return l.uid==app.rules.state.cook_trial.proof_uid)[0]
		before=app.rules.state.duplicate(true)
		expect(not app.rules.reward_kill("repeat","",monster,121) and app.rules.state==before,"duplicate kill adds no proof")
		var continuing: Dictionary=app.rules.state.duplicate(true)
		var ended: Dictionary=continuing.duplicate(true);ended.map="1";ended.cook_trial.active=false
		expect(app.rules.apply(ended,"lost_proof_branch_fixture"),"prepare uncollected proof after return")
		var owner: Dictionary=app.rules.story_npc("server:merchant:50");var owner_cell:=Vector2i(owner.cell[0],owner.cell[1])
		var reset_before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.reset_cook_trial("1",owner_cell) and app.rules.state==reset_before,"failed reset preserves old proof and victory")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.reset_cook_trial("1",owner_cell),"explicit reset clears unclaimed attempt")
		expect(not app.rules.state.has("cook_trial") and not app.rules.state.ground_loot.any(func(l):return l.uid==loot.uid) and app.rules.state.items==reset_before.items,"reset removes stale ground proof but keeps possessions")
		var retry:=Trial.begin(app.rules.state,job,owner_cell,140)
		expect(not retry.is_empty() and retry.id!=session.id,"retry receives fresh attempt identity")
		continuing.revision=app.rules.state.revision;expect(app.rules.apply(continuing,"restore_pickup_branch_fixture"),"restore independent pickup branch fixture")
		before=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.pickup(loot.uid,session.map,Vector2i(10,10)) and app.rules.state==before,"failed pickup leaves ground proof and picked flag unchanged")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.pickup(loot.uid,session.map,Vector2i(10,10)),"actual pickup succeeds")
		expect(app.rules.state.cook_trial.picked and int(app.rules.state.inventory["ref:218"])==2,"only matching ground pickup records proof")
		expect(app.rules.save_location("1",Vector2i(20,20),122),"leave trial through saved location")
		expect(not app.rules.state.cook_trial.active and app.rules.state.cook_trial.won,"leaving ends clock while preserving victory")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.rules.state.cook_trial.picked and not app.rules.state.cook_trial.active,"reload preserves proof and ended session")
		var npc: Dictionary=app.rules.story_npc("server:merchant:50");var at:=Vector2i(npc.cell[0],npc.cell[1])
		before=app.rules.state.duplicate(true)
		expect(not app.rules.finish_cook_trial("0",at) and app.rules.state==before,"wrong map cannot claim")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.finish_cook_trial("1",at) and app.rules.state==before,"failed claim retains helmet and unclaimed victory")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.finish_cook_trial("1",at),"claim after victory and matching pickup")
		expect(app.rules.state.cook_trial.claimed and int(app.rules.state.inventory["ref:218"])==1 and app.rules.state.gold==before.gold,"claim takes one helmet without inventing currency reward")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.finish_cook_trial("1",at) and not app.rules.reset_cook_trial("1",at) and app.rules.state==before,"claimed result cannot be repeated or reset")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.rules.state.cook_trial.claimed,"claimed state persists")
		var story=EditionRules.Story
		var q: Dictionary=story.quest("story_feast_cook_trial")
		expect(story.ready(app.rules.state,q),"actual claimed result completes story objective")
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"register completed cook trial")
		var oil: Dictionary=story.quest("story_feast_oil_trail")
		var smith: Dictionary=app.rules.story_npc(oil.start_npc)
		var elder: Dictionary=app.rules.story_npc(oil.end_npc)
		var smith_at:=Vector2i(smith.cell[0],smith.cell[1]);var elder_at:=Vector2i(elder.cell[0],elder.cell[1])
		expect(app.rules.story_action(oil.id,"accept",smith.id,smith.map,smith_at),"accept oil inquiry after trial registration")
		app.rules.story_talk(elder.id,elder.map,elder_at)
		expect(story.progress(app.rules.state,oil,1)==0,"elder cannot precomplete smith explanation")
		app.rules.story_talk(smith.id,smith.map,smith_at);app.rules.story_talk(elder.id,elder.map,elder_at)
		expect(story.ready(app.rules.state,oil),"ordered oil inquiry ready")
		before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(oil.id,"submit",elder.id,elder.map,elder_at) and app.rules.state==before,"oil submission failure preserves state")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(oil.id,"submit",elder.id,elder.map,elder_at),"oil inquiry submission retry")
		expect(app.store.load_world(app.rules.character.id).quests.get(oil.id)=="done","oil inquiry survives reload")
	var report:={"checks":checks,"failures":failures,"scope":"three professions actual SQLite kill/drop/pickup/leave transactions and reload; session, monster defeat, position and preowned helmet fixtures; cook story registration and ordered oil inquiry; actual combat and natural travel not exercised"}
	FileAccess.open("res://../artifacts/world-story/cook-trial-transaction-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
