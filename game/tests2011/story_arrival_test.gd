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
	for i in range(8):await process_frame
func reopen(profile: Dictionary) -> void:
	app.store.close();expect(app.store.open(),"reopen SQLite connection")
	expect(app.rules.attach(profile),"reattach character from persisted state")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-arrival-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var profile:={"id":"arrival","name":"到访存档","gender":"男","job":"战士"}
	app.start_character(profile);app.world.paused=true
	var q: Dictionary=Story.quest("story_pig_side_a")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_pig_maze="done";expect(app.rules.apply(next,"prerequisite_fixture"),"prepare prerequisite")
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept survey")
	expect(app.enter_map(q.objectives[0].map),"enter actual first room")
	expect(Story.progress(app.rules.state,q,0)==1,"arrival immediately records without autosave")
	reopen(profile)
	expect(Story.progress(app.rules.state,q,0)==1 and app.rules.state.tracked_story==q.id,"arrival and tracking survive connection close and reattach")
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(app.rules.story_arrival(q.objectives[0].map) and app.rules.state==before,"repeated arrival is idempotent")
	app.store.db.query("PRAGMA query_only=ON;")
	expect(app.enter_map(q.objectives[1].map),"failed progress save does not corrupt map load")
	expect(Story.progress(app.rules.state,q,1)==0,"read-only transaction cannot advance progress")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.save_location(app.world.metadata.id,app.world.player.cell,app.elapsed),"next position save retries alive visit")
	expect(Story.progress(app.rules.state,q,1)==1,"retry advances once")
	next=app.rules.state.duplicate(true);next.hp=0;expect(app.rules.apply(next,"death_fixture"),"prepare death")
	expect(app.enter_map(q.objectives[2].map),"load room while dead")
	expect(app.rules.save_location(app.world.metadata.id,app.world.player.cell,app.elapsed),"dead state still saves location")
	expect(Story.progress(app.rules.state,q,2)==0,"dead arrival and save never grant exploration")
	reopen(profile)
	expect(app.rules.state.hp==0 and Story.progress(app.rules.state,q,2)==0,"dead persistence does not grant exploration")
	next=app.rules.state.duplicate(true);next.hp=100;expect(app.rules.apply(next,"revive_fixture"),"prepare revival")
	expect(app.rules.story_arrival(q.objectives[2].map) and Story.progress(app.rules.state,q,2)==1,"alive arrival can continue investigation")
	expect(app.rules.abandon_story(q.id),"abandon partial survey")
	reopen(profile)
	expect(not app.rules.state.quests.has(q.id) and not app.rules.state.story_progress.has(q.id),"abandon survives reattach")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"reaccept at NPC")
	for i in range(3):expect(Story.progress(app.rules.state,q,i)==0,"reaccept never restores old visit "+str(i))
	var report:={"checks":checks,"failures":failures,"scope":"actual map entry, SQLite close/open and character reattach, immediate visit, read-only retry, death save and abandon; prerequisites/death/revival and NPC distance are fixtures"}
	FileAccess.open("res://../artifacts/world-story/arrival-persistence-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
