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
	app.store.path="/tmp/story-bosses-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"boss-story","name":"远征验收","gender":"男","job":"战士"});app.world.paused=true
	for q in Story.data().quests:
		if q.kind not in ["首领远征","石墓侧路调查","雷炎调查"] and q.id not in ["story_seal_scorpion","story_seal_boar","story_moon_square","story_moon_choice","story_moon_passages","story_island_corpse_depths","story_island_bull_mages","story_island_bull_generals","story_island_bull_priests","story_zuma_watch","story_zuma_archers","story_zuma_statues","story_pig_snakes","story_woma_flame","story_woma_dark","story_woma_guard","story_mine_recovery","story_valley_snakes","story_centipede_dark","story_seal_surface","story_woma_cave_entry","story_woma_cave_depths","story_incense_entry","story_incense_middle","story_incense_depths","story_zuma_rooms_a","story_zuma_rooms_b","story_demon_east","story_demon_west","story_demon_east_depths","story_demon_west_depths","story_demon_valley","story_demon_bloodroad","story_noreturn_entry","story_noreturn_depths","story_passages_bones","story_passages_dead","story_passages_insects","story_secret_passage"]:continue
		var o: Dictionary=q.objectives.filter(func(objective):return objective.type=="kill")[0];var objective_index: int=q.objectives.find(o);var mid: String=o.maps[0]
		var npc: Dictionary=app.rules.story_npc(q.start_npc)
		var next: Dictionary=app.rules.state.duplicate(true)
		for previous in q.requires:next.quests[previous]="done"
		expect(app.rules.apply(next,"boss_prerequisite_fixture"),"seed prior chapter "+q.id)
		expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])),"accept boss expedition "+q.id)
		for objective in q.objectives:
			if objective.type=="visit":
				expect(app.enter_map(objective.map),"load survey map before guard")
				app.world.paused=true
				expect(app.rules.save_location(objective.map,app.world.player.cell,app.elapsed),"record actual survey map")
		var point: Array=[]
		for row in EditionRegion.data().populations[mid]:
			if EditionRegion.data().spawns[int(row[0])].name==o.names[0]:point=row;break
		expect(not point.is_empty(),"real boss population exists")
		if point.is_empty():continue
		expect(app.enter_map(mid,Vector2i(point[2],point[3])+Vector2i(1,0)),"boss map loads "+mid)
		app.world.paused=true
		var boss: Dictionary={}
		for entity in app.world.entities:
			if entity.get("reference_name","")==o.names[0] and entity.get("hp",0)>0:boss=entity;break
		expect(not boss.is_empty(),"live runtime boss loaded "+o.names[0])
		if boss.is_empty():continue
		expect(app.world.navigation.walkable(app.world.player.cell),"player landing walkable")
		expect(str(int(boss.max_hp)) in Story.combat_brief(o),"task health description matches live boss")
		if o.names[0]=="黄泉教主":
			var probe: Dictionary=boss.duplicate(true)
			probe.hp=0;probe.motion_time=app.world.elapsed-2.0
			for direction in range(8):
				probe.direction=direction
				var frame: int=app.world.actor_frame(probe)
				expect(frame==2880+269+direction*10,"Huangquan corpse holds final death frame direction "+str(direction))
				expect(not app.resources.frame("mon15",frame).is_empty(),"Huangquan corpse PNG decodes")
		var original_hp: int=boss.hp
		app.store.db.query("PRAGMA query_only=ON;")
		app.apply_attack_hit(boss,{"damage":original_hp+100000})
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(boss.hp==original_hp and Story.progress(app.rules.state,q,objective_index)==0,"failed lethal hit keeps live boss and no quest credit")
		app.apply_attack_hit(boss,{"damage":original_hp+100000})
		expect(boss.hp==0 and Story.progress(app.rules.state,q,objective_index)==1,"real attack settlement completes kill objective "+q.id)
		if q.id=="story_dragon_trial":
			expect(not app.resources.frame("items",822).is_empty(),"quest scale icon available")
			expect(not Story.ready(app.rules.state,q) and not app.rules.state.inventory.has("dragon_story_scale"),"kill does not auto-pick quest token")
			expect(not app.rules.shop("dragon_story_scale",1),"quest token cannot be purchased")
			var drops: Array=app.rules.state.ground_loot.filter(func(loot):return loot.type=="dragon_story_scale")
			expect(drops.size()==1 and drops[0].map==mid,"exactly one token on actual boss map")
			if not drops.is_empty():
				var loot: Dictionary=drops[0];app.world.player.reset(Vector2i(loot.cell[0],loot.cell[1]))
				var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
				expect(not app.rules.pickup(loot.uid,mid,app.world.player.cell) and app.rules.state==before,"failed pickup preserves ground token")
				app.store.db.query("PRAGMA query_only=OFF;")
				expect(app.rules.pickup(loot.uid,mid,app.world.player.cell),"pick up dragon token")
				expect(not app.rules.pickup(loot.uid,mid,app.world.player.cell),"token cannot be picked twice")
			expect(Story.ready(app.rules.state,q),"kill plus pickup permits delivery")
		var kills: int=app.rules.state.kills
		app.apply_attack_hit(boss,{"damage":original_hp+100000})
		expect(app.rules.state.kills==kills and Story.progress(app.rules.state,q,objective_index)==1,"corpse cannot count again")
		expect(app.chat_history.any(func(line):return q.title in line and ("1/%d"%int(o.count)) in line),"committed progress visible in chat")
		for remaining in range(1,int(o.count)):
			var target: Dictionary={}
			for population in EditionRegion.data().populations[mid]:
				if EditionRegion.data().spawns[int(population[0])].name!=o.names[0]:continue
				if not app.enter_map(mid,Vector2i(population[2],population[3])+Vector2i(1,0)):continue
				app.world.paused=true
				for entity in app.world.entities:
					if entity.get("reference_name","")==o.names[0] and entity.get("hp",0)>0:target=entity;break
				if not target.is_empty():break
			if target.is_empty():
				for population in EditionRegion.data().populations[mid]:
					var source: Dictionary=EditionRegion.data().spawns[int(population[0])]
					if source.name!=o.names[0]:continue
					var entity_id: String="region:"+str(int(population[0]))+":"+str(int(population[1]))
					var deadline: float=app.rules.state.get("regional_deaths",{}).get(entity_id,0.0)
					if deadline<=0:continue
					app.elapsed=maxf(app.elapsed,deadline+0.1)
					var spawn: Vector2i=app.region.spawn_cell(app.world,source,population,entity_id,deadline)
					if not app.enter_map(mid,spawn+Vector2i(1,0)):continue
					app.world.paused=true
					for entity in app.world.entities:
						if entity.get("reference_name","")==o.names[0] and entity.get("hp",0)>0:target=entity;break
					if not target.is_empty():break
			expect(not target.is_empty(),"another distinct live target exists for multi-kill task")
			if target.is_empty():break
			app.apply_attack_hit(target,{"damage":int(target.hp)+100000})
			expect(Story.progress(app.rules.state,q,objective_index)==remaining+1,"each live target adds exactly one required kill")
		expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i(1,0)),"return NPC map loads")
		expect(app.rules.story_action(q.id,"submit",npc.id,app.world.metadata.id,app.world.player.cell),"submit after returning to live map "+q.id)
		expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","boss story persists")
	expect(app.enter_map("3"),"prepare permit route from Mongchon explicitly")
	var gold_before: int=app.rules.state.gold
	var map_before: String=app.world.metadata.id
	app.show_story_route(EditionFireDragon.MAP);await settle()
	expect(app.panel.window_id=="火龙神殿入口","story route directs to permit NPC")
	expect(app.world.metadata.id==map_before and app.rules.state.gold==gold_before,"route preview does not bypass permit or spend")
	var report:={"checks":checks,"failures":failures,"scope":"real maps, runtime spawned bosses and selected guards, main attack settlement, chat and return NPC submission; chapter prerequisites, direct map travel and lethal damage are test controlled, not balanced gameplay or route traversal"}
	FileAccess.open("res://../artifacts/world-story/boss-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
