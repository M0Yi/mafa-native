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
	for i in range(4):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-dark-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"dark","name":"暗殿验收","gender":"男","job":"战士"});app.world.paused=true
	var q: Dictionary=Story.quest("story_dark_records");var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_dark_entry="done";app.rules.apply(next,"dark_prerequisite_fixture")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept investigation")
	expect(app.enter_map("m001"),"load actual dark hall");app.world.paused=true
	for i in range(q.objectives.size()):
		var o: Dictionary=q.objectives[i]
		var target: Dictionary={}
		for entity in app.world.entities:
			if entity.get("reference_name")==o.names[0] and entity.get("hp",0)>0:target=entity;break
		expect(not target.is_empty(),"live variant exists "+o.names[0])
		if target.is_empty():continue
		var raw: Dictionary=EditionRegion.data().monsters[o.names[0]].raw
		expect(int(target.mac)==int(raw.mac) and int(target.ac)==int(raw.ac) and int(target.damage)==int(raw.dcMax),"actual variant retains defense and attack configuration")
		expect("攻击上限 %d · 物防 %d · 魔防 %d"%[int(raw.dcMax),int(raw.ac),int(raw.mac)] in Story.combat_brief(o),"task combat briefing matches actual target stats")
		var probe: Dictionary=app.rules.state.duplicate(true)
		expect(not Story.observe(probe,"kill",{"name":o.names[0].trim_suffix("1"),"map":"m001"}),"base monster does not substitute for variant")
		expect(not Story.observe(probe,"kill",{"name":o.names[0],"map":"d024"}),"same name outside hall rejected")
		var credit_before: int=Story.progress(app.rules.state,q,i)
		for strike in [{"damage":20,"skill":"fireball"},{"damage":20,"skill":""}]:
			var health_before: int=target.hp
			var protection: int=int(target.mac) if strike.skill=="fireball" else int(target.ac)
			app.apply_attack_hit(target,strike)
			expect(health_before-int(target.hp)==maxi(1,20-protection),"actual nonlethal damage uses matching defense for "+str(strike.skill)+" on "+str(o.names[0]))
			expect(Story.progress(app.rules.state,q,i)==credit_before,"nonlethal hit never grants kill objective")
		var before: Dictionary=app.rules.state.duplicate(true);var hp: int=target.hp
		app.store.db.query("PRAGMA query_only=ON;");app.apply_attack_hit(target,{"damage":hp+1,"skill":"","kind":"physical"})
		expect(target.hp==hp and app.rules.state==before,"failed kill leaves living target and no credit")
		app.store.db.query("PRAGMA query_only=OFF;");app.apply_attack_hit(target,{"damage":hp+1,"skill":"","kind":"physical"})
		expect(target.hp==0 and Story.progress(app.rules.state,q,i)==1,"actual variant credits corresponding objective")
		if i==0:expect(Story.progress(app.rules.state,q,1)==0 and not Story.ready(app.rules.state,q),"first variant does not complete second objective")
		expect(app.store.load_world(app.rules.character.id).story_progress[q.id][str(i)]==1,"variant progress persists")
	expect(Story.ready(app.rules.state,q),"both distinct encounters required")
	expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i(1,0)),"return to actual elder map");app.world.paused=true
	var planner=preload("res://scripts/edition2011/story_routes.gd")
	var components: Array=planner.npc_components(app.resources,npc)
	expect(not components.is_empty(),"elder has reachable arrival component")
	var route: Array=planner.plan(app.resources.connections.by_map,npc.map,npc.map,app.world.player.cell,app.world.navigation,components)
	expect(not route.is_empty(),"isolated current component can route around to elder")
	if not route.is_empty():
		var last: Dictionary=route.back()
		app.enter_map(npc.map,Vector2i(last.target_cell[0],last.target_cell[1]));app.world.paused=true
		var reached:=false
		for direction in ClassicNavigation.DIRECTIONS:
			var at: Vector2i=Vector2i(npc.cell[0],npc.cell[1])+direction
			if not app.world.navigation.path(app.world.player.cell,at).is_empty() or app.world.player.cell==at:
				app.world.player.reset(at);reached=true;break
		expect(reached,"route arrival can approach elder without crossing walls")
	expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell),"submit records to elder: "+app.rules.message+" at "+str(app.world.player.cell))
	var report:={"checks":checks,"failures":failures,"scope":"actual dark hall monster variants, independent objectives, failed kill rollback and elder return; prerequisites, direct travel and lethal damage controlled"}
	FileAccess.open("res://../artifacts/world-story/dark-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
