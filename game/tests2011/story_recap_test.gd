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
	for i in range(4):await process_frame
func press(button: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=true;root.push_input(e,true);await settle()
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-recap-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"recap","name":"归档阅读","gender":"男","job":"战士"})
	var q: Dictionary=Story.quest("story_jungle_branch_archive")
	expect(Story.recap(app.rules.state,q).is_empty(),"unaccepted recap hidden")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_jungle_branch_dead="done"
	expect(app.rules.apply(next,"recap_prerequisite_fixture"),"prepare prerequisite")
	var start: Dictionary=app.rules.story_npc(q.start_npc);var target: Dictionary=app.rules.story_npc(q.end_npc);var witness: Dictionary=app.rules.story_npc(q.objectives[0].npc)
	expect(app.rules.story_action(q.id,"accept",start.id,start.map,Vector2i(start.cell[0],start.cell[1])),"accept archive")
	expect(Story.recap(app.rules.state,q).is_empty(),"accepted recap hidden")
	expect(app.rules.story_talk(witness.id,witness.map,Vector2i(witness.cell[0],witness.cell[1])),"record actual witness operation")
	expect(app.rules.story_action(q.id,"submit",target.id,target.map,Vector2i(target.cell[0],target.cell[1])),"submit archive")
	var recap: String=Story.recap(app.rules.state,q)
	expect(q.dialogue in recap and q.objectives[0].dialogue in recap,"completed recap preserves premise and witness text")
	app.enter_map(target.map,Vector2i(target.cell[0],target.cell[1])+Vector2i.DOWN);app.world.paused=false
	var before: Dictionary=app.rules.state.duplicate(true)
	app.show_story();await settle();var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	expect(view.details.get_children().any(func(c):return c is Label and recap in c.text),"mouse journal reads intermediate witness away from witness")
	expect(view.details.get_children().any(func(c):return c is Label and "归档结论" in c.text and q.completion in c.text),"mouse conclusion separately identified")
	app.windows.close_all();app.controller_interact(target);await settle();view=app.form.get_child(1)
	var found:=false
	for i in range(view.rows.size()):
		if view.rows[i].id==q.id:view.cursor=i;found=true;break
	expect(found,"controller completed archive remains listed")
	if found:
		await press(JOY_BUTTON_A)
		expect(recap in view.text.text and q.completion in view.text.text,"controller opens same complete record")
		expect("接取 / 交付" not in view.hint.text,"completed controller record has reading hints")
		await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"completed record cannot award again")
	expect(app.rules.state==before,"all recap reading is read only")
	var report:={"checks":checks,"failures":failures,"scope":"real archive rule operations with prerequisite/position fixtures, mouse journal content and actual controller input; no full journey"}
	FileAccess.open("res://../artifacts/world-story/recap-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
