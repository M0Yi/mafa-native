extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func press(key: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=key;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-report-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"report","name":"归程汇报","job":"战士","gender":"男"});app.world.hide()
	var q: Dictionary=EditionRules.Story.quest("story_demon_garrison_survey")
	var npc: Dictionary=app.rules.story_npc(q.end_npc);app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]));app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_demon_homecoming="done";expect(app.rules.apply(next,"prerequisite_fixture"),"prepare prerequisite")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,app.world.player.cell),"accept report")
	app.controller_interact(npc);await settle();var view=app.form.get_child(1)
	for i in range(view.rows.size()):
		if view.rows[i].id==q.id:view.cursor=i;break
	await press(JOY_BUTTON_A)
	expect(view.reading and view.text.text.contains("先完成前面的目标"),"controller detail shows report order")
	var before: Dictionary=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_A)
	expect(app.rules.state==before and view.reading,"early controller submission preserves state and detail")
	next=app.rules.state.duplicate(true)
	EditionRules.Story.observe(next,"visit",{"map":"b357"});EditionRules.Story.observe(next,"visit",{"map":"ga1"})
	EditionRules.Story.observe(next,"talk",{"npc":"reconstructed:ga1:guard"})
	expect(app.rules.apply(next,"survey_fixture"),"prepare witnessed survey");await settle()
	expect(not view.text.text.contains("先完成前面的目标"),"open controller detail refreshes unlocked report")
	expect(not EditionRules.Story.ready(app.rules.state,q),"unlock alone does not fake return conversation")
	expect(app.rules.story_talk(npc.id,npc.map,app.world.player.cell),"actual elder conversation");await settle()
	before=app.rules.state.duplicate(true);await press(JOY_BUTTON_A)
	expect(app.rules.state.quests[q.id]=="done" and app.rules.state.gold==before.gold+240,"controller submits actual ready report once")
	await press(JOY_BUTTON_B)
	expect(not app.windows.order.has("手柄人物委托"),"B closes controller task list")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport joypad detail, blocked submit, live revision refresh and successful submit; prerequisite, survey and location fixtures; no physical controller or natural exploration"}
	FileAccess.open("res://../artifacts/world-story/controller-report-order-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
