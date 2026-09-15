extends SceneTree
var app
var failures: Array=[]
var checks:=0
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func settle() -> void:
	for i in range(8):await process_frame
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless":return
	RenderingServer.force_draw();root.get_texture().get_image().save_png(path)
func joy(button: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=pressed;root.push_input(event,true)
	await settle()
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/finish-scope-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"finish","name":"收尾验收","job":"法师","gender":"女"});app.world.paused=false
	var entity: Dictionary=app.world.entities.filter(func(e):return e.kind=="traveler")[0]
	var info: Dictionary=app.world.labels.layout(entity)
	check(not info.health_rect.has_area(),"full health hidden")
	check(info.name_rect.position.y>info.head.y,"name beneath actor")
	entity.hp=100;info=app.world.labels.layout(entity)
	check(info.health_rect.has_area() and info.health_rect.position.y<info.head.y,"injured health visible above head")
	var cfg: Dictionary=EditionRegion.data().monster_settings
	var monster:={"hp":10,"max_hp":100};EditionMonsterAI.regenerate(monster,6,cfg)
	check(monster.hp>10,"monster regenerates")
	monster.hp=99;EditionMonsterAI.regenerate(monster,60,cfg);check(monster.hp==100,"regen capped")
	monster.hp=0;EditionMonsterAI.regenerate(monster,60,cfg);check(monster.hp==0,"regen cannot revive")
	var a:={"hp":10,"max_hp":100};var b: Dictionary=a.duplicate()
	for i in range(600):EditionMonsterAI.regenerate(a,0.1,cfg)
	EditionMonsterAI.regenerate(b,60,cfg);check(absf(float(a.hp)-float(b.hp))<=2,"regen equivalent across step sizes")
	check(app.rules.set_assist("auto_shield",true),"shield option persists")
	check(not app.gameplay.auto_profession(app.rules.state.assist),"unlearned shield not cast")
	var next: Dictionary=app.rules.state.duplicate(true);next.level=50;next.skills.shield={"rank":1,"proficiency":0}
	check(app.rules.apply(next,"learned_shield_test_fixture"),"prepare learned skill")
	app.elapsed=10
	check(app.gameplay.auto_profession(app.rules.state.assist),"learned shield automatic cast")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.fight_timer=0;check(not app.gameplay.auto_profession(app.rules.state.assist) and app.rules.state==before,"active shield not repeatedly charged")
	app.gameplay.show_assist();await settle()
	var view=app.form.get_child(app.form.get_child_count()-1)
	await joy(JOY_BUTTON_RIGHT_SHOULDER);check(view.page==1,"assist shoulder next")
	await joy(JOY_BUTTON_LEFT_SHOULDER);check(view.page==0,"assist shoulder previous")
	await joy(JOY_BUTTON_A);check(app.rules.state.assist.get("hp",false),"controller toggles option")
	await joy(JOY_BUTTON_DPAD_DOWN);var old: float=view.controls[1].value
	await joy(JOY_BUTTON_DPAD_RIGHT);check(view.controls[1].value==old+1,"controller adjusts threshold")
	for screen in [Vector2i(1280,800),Vector2i(800,600)]:
		root.size=screen;await settle()
		check(Rect2(Vector2.ZERO,Vector2(screen)).encloses(app.panel.get_global_rect()),"fullscreen assist fits "+str(screen))
		capture("res://../artifacts/world-story/finish-assist-"+str(screen.x)+".png")
	await joy(JOY_BUTTON_B);check(not app.windows.windows.has("内挂设置"),"B closes assist")
	app.show_controller_panel();await settle();view=app.form.get_child(1)
	await joy(JOY_BUTTON_RIGHT_SHOULDER);check(view.page==1,"controller inventory shoulder tabs")
	capture("res://../artifacts/world-story/finish-controller-800.png")
	await joy(JOY_BUTTON_X);check(app.windows.windows.has("内挂设置"),"controller opens assist")
	app.windows.close_all();app.show_adventure(0);await settle();view=app.form.get_child(1)
	await joy(JOY_BUTTON_RIGHT_SHOULDER);check(view.current==1,"adventure also supports shoulder")
	app.windows.close_all()
	app.start_character({"id":"finish-warrior","name":"刺杀验收","job":"战士","gender":"男"});app.world.paused=false
	check(app.rules.set_assist("auto_thrust",true),"thrust setting saved")
	check(not app.gameplay.assisted_strike(),"unlearned thrust cannot replace attack")
	next=app.rules.state.duplicate(true);next.level=50;next.skills.thrust={"rank":1,"proficiency":0}
	check(app.rules.apply(next,"learned_thrust_fixture"),"prepare learned thrust")
	var target: Dictionary={}
	for e in app.world.entities:
		if e.kind=="monster" and e.hp>0 and not EditionRegion.safe(app.world.metadata.id,Vector2i(e.cell[0],e.cell[1])):
			target=e;break
	check(not target.is_empty(),"outdoor target available")
	if not target.is_empty():
		app.world.player.cell=Vector2i(target.cell[0]-1,target.cell[1]);app.selected=target
		app.pending_attack.clear();app.fight_timer=0;app.elapsed+=10
		var proficiency: int=app.rules.state.skills.thrust.proficiency
		check(app.gameplay.assisted_strike() and app.rules.state.skills.thrust.proficiency==proficiency+1,"assisted thrust commits actual cast")
		before=app.rules.state.duplicate(true)
		app.gameplay.assisted_strike();check(app.rules.state==before,"thrust cannot charge twice during cooldown")
		app.world.paused=true;app.fight_timer=0;app.pending_attack.clear();app.elapsed+=10
		app.gameplay.assisted_strike();check(app.rules.state==before,"pause blocks thrust")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/finish-fallbacks.json"))
	for key in manifest.aliases:
		var parts: PackedStringArray=key.split(":");var frame: Dictionary=app.resources.frame(parts[0],int(parts[1]))
		check(not frame.is_empty() and frame.body_visible,"substitute loads "+key)
	check(app.resources.fallback_used.size()==manifest.aliases.size(),"all configured substitutes tracked")
	var report:={"checks":checks,"failures":failures,"scope":"labels, regeneration, learned-only shield and thrust/cooldown/pause, shoulder menus, fullscreen layouts and all explicit fallback decodes; isolated fixtures; no physical controller or all-map visual review"}
	FileAccess.open("res://../artifacts/world-story/finish-scope-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
