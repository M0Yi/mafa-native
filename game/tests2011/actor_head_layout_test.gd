extends SceneTree
var app
var failures: Array=[]
var checks:=0
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func settle() -> void:
	for i in range(6):await process_frame
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/actor-head-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"heads","name":"头顶检查","job":"战士","gender":"女"})
	var actors: Array=app.world.entities.filter(func(e):return e.kind in ["npc","traveler","monster"])
	for density in [1.0,2.0]:
		app.world.display_density=density
		for entity in actors:
			var info: Dictionary=app.world.labels.layout(entity)
			check(absf(info.name_rect.get_center().x-info.head.x)<=0.51,"name shares head center "+entity.id)
			check(info.name_rect.end.y<info.head.y,"nickname above visible head "+entity.id)
			if info.health_rect.has_area():
				check(info.health_rect.end.y<info.name_rect.position.y,"bar above name "+entity.id)
				check(absf(info.health_rect.get_center().x-info.head.x)<=0.51,"health shares head center "+entity.id)
			var before: Rect2=info.name_rect
			app.world.elapsed+=0.15
			check(app.world.labels.layout(entity).name_rect==before,"idle label does not bob "+entity.id)
	app.world.display_density=1
	var traveler: Dictionary=actors.filter(func(e):return e.kind=="traveler" and e.name=="青禾")[0]
	for direction in range(8):
		traveler.direction=direction
		check(app.world.actor_idle_bounds(traveler,true).size.x<app.world.actor_idle_bounds(traveler).size.x,"head excludes broad shadow direction "+str(direction))
	traveler.direction=6
	app.world.player.reset(Vector2i(traveler.cell[0]+1,traveler.cell[1]))
	app.world.update_world(0,Vector2(root.size),false);app.world.labels.queue_redraw();await settle();RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../artifacts/world-story/actor-head-layout.png")
	app.world.player.reset(EditionVillage.SPAWN)
	app.world.update_world(0,Vector2(root.size),false);app.world.labels.queue_redraw();await settle();RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../artifacts/world-story/npc-head-layout.png")
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"current village NPC/traveler/monster layout at two text densities, idle stability and eight traveler directions; native screenshot; isolated save"}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
