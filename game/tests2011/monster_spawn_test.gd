extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move,true)
	var press:=InputEventMouseButton.new();press.position=point;press.global_position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
	var release:=press.duplicate();release.pressed=false;root.push_input(release,true)
	await settle()
func find_button(node: Node,prefix: String) -> BaseButton:
	if node is BaseButton and str(node.text).begins_with(prefix):return node
	for child in node.get_children():
		var found:=find_button(child,prefix)
		if found!=null:return found
	return null
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-monsters-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"monster-test","name":"刷新核查","gender":"男","job":"战士"})
	var data:=EditionRegion.data()
	for name in data.monsters:
		var spec: Dictionary=data.monsters[name]
		var fixture:={"runtime_id":"fixture","name":name,"interval":10}
		var e:=EditionRegion.entity_from(fixture,spec,"fixture",0,Vector2i.ZERO,0)
		expect(e.level==spec.raw.lvl and e.max_hp==spec.raw.hp and e.mp==spec.raw.mp,"source level/HP/MP "+name)
		expect(e.dc==spec.raw.dc and e.dc_max==spec.raw.dcMax and e.ac==spec.raw.ac and e.mac==spec.raw.mac,"source attack/defense "+name)
		expect(e.reference_stats==spec.raw and e.reference_stats.size()==26,"all original fields retained "+name)
		expect(e.walk_ms==spec.runtime_stats.walk_ms and e.attack_ms==spec.runtime_stats.attack_ms and e.walk_step==spec.runtime_stats.walk_step and e.walk_wait_ms==spec.runtime_stats.walk_wait_ms,"source initialization defaults "+name)
	for row in data.spawns:
		var period:=float(row.interval if row.interval>0 else 10)*60
		expect(EditionRegion.next_refresh(period-1,period)==period,"near-end kill waits for batch boundary "+row.runtime_id)
		expect(EditionRegion.next_refresh(period+1,period)==period*2,"next batch after current boundary "+row.runtime_id)
	var index:=-1
	for i in range(data.spawns.size()):
		if data.spawns[i].name=="沃玛教主" and data.spawns[i].status=="enabled":index=i;break
	expect(index>=0,"reference Woma boss has an enabled spawn")
	var source: Dictionary=data.spawns[index];var point: Array=data.populations[str(source.mapName).to_lower()].filter(func(p):return int(p[0])==index)[0]
	var mid: String=str(source.mapName).to_lower();var cell:=Vector2i(point[2],point[3]);var id:="region:%d:%d"%[index,int(point[1])]
	app.enter_map(mid,cell);app.world.paused=false
	var boss: Dictionary=app.world.entities.filter(func(e):return e.id==id)[0]
	expect(boss.level==60 and boss.max_hp==2200 and boss.respawn_seconds==10800,"Woma boss retains reference values")
	expect(app.world.labels.title(boss)=="沃玛教主 Lv.60","display uses source level")
	var period:=float(boss.respawn_seconds);app.elapsed=period-1;app.world.elapsed=app.elapsed
	var reward_fixture:=boss.duplicate(true);reward_fixture.drops=[]
	expect(app.rules.reward_kill("boss-cycle",boss.species,reward_fixture,app.elapsed),"kill transaction commits")
	boss.hp=0;boss.respawn=float(app.rules.state.regional_deaths[id])
	expect(boss.respawn==period and app.rules.state.time==period-1,"deadline belongs to spawn cycle and persists with world time")
	app.world.elapsed=app.elapsed;boss.motion_time=app.elapsed
	app.region.refresh_left=0;app.region.populate(app.world,app.rules,0,period-0.1)
	expect(not app.world.entities.any(func(e):return e.id==id and e.hp>0),"no early boss respawn")
	var clock_before: float=app.elapsed;app.world.paused=true;app._process(30)
	expect(app.elapsed==clock_before,"pause freezes spawn clock");app.world.paused=false
	app.elapsed=period;app.world.elapsed=period;app.region.refresh_left=0;app.region.populate(app.world,app.rules,0,period)
	var positions: Array=data.populations[mid].filter(func(p):return int(p[0])==index)
	# A new in-range position may lie outside the current viewport; visit it.
	var renewed: Vector2i=app.region.spawn_cell(app.world,source,positions[0],id,period)
	app.world.player.reset(renewed);app.region.refresh_left=0;app.region.populate(app.world,app.rules,0,period)
	var alive: Array=app.world.entities.filter(func(e):return e.id==id and e.hp>0)
	expect(alive.size()==1,"one live boss restored at the refresh boundary")
	if not alive.is_empty():
		boss=alive[0];expect(boss.hp==2200 and boss.generation==int(period),"fresh boss stats and generation")
		expect(absi(boss.cell[0]-int(source.x))<=int(source.range) and absi(boss.cell[1]-int(source.y))<=int(source.range),"renewed boss stays within source radius")
	app.region.refresh_left=0;app.region.populate(app.world,app.rules,0,period+0.5)
	expect(app.world.entities.filter(func(e):return e.id==id and e.hp>0).size()==1,"repeat scheduler tick cannot duplicate boss")
	app.rules.state=app.store.load_world("monster-test");app.elapsed=float(app.rules.state.time)
	app.region.remembered.clear();app.enter_map(mid,cell)
	expect(not app.world.entities.any(func(e):return e.id==id and e.hp>0),"reloaded saved kill still waits; no offline time advance")
	var saved_entities: Array=app.world.entities.duplicate()
	for fps in [30,60,120]:
		var fixture:=boss.duplicate(true);fixture.id="movement-fixture";fixture.hp=2200;fixture.passive=true;fixture.aggro=false;fixture.motion="stand";fixture.walk_ms=800;fixture.walk_step=1;fixture.walk_wait_ms=1000
		var start: Vector2i=app.world.actors.landing(cell)
		var target:=start
		for direction in ClassicNavigation.DIRECTIONS:
			if app.world.navigation.can_step(start,start+direction) and app.world.navigation.can_step(start+direction,start+direction*2):target=start+direction*2;break
		expect(target!=start,"two-step walk fixture exists")
		fixture.cell=[start.x,start.y];fixture.origin=fixture.cell.duplicate();app.world.entities=[fixture];app.world.actors.reset()
		var motion: ClassicPlayer=app.world.actors.mover(fixture);app.world.actors.brains[fixture.id].wait=10000
		motion.go_to(target)
		for tick in range(int(1.3*fps)):app.world.actors.update(1.0/fps,[])
		expect(motion.completed_steps==1 and motion.progress==1,"source walk burst pauses after one step at %d FPS"%fps)
	app.world.entities=saved_entities;app.world.actors.reset()
	app.show_map_info();await settle()
	var b:=find_button(app.windows,"BOSS ·")
	expect(b!=null,"map page exposes boss catalog")
	if b!=null:await click(b.get_global_rect().get_center())
	b=find_button(app.windows,"沃玛教主 ·")
	expect(b!=null,"boss catalog includes reference boss")
	if b!=null:await click(b.get_global_rect().get_center())
	app._process(0);await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/monster-ai-0.9.7/boss-details.png")
	expect(app.resources.errors.is_empty(),"no resource errors in boss scene")
	var report:={"checks":checks,"failures":failures,"boss_map":mid,"boss_source":source,"resource_errors":app.resources.errors}
	FileAccess.open("res://../artifacts/monster-ai-0.9.7/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
