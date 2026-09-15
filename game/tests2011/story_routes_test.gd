extends SceneTree
const Planner=preload("res://scripts/edition2011/story_routes.gd")
class OpenNavigation:
	extends RefCounted
	func path(_a: Vector2i,b: Vector2i) -> Array:return [b] if b.x!=99 else []
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func edge(id: String,a: Array,b: Array,x:=1) -> Dictionary:
	return {"id":id,"map":a[0],"target_map":b[0],"component":a,"target_component":b,"cell":[x,1],"kind":"reference"}
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	var nav:=OpenNavigation.new()
	var graph:={"a":[edge("ab",["a",1],["b",1])],"b":[edge("bc",["b",2],["c",1])]}
	expect(Planner.plan(graph,"a","c",Vector2i.ZERO,nav).is_empty(),"disconnected components in same map do not join")
	graph.b[0].component=["b",1]
	var path:=Planner.plan(graph,"a","c",Vector2i.ZERO,nav)
	expect(path.size()==2 and path[0].id=="ab" and path[1].id=="bc","connected components produce ordered route")
	graph.a[0].cell=[99,1]
	expect(Planner.plan(graph,"a","c",Vector2i.ZERO,nav).is_empty(),"unreachable first door refused")
	graph.a.append(edge("ac",["a",2],["c",1],2))
	expect(Planner.plan(graph,"a","c",Vector2i.ZERO,nav)[0].id=="ac","reachable alternative chosen")
	expect(Planner.plan(graph,"a","a",Vector2i.ZERO,nav).is_empty(),"same-map request avoids exit")
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-routes-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"routes","name":"远行验收","gender":"男","job":"战士"});app.world.paused=true
	var targets: Dictionary={}
	for q in EditionRules.Story.data().quests:
		for o in q.objectives:
			if o.type=="visit":targets[o.map]=true
			if o.type=="kill":
				for id in o.maps:targets[id]=true
	var routes: Dictionary={}
	for target in targets:
		path=Planner.plan(app.resources.connections.by_map,"0",target,app.world.player.cell,app.world.navigation)
		expect(not path.is_empty(),"world route exists to "+target)
		if path.is_empty():continue
		routes[target]=path.map(func(r):return r.id)
		expect(path[0].map=="0" and path.back().target_map==target,"route endpoint "+target)
		for i in range(path.size()-1):expect(path[i].target_component==path[i+1].component,"component continuity "+target)
	var gold: int=app.rules.state.gold;var start: Vector2i=app.world.player.cell
	app.show_story_route("d024");await settle()
	expect(app.rules.state.gold==gold and app.world.player.cell==start,"preview does not move or spend")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"route panel fits minimum window")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/routes.png")
	var report:={"checks":checks,"failures":failures,"routes":routes,"scope":"component graph, current real-map first-leg pathfinding and route preview; future legs are not physically traversed"}
	FileAccess.open("res://../artifacts/world-story/routes-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"checks":checks,"failures":failures,"targets":targets.size()}));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
