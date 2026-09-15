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
	app.store.path="/tmp/story-spawn-route-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"spawn-route","name":"区域寻路","gender":"男","job":"战士"})
	var q: Dictionary=Story.quest("story_woma_cave_entry");var objective: Dictionary=q.objectives[1]
	var population: Array=[]
	for row in EditionRegion.data().populations.e001:
		if EditionRegion.data().spawns[int(row[0])].name in objective.names:population=row;break
	expect(not population.is_empty(),"actual target spawn exists")
	expect(app.enter_map("e001",Vector2i(population[2],population[3])+Vector2i(3,0)),"load actual cave near spawn")
	app.world.entities=[];app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.tracked_story=q.id;next.story_progress={q.id:{"0":1}}
	expect(app.rules.apply(next,"unloaded_monsters_fixture"),"prepare accepted task with unloaded monsters")
	var before: Dictionary=app.rules.state.duplicate(true)
	app.world.paused=true;app.navigate_tracked_quest()
	expect(app.world.player.route.is_empty() and app.rules.state==before,"paused monster route refuses movement")
	app.world.paused=false;app.navigate_tracked_quest()
	expect(not app.world.player.route.is_empty(),"unloaded target routes to registered population")
	expect("已登记刷新区域" in app.pending_message,"hint does not promise a live monster")
	expect(app.rules.state==before,"route does not spawn kill reward or save task progress")
	var end: Vector2i=app.world.player.route.back()
	expect(EditionRegion.data().populations.e001.any(func(row):return EditionRegion.data().spawns[int(row[0])].name in objective.names and Vector2(Vector2i(row[2],row[3])-end).length()<=1.5),"route terminates beside a genuine target spawn")
	app.world.player.reset(app.world.player.cell)
	app.show_story();await settle();var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var control=find_button(view,"前往此目标");expect(control!=null,"pending kill target has mouse navigation")
	if control!=null:await click(control)
	expect(not app.world.player.route.is_empty() and app.rules.state==before,"mouse also routes without modifying world state")
	app.world.player.reset(app.world.player.cell);app.approach_story_objective({"type":"kill","maps":["e001"],"names":["不存在的怪物"]})
	expect(app.world.player.route.is_empty() and app.rules.state==before,"unknown target does not borrow another monster spawn")
	var report:={"checks":checks,"failures":failures,"scope":"real map population fallback and mouse route, paused and unknown targets; active entities deliberately unloaded, traversal not simulated"}
	FileAccess.open("res://../artifacts/world-story/spawn-route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
