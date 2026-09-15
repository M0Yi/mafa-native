extends "res://tests2011/trap_population_test.gd"
func run() -> void:
	await open_app()
	app.enter_map("1",Vector2i(300,299));app.world.paused=false
	var candidates: Array=app.world.entities.filter(func(e):return e.has("spawn_id"))
	expect(not candidates.is_empty(),"natural spawn available")
	if candidates.is_empty():app.queue_free();await settle();quit(1);return
	var entity: Dictionary=candidates[0];var id: String=entity.id
	var index: int=int(entity.spawn_index)
	var source: Dictionary=EditionRegion.data().spawns[index]
	var original: Dictionary=source.duplicate(true)
	var cell:=Vector2i(entity.cell[0],entity.cell[1])
	source.x=cell.x;source.y=cell.y;source.range=0
	var next: Dictionary=app.rules.state.duplicate(true);next.level=100
	expect(app.rules.apply(next,"respawn_level_fixture"),"prepare reward capacity")
	expect(app.rules.reward_kill("retry-kill",entity.species,entity,10.0),"death persists reference deadline")
	var due: float=float(app.rules.state.regional_deaths[id])
	entity.hp=0;entity.respawn=due
	app.world.player.reset(cell)
	app.region.populate(app.world,app.rules,1.0,due-0.1)
	expect(not app.world.entities.any(func(e):return e.id==id and e.hp>0),"no early respawn")
	app.region.populate(app.world,app.rules,1.0,due)
	expect(app.region.blocked_until.get(id,0)==due+1.0,"occupied spawn retries in one second not whole period")
	var destination:=Vector2i(-1,-1)
	for direction in ClassicNavigation.DIRECTIONS:
		if app.world.navigation.can_step(cell,cell+direction):destination=cell+direction;break
	expect(destination.x>=0,"can release occupied spawn")
	app.world.player.reset(destination)
	app.region.populate(app.world,app.rules,1.0,due+1.0)
	expect(app.world.entities.filter(func(e):return e.id==id and e.hp>0).size()==1,"released spawn respawns once at retry deadline")
	app.region.populate(app.world,app.rules,1.0,due+2.0)
	expect(app.world.entities.filter(func(e):return e.id==id and e.hp>0).size()==1,"subsequent update does not duplicate")
	EditionRegion.catalog.spawns[index]=original
	var report={"checks":checks,"failures":failures,"deadline":due,"scope":"actual population/death transaction; zero-radius spawn/player occupancy fixture; not all boss maps"}
	FileAccess.open("res://../artifacts/world-story/respawn-retry-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
