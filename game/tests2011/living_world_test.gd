extends SceneTree
var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-living-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.sound_started.connect(func(id):sounds.append(id))
	var profile:={"id":"living","name":"村庄旅人","job":"战士","gender":"男"}
	app.start_character(profile)
	expect(app.rules.state.map=="0" and app.rules.state.cell==[289,618],"new character starts at village")
	var old: Dictionary=app.rules.state.duplicate(true);old.erase("village_entry_version");old.map="3";old.cell=[10,20];old.gold=321
	expect(app.store.commit(profile.id,old,"old_fixture"),"create old-location fixture")
	var item_ids: Array=old.items.map(func(i):return i.uid)
	expect(app.rules.attach(profile),"old character gets one-time village entry")
	expect(app.rules.state.map=="0" and app.rules.state.cell==[289,618] and app.rules.state.gold==321 and app.rules.state.items.map(func(i):return i.uid)==item_ids,"location migration preserves wealth and item identity")
	expect(app.rules.save_location("3",Vector2i(10,20),5) and app.rules.attach(profile) and app.rules.state.map=="3","later saved location is restored instead of resetting every login")
	app.enter_map("0",EditionVillage.SPAWN)
	var travelers: Array=app.world.entities.filter(func(e):return e.kind=="traveler")
	expect(travelers.size()==4,"four village travelers")
	for entity in travelers:expect(Vector2(entity.cell[0],entity.cell[1]).distance_to(Vector2(EditionVillage.SPAWN))<12,"travelers spawn near village")
	expect(app.rules.recruit_hero("道士"),"hero recruited")
	var existing: Dictionary=app.world.entities[0];app.spawn_hero()
	expect(app.world.entities[0]==existing,"summoning does not recreate scene")
	var hero: Dictionary=app.world.entities.filter(func(e):return e.kind=="hero")[0]
	expect(app.world.actors.anchor(hero).distance_to(app.world.player.anchor)<160,"hero appears near player, not remote service spot")
	var walked:=false
	for fps in [30,60,120]:
		var smooth:=true;var solid:=true;var visible:=true
		for step in range(fps*10):
			var before: Dictionary={}
			for entity in travelers:before[entity.id]=app.world.actors.anchor(entity)
			app.world.update_world(1.0/fps,Vector2(1280,800),false)
			for entity in travelers:
				var motion: ClassicPlayer=app.world.actors.mover(entity)
				var displacement: float=before[entity.id].distance_to(motion.anchor)
				smooth=smooth and displacement<=400.0/fps;walked=walked or displacement>0.01
				solid=solid and app.world.navigation.walkable(motion.cell) and (motion.progress>=1 or app.world.navigation.can_step(motion.cell,motion.destination))
				var frame: Rect2=app.resources.frame_bounds("hum",app.world.actor_frame(entity));visible=visible and frame.size.x>1 and frame.size.y>1
			expect(smooth,"no whole-cell jumps at "+str(fps)+" FPS");expect(solid,"no wall/corner crossing");expect(visible,"human direction frames are nonblank")
	expect(walked,"travelers actually move")
	var before: Vector2=app.world.actors.anchor(travelers[0]);var time: float=app.world.elapsed
	app.world.paused=true;app.world.update_world(20,Vector2(1280,800),false)
	expect(app.world.actors.anchor(travelers[0])==before and app.world.elapsed==time,"pause freezes AI and clocks")
	app.world.paused=false
	var destination: Vector2i=app.world.actors.landing(EditionVillage.SPAWN+Vector2i(8,6));app.world.player.reset(destination)
	var distance: float=app.world.actors.anchor(hero).distance_to(app.world.player.anchor)
	for i in range(60*10):app.world.update_world(1.0/60,Vector2(1280,800),false)
	expect(app.world.actors.anchor(hero).distance_to(app.world.player.anchor)<distance,"hero follows by path")
	var label: Dictionary=app.world.labels.layout(hero)
	expect(app.world.pick_entity(label.name_rect.get_center()).get("id")==hero.id,"moving hero name and hit projection agree")
	for species in EditionCreatures.PROFILES:
		var spec: Dictionary=EditionCreatures.PROFILES[species]
		for action in spec.actions.values():
			for dir in range(8):
				for frame in range(int(action.count)):
					var index:=int(spec.base)+int(action.start)+dir*(int(action.count)+int(action.skip))+frame
					expect(app.resources.frame_bounds(spec.bank,index).size.x>1,"monster action frame nonblank: "+species+" "+str(index))
		var monster: Dictionary=app.world.entities.filter(func(e):return e.get("species")==species)[0]
		app.world.player.reset(Vector2i(monster.cell[0],monster.cell[1]));sounds.clear()
		for event in ["idle","attack","hurt","die"]:app.world.actors.sound(monster,event)
		for offset in [1,2,4,5]:expect(200+int(spec.appearance)*10+offset in sounds,"distinct monster event sound "+species+str(offset))
	# A cancelled attack must not deliver its deferred strike.
	var chicken: Dictionary=app.world.entities.filter(func(e):return e.get("species")=="village_chicken")[0]
	app.world.player.reset(Vector2i(chicken.cell[0],chicken.cell[1]));chicken.motion="attack";chicken.motion_time=app.world.elapsed;chicken.strike_done=false
	var hp: int=app.rules.state.hp;chicken.motion="hurt"
	for i in range(20):app.world.update_world(1.0/60,Vector2(1280,800),false)
	expect(app.rules.state.hp==hp,"hurt cancels pending monster strike")
	chicken.motion="attack";chicken.motion_time=app.world.elapsed;chicken.strike_done=false
	for i in range(30):app.world.update_world(1.0/60,Vector2(1280,800),false)
	expect(app.rules.state.hp==hp-1,"monster attack damage once per action")
	app.pending_attack={"id":chicken.id,"at":app.elapsed+5}
	app.world.monster_hit.emit(chicken,app.rules.state.hp)
	expect(app.rules.state.hp==0 and app.pending_attack.is_empty(),"death cancels pending player damage")
	expect(app.save_world(),"dead state saved before automatic return")
	app.start_character(profile)
	expect(app.death_return_at>app.elapsed,"loading a dead character schedules village recovery")
	app._process(1.1)
	expect(app.rules.state.hp==app.rules.max_hp() and app.world.player.cell==EditionVillage.SPAWN,"death resumes at village with health restored")
	app.enter_map("0")
	expect(app.world.player.cell==EditionVillage.SPAWN,"default first-map entry uses novice village")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/monster-sounds.json"));var decoded: Dictionary={}
	for entry in catalog.entries:
		for event in entry.events.values():
			if event.status=="available" and not decoded.has(event.file):decoded[event.file]=true;expect(app.resources.sound(event.file)!=null,"catalog WAV decodes: "+event.file)
	expect(app.resources.errors.is_empty(),"all runtime animation/audio resources readable")
	var result:={"checks":checks,"failures":failures,"decoded_wavs":decoded.size()}
	FileAccess.open("res://../artifacts/living-village-0.9.0/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
