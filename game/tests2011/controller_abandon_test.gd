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
func press(key: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=true;root.push_input(event,true);await settle()
func select_task(view,id: String) -> void:
	view.refresh()
	for i in range(view.rows.size()):
		if view.rows[i].id==id:view.cursor=i
	view.open_detail()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-abandon-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"abandon","name":"手柄回接","gender":"男","job":"战士"})
	var q: Dictionary=Story.quest("story_woma_cave_entry")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.quests.story_woma="done";next.tracked_story=q.id;next.story_progress={q.id:{"0":1,"1":2}}
	expect(app.rules.apply(next,"abandon_progress_fixture"),"prepare partial task")
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i(1,0)),"actual NPC map")
	app.world.paused=false;app.controller_interact(npc);await settle();var view=app.form.get_child(1);select_task(view,q.id)
	var before: Dictionary=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_RIGHT_STICK)
	expect(app.windows.has_modal() and view.abandon_id==q.id and app.rules.state==before,"R3 requests confirmation only")
	await press(JOY_BUTTON_B)
	expect(not app.windows.has_modal() and view.abandon_id.is_empty() and app.rules.state==before,"B cancels without changes")
	await press(JOY_BUTTON_RIGHT_STICK);await click(app.windows.modal.get_cancel_button())
	expect(view.abandon_id.is_empty() and app.rules.state==before,"mouse cancel releases controller ownership")
	app.windows.confirm("其他操作",func():pass);await press(JOY_BUTTON_A)
	expect(app.rules.state==before,"unrelated confirmation never abandons prior quest")
	app.windows.modal.hide()
	await press(JOY_BUTTON_RIGHT_STICK);app.windows.pause("focus");await settle()
	expect(view.abandon_id.is_empty(),"focus pause clears pending abandon")
	await click(app.windows.modal.get_ok_button())
	expect(app.rules.state==before and not app.world.paused,"resuming never confirms displaced abandonment")
	await press(JOY_BUTTON_RIGHT_STICK);app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A)
	expect(app.rules.state==before,"failed write preserves progress and tracking")
	app.store.db.query("PRAGMA query_only=OFF;");select_task(view,q.id)
	await press(JOY_BUTTON_RIGHT_STICK);await press(JOY_BUTTON_A)
	expect(not app.rules.state.quests.has(q.id) and not app.rules.state.story_progress.has(q.id) and app.rules.state.tracked_story=="","retry confirmed abandonment clears task only")
	for field in ["items","gold","xp","skills"]:expect(app.rules.state[field]==before[field],"preserve "+field)
	await press(JOY_BUTTON_A)
	expect(view.reading and not app.rules.state.quests.has(q.id),"extra A opens detail without accepting")
	var report:={"checks":checks,"failures":failures,"scope":"native viewport joypad events R3/B/A, mouse cancel, focus replacement, write failure and retry; partial quest and cursor are fixtures, physical controller untested"}
	FileAccess.open("res://../artifacts/world-story/controller-abandon-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
