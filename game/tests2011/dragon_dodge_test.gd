extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
var hits:=0
func run() -> void:
	root.size=Vector2i(1280,800);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/dragon-dodge-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"dodge","name":"走位验证","gender":"男","job":"战士"});app.enter_map(EditionFireDragon.MAP)
	var boss: Dictionary={}
	for entity in app.world.entities:
		if entity.get("reference_name","")=="火龙教主":boss=entity;break
	expect(not boss.is_empty(),"real boss exists")
	if boss.is_empty():quit(1);return
	# Isolate this attack from surrounding guards; retain the actual chamber grid.
	app.world.entities=[boss]
	var motion: ClassicPlayer=app.world.actors.mover(boss);var origin:=motion.cell
	var target:=origin;var escape:=origin
	for offset in ClassicNavigation.DIRECTIONS:
		var candidate: Vector2i=origin+offset*4
		var clear:=true
		for step in range(1,7):
			if not app.world.navigation.can_step(origin+offset*(step-1),origin+offset*step):clear=false;break
		if clear:target=candidate;escape=origin+offset*6;break
	expect(target!=origin,"two-step dodge corridor exists in chamber")
	if target==origin:quit(1);return
	app.world.monster_hit.connect(func(_e,_damage):hits+=1)
	for fps in [30,60,120]:
		for late in [false,true]:
			var next: Dictionary=app.rules.state.duplicate(true);next.hp=100;app.rules.apply(next,"alive_fixture")
			app.world.player.reset(target);app.world.player_alive=true;app.world.paused=false;app.world.elapsed=0
			boss.aggro=true;boss.focus_time=0;boss.motion="stand";boss.erase("dragon_warning");boss.dragon_ready=0;motion.reset(origin)
			app.world.actors.update(0.0,[]);expect(boss.has("dragon_warning"),"real update starts warning")
			var prior:=hits;var started:=false;var steps: int=app.world.player.completed_steps
			for frame in range(int(fps*1.6)):
				if not started and app.world.elapsed>=(1.1 if late else 0.3):
					started=true;expect(app.world.player.go_to(escape),"normal walk path accepted")
				app.world.update_world(1.0/fps,Vector2(root.size),false,false)
			if late:
				expect(hits==prior+1 and app.rules.state.hp<100,"late reaction takes one hit at "+str(fps))
			else:
				expect(hits==prior and app.rules.state.hp==100,"timely walk dodges at "+str(fps))
				expect(app.world.player.completed_steps>=steps+2 and app.world.player.cell==escape,"dodge completes actual steps without reset")
	var report:={"checks":checks,"failures":failures,"scope":"actual chamber grid, player step interpolation and actor update at 30/60/120; reaction delay and target placements controlled, surrounding guards excluded, physical mouse/controller and full fight untested"}
	FileAccess.open("res://../artifacts/world-story/dragon-dodge-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
