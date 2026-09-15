extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var path:=OS.get_environment("MAFA_RESTART_DB")
	var phase:=OS.get_environment("MAFA_RESTART_PHASE")
	if path.is_empty() or phase not in ["deposit","resume"]:printerr("explicit isolated database and phase required");quit(1);return
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path=path;root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"warehouse-restart","name":"寄存续行","gender":"男","job":"战士"})
	var q: Dictionary=Story.quest("story_mongchon_storage")
	var giver: Dictionary=app.rules.story_npc(q.start_npc)
	var npc: Dictionary=app.rules.story_npc("server:merchant:65")
	var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
	if phase=="deposit":
		var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.requires[0]]="done"
		expect(app.rules.apply(next,"warehouse_restart_prerequisite"),"prepare prior procurement")
		var giver_at:=Vector2i(giver.cell[0]+1,giver.cell[1])
		expect(app.enter_map(giver.map,giver_at) and app.save_world(),"prepare elder location")
		expect(app.rules.story_action(q.id,"accept",giver.id,giver.map,app.world.player.cell),"accept from elder")
		expect(app.rules.warehouse("potion",true),"deposit on different map through rule fixture")
		expect(Story.progress(app.rules.state,q,1)==0,"wrong map deposit does not count")
		expect(app.enter_map(npc.map,at) and app.save_world(),"save warehouse location")
		at=app.world.player.cell
		expect((at-Vector2i(npc.cell[0],npc.cell[1])).length()<=4,"resolved landing remains within warehouse service range")
		FileAccess.open(path+".landing.json",FileAccess.WRITE).store_string(JSON.stringify({"map":app.rules.state.map,"cell":app.rules.state.cell}))
		expect(app.rules.warehouse("potion",false),"retrieve existing potion before proper deposit")
		expect(Story.progress(app.rules.state,q,2)==0,"early retrieval cannot satisfy ordered withdrawal")
		expect(app.rules.warehouse("potion",true),"commit deposit before process exits")
		expect(Story.progress(app.rules.state,q,1)==1 and Story.progress(app.rules.state,q,2)==0,"only deposit complete")
	else:
		expect(app.rules.state.quests.get(q.id)=="accepted","accepted task restored in new process")
		expect(Story.progress(app.rules.state,q,1)==1 and Story.progress(app.rules.state,q,2)==0,"intermediate stage restored")
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".landing.json"))
		expect(app.rules.state.map==saved.map and app.rules.state.cell==saved.cell,"actual saved warehouse location restored")
		at=Vector2i(saved.cell[0],saved.cell[1])
		expect(app.rules.state.inventory.get("potion",0)==4 and app.rules.state.warehouse.get("potion",0)==1,"stored potion not duplicated on restart")
		expect(app.rules.warehouse("potion",false) and Story.ready(app.rules.state,q),"withdraw continues second stage")
		var giver_at:=Vector2i(giver.cell[0]+1,giver.cell[1])
		expect(app.enter_map(giver.map,giver_at),"prepare delivery location after resumed withdrawal")
		at=app.world.player.cell
		expect(app.rules.story_action(q.id,"submit",giver.id,giver.map,at),"complete resumed task")
		var completed: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",giver.id,giver.map,at) and app.rules.state==completed,"resumed reward cannot duplicate")
		expect(app.rules.state.inventory.get("potion",0)==5 and app.rules.state.warehouse.get("potion",0)==0,"same five potions retained")
	var report:={"phase":phase,"checks":checks,"failures":failures,"scope":"two separate native processes, committed deposit and resumed withdrawal; initial/delivery positions, prerequisite and wrong-map rule operation fixtures; not natural travel, crash recovery or hardware input"}
	FileAccess.open("res://../artifacts/world-story/mongchon-storage-restart-"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	if phase=="deposit" and OS.get_environment("MAFA_RESTART_HOLD")=="1" and failures.is_empty():
		var marker:=FileAccess.open(path+".committed",FileAccess.WRITE)
		marker.store_string("deposit committed; process awaits forced termination");marker.close()
		return
	app.queue_free()
	for i in range(3):await process_frame
	# Audio playback releases on the mixer clock, not headless frame count.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
