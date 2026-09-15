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
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-ground-route-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"ground-route","name":"拾取指引","gender":"男","job":"战士"});app.world.paused=false
	var origin: Vector2i=app.world.player.cell
	var target: Vector2i=app.world.navigation.nearest_mobile(origin+Vector2i(4,0))
	var q: Dictionary=Story.quest("story_dragon_trial")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.tracked_story=q.id;next.story_progress={q.id:{"0":1}}
	app.rules.add_ground(next,{"map":"3","cell":[origin.x,origin.y]},"dragon_story_scale",1)
	expect(app.rules.apply(next,"loot_navigation_fixture"),"prepare accepted collection with other-map drop")
	var before: Dictionary=app.rules.state.duplicate(true);app.navigate_tracked_quest()
	expect(app.world.player.route.is_empty() and app.rules.state==before,"other-map drop cannot cause local path or pickup")
	await settle()
	expect(app.windows.windows.has("寻找遗留任务物品"),"foreign drop offers a return itinerary")
	var route_button=find_button(app.form,"查看路线："+str(app.resources.map_by_id["3"].name)+" · 地面 ×1")
	expect(route_button!=null,"foreign drop shows actual map and count")
	if route_button!=null:await click(route_button)
	expect(app.windows.windows.has("任务远行路线") and app.rules.state==before and app.world.metadata.id=="0","mouse opens normal route without teleport pickup or payment")
	app.windows.close_all()

	next=app.rules.state.duplicate(true);app.rules.add_ground(next,{"map":"0","cell":[target.x,target.y]},"dragon_story_scale",1)
	expect(app.rules.apply(next,"local_loot_fixture"),"prepare local dropped material")
	before=app.rules.state.duplicate(true);app.world.paused=true;app.navigate_tracked_quest()
	expect(app.world.player.route.is_empty() and app.rules.state==before,"paused collection navigation refuses movement")
	app.world.paused=false;app.navigate_tracked_quest()
	expect(not app.world.player.route.is_empty() and app.world.player.route.back()==target,"tracker paths to matching local ground item")
	expect(app.rules.state==before and not Story.ready(app.rules.state,q),"path planning does not put material in bag or satisfy quest")
	app.world.player.reset(origin);app.show_story();await settle()
	var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var control=find_button(view,"寻找材料 / 地面物品");expect(control!=null,"task detail exposes collect navigation")
	if control!=null:await click(control)
	expect(not app.world.player.route.is_empty() and app.rules.state==before,"actual mouse navigation only plans route")
	app.world.player.reset(target)
	var drop: Dictionary=app.rules.state.ground_loot.filter(func(row):return row.map=="0" and row.type=="dragon_story_scale")[0]
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.pickup(drop.uid,"0",target) and app.rules.state==before,"failed pickup preserves ground material and quest")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.pickup(drop.uid,"0",target) and Story.ready(app.rules.state,q),"real pickup satisfies collection")
	expect(not app.rules.pickup(drop.uid,"0",target),"same ground item cannot be picked twice")
	var report:={"checks":checks,"failures":failures,"scope":"tracker and native mouse local loot navigation, real pickup failure and retry; kill, drop placement and arrival are fixtures"}
	FileAccess.open("res://../artifacts/world-story/ground-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
