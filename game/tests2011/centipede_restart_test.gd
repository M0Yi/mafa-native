extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var phase:=OS.get_environment("MAFA_TEST_PHASE");var mode:=OS.get_environment("MAFA_TEST_STEP")
	var path:=OS.get_environment("MAFA_TEST_DATABASE")
	if not path.begins_with("/tmp/centipede-restart-") or phase not in ["hidden","emerging","exposed","receding"] or mode not in ["write","read"]:quit(2);return
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path=path;root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"restart","name":"阶段重启检查","gender":"男","job":"战士"})
	if mode=="write":expect(app.enter_map("d606",Vector2i(69,153)),"load writer location")
	else:expect(app.world.metadata.id=="d606","reader opens saved map")
	var boss: Dictionary={}
	for entity in app.world.entities:
		if entity.get("reference_name","")=="触龙神":boss=entity;break
	expect(not boss.is_empty(),"boss is populated")
	if not boss.is_empty():
		if mode=="write":
			app.elapsed=125;app.world.elapsed=125;boss.hp=321;boss.centipede_phase=phase;boss.centipede_last_attack=120;boss.motion_time=124.5
			boss.motion="emerge" if phase=="emerging" else "recede" if phase=="receding" else "stand"
			expect(app.save_world(),"writer commits phase")
		else:
			expect(app.elapsed==125 and app.world.elapsed==125,"separate process preserves runtime clock without offline advance")
			expect(boss.hp==321 and boss.centipede_phase==phase,"separate process restores health and phase")
			expect(boss.centipede_last_attack==120 and boss.motion_time==124.5,"cooldown and animation origin retained")
			expect(app.gameplay.can_target(boss)==(phase in ["emerging","exposed"]),"targetability follows restored phase")
			var frame: int=app.world.actor_frame(boss)
			if phase=="hidden":expect(frame==-1,"hidden body remains hidden after restart")
			elif phase in ["emerging","receding"]:expect(frame==(72 if phase=="emerging" else 82),"partial animation resumes at saved progress")
			else:expect(frame>=0,"exposed body stays visible")
	var report:={"checks":checks,"failures":failures,"phase":phase,"step":mode,"pid":OS.get_process_id(),"scope":"separate native process save/load with controlled initial phase and clock, not manual UI quit or power interruption"}
	FileAccess.open("res://../artifacts/world-story/centipede-restart-"+phase+"-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
