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
func press(key: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=true;root.push_input(event,true);await settle()
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
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-book-hunt-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"hunt","name":"掉书路线","gender":"男","job":"战士"});app.world.paused=false
	var q: Dictionary=EditionRules.Story.quest("story_mastery_return")
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	app.game_panel("手柄人物委托",Vector2(520,430));var view=load("res://scripts/edition2011/ui/controller_npc.gd").new();app.form.add_child(view);view.setup(app,npc);await settle()
	for i in range(view.rows.size()):
		if view.rows[i].id==q.id:view.cursor=i
	view.open_detail();expect("L3" in view.hint.text,"controller advertises book routes")
	var before: Dictionary=app.rules.state.duplicate(true)
	await press(JOY_BUTTON_LEFT_STICK);view=app.form.get_child(1)
	expect(app.windows.order.back()=="技能书掉落来源" and not view.rows.is_empty(),"L3 opens actual populated sources")
	await press(JOY_BUTTON_DPAD_DOWN);expect(view.cursor==1,"dpad selects next source")
	await press(JOY_BUTTON_DPAD_UP);expect(view.cursor==0,"dpad selects previous source")
	for i in range(view.rows.size()):
		if view.rows[i].map!=app.world.metadata.id:view.cursor=i;break
	app.world.paused=true;await press(JOY_BUTTON_A)
	expect(view.route.is_empty() and app.rules.state==before,"paused game cannot start route")
	app.world.paused=false;await press(JOY_BUTTON_A)
	expect(not view.route.is_empty() and not view.list.visible,"A previews connected route")
	expect(app.rules.state==before,"route preview grants no book or skill")
	await press(JOY_BUTTON_B);expect(view.route.is_empty() and view.list.visible,"B returns to source list")
	await press(JOY_BUTTON_A);var cell: Vector2i=app.world.player.cell
	await press(JOY_BUTTON_A)
	expect(not app.windows.windows.has("技能书掉落来源"),"second A starts walking and closes panels")
	expect(app.world.player.cell==cell and app.rules.state==before,"starting navigation does not teleport or award")
	var objective: Dictionary=q.objectives.filter(func(o):return o.type=="skill")[0]
	app.show_story_book_hunt(objective);await settle();view=app.form.get_child(1);await press(JOY_BUTTON_B)
	expect(not app.windows.windows.has("技能书掉落来源"),"B closes list without operation")
	app.show_story();await settle();view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	await click(find_button(view,"寻找掉书怪物"));view=app.form.get_child(1)
	expect(app.windows.order.back()=="技能书掉落来源","mouse opens source browser")
	for i in range(view.rows.size()):
		if view.rows[i].map!=app.world.metadata.id:view.cursor=i;break
	await click(find_button(view,"查看路线 / 步行下一入口"))
	expect(not view.route.is_empty(),"mouse previews source route")
	expect(app.rules.state==before,"mouse source browsing leaves wealth and skills unchanged")
	var transport_rows:=0
	for i in range(view.rows.size()):
		if view.rows[i].map not in ["5","6","d2081","d2082"]:continue
		transport_rows+=1
		view.route.clear();view.transport.clear();view.list.show();view.cursor=i
		await press(JOY_BUTTON_A)
		expect(not view.transport.is_empty() and view.route.is_empty(),"transport source uses NPC instead of walking graph: "+view.rows[i].map)
		expect(not view.list.visible and "返回来源" in view.detail.text,"controller transport preview visible")
		var selected: int=view.cursor
		await press(JOY_BUTTON_DPAD_DOWN)
		expect(view.cursor==selected,"transport preview locks source selection")
		await press(JOY_BUTTON_B)
		expect(view.transport.is_empty() and view.list.visible,"B cancels transport preview")
		await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"NPC route preview does not consume transport costs")
		view.source_map="stale-map"
		await press(JOY_BUTTON_A)
		expect(view.transport.is_empty() and view.list.visible,"changed map invalidates NPC preview")
		await press(JOY_BUTTON_A)
		await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"NPC guidance does not teleport or deduct funds")
		expect(app.windows.order.back()!="技能书掉落来源","A advances to NPC route or begins walking")
		break
	expect(transport_rows>0,"actual skill drop catalog includes a transport destination")
	var report:={"checks":checks,"failures":failures,"scope":"native mouse entry/preview and viewport joypad L3/dpad/A/B, real source catalog and path planner, pause and no award; selected quest and source cursor are fixtures, continuous route walking and hardware untested"}
	FileAccess.open("res://../artifacts/world-story/book-hunt-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
