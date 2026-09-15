extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-skill-bind-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"bind","name":"绑定保存","job":"道士","gender":"女"})
	var next: Dictionary=app.rules.state.duplicate(true)
	next.level=40;next.skills={"heal":{"rank":1,"proficiency":0},"talisman":{"rank":1,"proficiency":0}};next.skill_keys={"0":"heal"};next.active_skill="heal"
	assert(app.rules.apply(next,"learned_skill_fixture"))
	var stored_before: Dictionary=app.store.load_world("bind")
	for mode in ["paused","dead","roster"]:
		app.world.paused=mode=="paused"
		var old_hp: int=app.rules.state.hp
		if mode=="dead":app.rules.state.hp=0
		if mode=="roster":app.mode="roster"
		var unchanged: Dictionary=app.rules.state.duplicate(true)
		app.gameplay.bind_skill("heal",1)
		assert(app.rules.state==unchanged and app.store.load_world("bind")==stored_before)
		app.rules.state.hp=old_hp;app.mode="game";app.world.paused=false
	print("PASS: paused, dead and roster skill-order updates preserve memory and save")
	var before: Dictionary=app.rules.state.duplicate(true)
	assert(app.store.db.query("PRAGMA query_only=ON;"))
	app.gameplay.bind_skill("heal",1)
	assert(app.rules.state==before)
	assert(app.pending_message==app.rules.message and app.pending_message!="已更新自动技能顺序")
	assert(app.store.db.query("PRAGMA query_only=OFF;"))
	app.gameplay.bind_skill("heal",1)
	assert(app.rules.state.skill_keys=={"1":"heal"})
	assert(app.store.load_world("bind").skill_keys=={"1":"heal"})
	assert(app.pending_message=="已更新自动技能顺序")
	before=app.rules.state.duplicate(true)
	assert(app.store.db.query("PRAGMA query_only=ON;"))
	app.gameplay.select_skill("talisman")
	assert(app.rules.state==before and app.gameplay.current_skill()=="heal")
	assert(app.pending_message==app.rules.message and not app.pending_message.begins_with("当前技能："))
	assert(app.store.db.query("PRAGMA query_only=OFF;"))
	app.gameplay.select_skill("talisman")
	assert(app.gameplay.current_skill()=="talisman" and app.store.load_world("bind").active_skill=="talisman")
	print("PASS: failed binding and selection preserve state, report failure, retry persists both")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
