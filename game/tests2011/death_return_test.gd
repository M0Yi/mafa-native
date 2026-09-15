extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func talk(id: String) -> void:
	var npc: Dictionary=app.rules.story_npc(id)
	app.rules.story_talk(id,npc.map,Vector2i(npc.cell[0],npc.cell[1]))
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/death-return-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"death","name":"死亡回城","job":"战士","gender":"男"});app.world.hide();app.enter_map("1",Vector2i(300,299));app.world.paused=false;app.elapsed=100
	var next: Dictionary=app.rules.state.duplicate(true);next.hp=0;next.map="1";next.cell=[300,299];next.time=100
	expect(app.rules.apply(next,"death_fixture"),"prepare death")
	app.gameplay.ensure_death()
	expect(app.rules.state.death_due==130,"death wait remains 30 seconds")
	var callbacks: Array=[]
	app.windows.confirm("死亡前旧操作",func():callbacks.append("stale"))
	app.world.paused=true
	var resume: Button=app.gameplay.death_layer.find_children("*","Button",true,false).filter(func(b):return b.text=="继续倒计时（暂停时）")[0]
	resume.pressed.emit();app.windows.modal.confirmed.emit()
	expect(callbacks.is_empty() and not app.windows.modal.visible and not app.world.paused,"resume countdown cancels old modal callback")
	var dead_state: Dictionary=app.rules.state.duplicate(true)
	var item: Dictionary=app.rules.state.items[0]
	for action in ["use","split","move","drop","sort","bind"]:
		expect(not app.rules.inventory_action(action,{"uid":item.uid,"count":1,"container":"inventory","slot":5}) and app.rules.state==dead_state,"dead inventory action rejected: "+action)
	expect(not app.gameplay.use_item_uid(item.uid) and app.rules.state==dead_state,"dead gameplay use cannot consume or heal")
	app.elapsed=129.99
	expect(not app.gameplay.revive_after_wait() and app.rules.state.hp==0,"cannot revive early")
	app.elapsed=130;app.world.paused=true
	expect(not app.gameplay.revive_after_wait(),"pause freezes return")
	app.world.paused=false;var before: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	var back: Button=app.gameplay.death_layer.find_children("*","Button",true,false).filter(func(b):return b.text=="返回选角（重新进入即可就近复活）")[0]
	back.pressed.emit()
	expect(app.mode=="game" and app.rules.state==before and is_instance_valid(app.gameplay.death_layer),"failed death-page logout preserves dead state")
	expect(app.gameplay.death_feedback.text.begins_with("保存未完成：") and not app.pending_message.is_empty(),"death page shows save failure above grey overlay")
	root.size=Vector2i(800,600)
	app.gameplay.death_feedback.text="保存未完成：当前存档目录无法写入，请检查磁盘空间与目录权限，处理后重试。原有进度仍保留。"
	await settle();app.gameplay.update_death_layout();await settle()
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.gameplay.death_box.get_global_rect()),"death feedback box fits minimum window")
	expect(app.gameplay.death_box.get_global_rect().encloses(app.gameplay.death_feedback.get_global_rect()),"death feedback remains inside panel")
	if "--capture-death" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/closeout-death-feedback-800.png")
	expect(not app.gameplay.revive_after_wait() and app.rules.state==before,"failed revival commits nothing")
	expect(app.world.metadata.id=="1" and app.death_return_at==130,"failure restores dead scene and retry timer")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.gameplay.revive_after_wait(),"retry revival succeeds")
	expect(app.rules.state.hp>0 and app.rules.state.map=="0" and not app.rules.state.has("death_due"),"health and village saved together")
	expect(app.rules.state.items==before.items and app.rules.state.gold==before.gold,"possessions preserved")
	app.start_character(app.rules.character.duplicate(true));app.world.hide()
	expect(app.world.metadata.id=="0" and app.rules.state.hp>0,"reload is alive at village")
	var report:={"checks":checks,"failures":failures,"scope":"30-second boundary, paused and readonly failure/retry, atomic health/location and reload; death and elapsed time injected, no physical input"}
	FileAccess.open("res://../artifacts/world-story/death-return-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	if failures.is_empty():print("PASS: death page regression completed")
	var path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)
