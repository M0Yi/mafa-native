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
	app.store.path="/tmp/fire-delivery-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=Story.quest("story_dragon_trial")
	for picked in [true,false]:
		var profile: Dictionary={"id":"delivery-"+str(picked),"name":"远征交付","gender":"男","job":"战士"}
		app.start_character(profile);app.world.hide();app.world.paused=false
		var npc: Dictionary=app.rules.story_npc(q.start_npc)
		var next: Dictionary=app.rules.state.duplicate(true);next.gold=5000;next.quests.story_dragon_survey="done"
		expect(app.rules.apply(next,"expedition_prerequisite_fixture"),"seed expedition prerequisite")
		app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN)
		expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,app.world.player.cell),"accept at entrance")
		expect(app.fire_dragon.buy_permit() and app.fire_dragon.enter(),"paid expedition starts")
		expect(q.title in app.pending_message and "火龙教主" in app.pending_message,"entry describes accepted boss expedition")
		var population: Array=[]
		for row in EditionRegion.data().populations[EditionFireDragon.MAP]:
			if EditionRegion.data().spawns[int(row[0])].name=="火龙教主":population=row;break
		expect(not population.is_empty(),"actual boss population exists")
		if population.is_empty():continue
		app.enter_map(EditionFireDragon.MAP,Vector2i(population[2],population[3])+Vector2i.RIGHT)
		var bosses: Array=app.world.entities.filter(func(e):return e.get("reference_name","")=="火龙教主" and e.get("hp",0)>0)
		expect(not bosses.is_empty(),"actual boss loads")
		if bosses.is_empty():continue
		app.apply_attack_hit(bosses[0],{"damage":int(bosses[0].hp)+100000})
		var drops: Array=app.rules.state.ground_loot.filter(func(row):return row.type=="dragon_story_scale")
		expect(drops.size()==1,"one scale settles on ground")
		if drops.is_empty():continue
		var loot: Dictionary=drops[0]
		if picked:
			app.world.player.reset(Vector2i(loot.cell[0],loot.cell[1]))
			expect(app.rules.pickup(loot.uid,EditionFireDragon.MAP,app.world.player.cell),"pickup before timeout")
		app.elapsed=float(app.fire_dragon.state().deadline)
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;");app.fire_dragon.update();app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.world.metadata.id==EditionFireDragon.MAP and app.rules.state==before,"failed timeout return preserves material and task")
		app.fire_dragon.update()
		expect(app.world.metadata.id=="3" and not app.fire_dragon.state().active,"timeout retry returns safely")
		app.start_character(profile);app.world.hide();app.world.paused=false
		expect(app.world.metadata.id=="3" and Story.progress(app.rules.state,q,0)==1,"reload retains return map and boss credit")
		if not picked:
			expect(app.rules.state.ground_loot.any(func(row):return row.uid==loot.uid),"unpicked scale survives return and reload on ground")
			expect(not Story.ready(app.rules.state,q),"unpicked token cannot satisfy delivery")
			app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN)
			expect(app.fire_dragon.buy_permit() and app.fire_dragon.enter(),"fresh permit allows recovery trip")
			app.enter_map(EditionFireDragon.MAP,Vector2i(loot.cell[0],loot.cell[1]))
			expect(app.rules.pickup(loot.uid,EditionFireDragon.MAP,app.world.player.cell),"old ground token recoverable without another kill")
			app.world.player.reset(EditionFireDragon.LANDING)
			expect(app.fire_dragon.leave(),"recovered material returns with guide")
		expect(app.rules.state.inventory.get("dragon_story_scale",0)==1 and Story.ready(app.rules.state,q),"bag credential and kill jointly ready")
		expect("条件已满足" in app.fire_dragon.objective_text(),"picked credential changes briefing to delivery")
		app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN)
		expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell),"returned expedition delivers")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.state.inventory.has("dragon_story_scale"),"delivery consumes one recovered credential")
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==before,"no repeated reward after return")
		app.start_character(profile);app.world.paused=false
		expect(app.rules.state.quests[q.id]=="done" and app.rules.state.quest_receipts.has(q.id),"final receipt survives reload")
	var report:={"checks":checks,"failures":failures,"scope":"real boss lethal settlement, paid entry, ground pickup, failed timeout retry, database reload, recovery trip and delivery; prerequisite, position and lethal damage fixtures, not full combat or physical travel"}
	FileAccess.open("res://../artifacts/world-story/fire-delivery-resume-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
