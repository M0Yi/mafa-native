extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/world-story"))!=OK:
		printerr("无法创建测试报告目录");quit(1);return
	call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
var hits:=0
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/dragon-attack-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"dragon","name":"地火验收","gender":"男","job":"战士"})
	expect(app.enter_map(EditionFireDragon.MAP),"actual chamber loads")
	var boss: Dictionary={}
	for e in app.world.entities:
		if e.get("reference_name","")=="火龙教主":boss=e;break
	expect(not boss.is_empty(),"actual boss exists")
	if boss.is_empty():await cleanup_test_store();quit(1);return
	var motion: ClassicPlayer=app.world.actors.mover(boss);var center:=motion.cell
	var target:=center
	for offset in ClassicNavigation.DIRECTIONS:
		if app.world.navigation.can_step(center,center+offset):
			target=center+offset
			for step in range(2,5):
				if app.world.navigation.can_step(center+offset*(step-1),center+offset*step):target=center+offset*step
				else:break
			break
	expect(target!=center,"nearby target has clear line")
	app.world.monster_hit.connect(func(_e,_damage):hits+=1)
	for fps in [30,60,120]:
		var next: Dictionary=app.rules.state.duplicate(true);next.hp=100;expect(app.rules.apply(next,"alive_fixture"),"alive fixture")
		app.world.player.reset(target);app.world.player_alive=true;app.world.paused=false;app.world.elapsed=0
		boss.aggro=true;boss.motion="stand";boss.erase("dragon_warning");boss.dragon_ready=0;var prior:=hits
		app.world.actors.update(0.0,[])
		expect(boss.has("dragon_warning"),"actor update starts warning "+str(fps))
		if fps==30 and DisplayServer.get_name()!="headless":
			app.world.update_camera(Vector2(root.size));app.world.queue_redraw();await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../artifacts/world-story/dragon-warning.png")
		for frame in range(1,int(fps*1.2)):
			app.world.elapsed=float(frame)/fps;EditionDragonAttack.update(app.world,boss,motion,false)
		expect(hits==prior,"windup never hits early "+str(fps))
		app.world.elapsed=1.21;EditionDragonAttack.update(app.world,boss,motion,false)
		expect(hits==prior+1 and not boss.has("dragon_warning"),"one settlement "+str(fps))
		expect(app.rules.state.hp<100,"strike reaches player damage transaction")
		EditionDragonAttack.update(app.world,boss,motion,false);expect(hits==prior+1,"same time cannot double hit")
	var next: Dictionary=app.rules.state.duplicate(true);next.hp=100;app.rules.apply(next,"dodge_fixture")
	app.world.player.reset(target);app.world.elapsed=10;boss.motion="stand";boss.dragon_ready=0;boss.aggro=true
	EditionDragonAttack.update(app.world,boss,motion,false);var prior:=hits
	app.world.paused=true;EditionDragonAttack.update(app.world,boss,motion,false)
	expect(boss.has("dragon_warning") and hits==prior,"pause preserves warning without hit")
	app.world.paused=false;app.world.player.reset(EditionFireDragon.LANDING);app.world.elapsed=11.3
	EditionDragonAttack.update(app.world,boss,motion,false);expect(hits==prior,"leaving marked cells dodges strike")
	app.world.player.reset(target);boss.motion="stand";boss.dragon_ready=0;app.world.elapsed=20
	EditionDragonAttack.update(app.world,boss,motion,false);EditionDragonAttack.update(app.world,boss,motion,true)
	expect(not boss.has("dragon_warning") and hits==prior,"protected target cancels warning")
	EditionDragonAttack.update(app.world,boss,motion,false);expect(boss.has("dragon_warning"),"warning restarts for valid target")
	app.enter_map("3");expect(not boss.has("dragon_warning"),"map reset clears remembered warning")
	var report:={"display_backend":DisplayServer.get_name(),"physical_input":false,"capture_enabled":DisplayServer.get_name()!="headless","checks":checks,"failures":failures,"scope":"actual chamber and boss, 30/60/120 timed skill settlement, pause/dodge/protection/map cancellation; target placement and health are fixtures, full battle/audio/visual acceptance pending"}
	FileAccess.open("res://../artifacts/world-story/dragon-attack-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await cleanup_test_store();quit(0 if failures.is_empty() else 1)

func cleanup_test_store() -> void:
	var path: String=app.store.path
	var pattern:=RegEx.new()
	pattern.compile("^/tmp/dragon-attack-[0-9a-f]{16}\\.sqlite$")
	assert(pattern.search(path)!=null,"refuse cleanup outside this test's random database")
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		if FileAccess.file_exists(path+suffix):assert(DirAccess.remove_absolute(path+suffix)==OK)
	print("PASS: own temporary database cleaned: ",path)
