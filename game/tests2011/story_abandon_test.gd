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
	for i in range(8):await process_frame
func find_button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=find_button(child,title)
		if found!=null:return found
	return null
func click(button: Control) -> void:
	var parent=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.position+=Vector2(button.get_window().position) if button.get_window()!=root else Vector2.ZERO;e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-abandon-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"abandon","name":"委托回接","gender":"男","job":"战士"});app.world.paused=false
	var q: Dictionary=Story.quest("story_woma_cave_entry")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.quests.story_woma="done";next.tracked_story=q.id;next.story_progress={q.id:{"0":1,"1":2}}
	expect(app.rules.apply(next,"abandon_progress_fixture"),"prepare partial task")
	app.show_story();await settle();var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var before: Dictionary=app.rules.state.duplicate(true)
	await click(find_button(view,"放弃此任务"))
	expect(app.windows.has_modal() and app.rules.state==before,"abandon requires explicit confirmation")
	await click(app.windows.modal.get_cancel_button())
	expect(not app.windows.has_modal() and app.rules.state==before,"cancel preserves full state")
	await click(find_button(view,"放弃此任务"));app.store.db.query("PRAGMA query_only=ON;")
	await click(app.windows.modal.get_ok_button())
	expect(app.rules.state==before,"failed abandon transaction preserves task progress and tracking")
	app.store.db.query("PRAGMA query_only=OFF;")
	await click(find_button(view,"放弃此任务"));await click(app.windows.modal.get_ok_button())
	expect(not app.rules.state.quests.has(q.id) and not app.rules.state.story_progress.has(q.id) and app.rules.state.tracked_story=="","confirmed mouse abandon clears only task and tracking")
	for field in ["items","gold","xp","skills"]:expect(app.rules.state[field]==before[field],"abandon preserves "+field)
	expect(app.rules.state.quests.story_woma=="done","other completed quest remains")
	var npc: Dictionary=app.rules.story_npc(q.start_npc);var cell:=Vector2i(npc.cell[0],npc.cell[1])
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,cell),"original NPC allows reaccept")
	expect(Story.progress(app.rules.state,q,0)==0 and Story.progress(app.rules.state,q,1)==0,"reaccepted visit and kill progress starts over")
	next=app.rules.state.duplicate(true);next.hp=0;app.rules.apply(next,"death_fixture");before=app.rules.state.duplicate(true)
	expect(not app.rules.abandon_story(q.id) and app.rules.state==before,"dead state cannot abandon")
	next=app.rules.state.duplicate(true);next.hp=100;next.quests[q.id]="done";app.rules.apply(next,"completed_fixture");before=app.rules.state.duplicate(true)
	expect(not app.rules.abandon_story(q.id) and app.rules.state==before,"completed task cannot be reopened for reward")
	var report:={"checks":checks,"failures":failures,"scope":"Viewport synthetic mouse confirm/cancel (headless-compatible, not physical input), write failure, rule reaccept and state preservation; partial progress, death and completed state are fixtures"}
	FileAccess.open("res://../artifacts/world-story/abandon-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	var test_path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(test_path+suffix)
	quit(0 if failures.is_empty() else 1)
