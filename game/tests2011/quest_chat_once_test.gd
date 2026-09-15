extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/quest-chat-once-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"chat-once","name":"消息验收","job":"战士","gender":"女"});app.world.paused=false
	var elder: Dictionary=app.world.entities.filter(func(e):return e.id=="border:elder")[0]
	app.world.player.reset(Vector2i(elder.cell[0]+1,elder.cell[1]));app.interact(elder)
	var panel=app.form.get_child(1)
	for stage in ["accept","submit"]:
		app.chat_history.clear();panel.submit_control.pressed.emit()
		var message: String="[系统] "+app.rules.message.replace("\n"," ")
		if app.chat_history.count(message)!=1:failures.append(stage+" message count: "+str(app.chat_history.count(message)))
	if app.rules.state.quests.get("nv_arrival")!="done" or int(app.rules.state.inventory.get("ref:5",0))!=1:failures.append("reward or quest changed")
	app.chat_history.clear();app.info("相同操作反馈");app.info("相同操作反馈")
	if app.chat_history.size()!=2:failures.append("separate feedback events incorrectly deduplicated")
	var report:={"failures":failures,"scope":"quest panel real handler via signal: one message per accept/submit, reward unchanged, separate identical operations remain; not physical input"}
	FileAccess.open("res://../artifacts/closeout-quest-chat.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
