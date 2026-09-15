extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	seed(10733)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/centipede-quest-combat-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"expedition","name":"虫洞远征","gender":"男","job":"战士"})
	var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.gold=100000;next.quests.story_centipede_passage="done";app.rules.apply(next,"journey_level_budget_fixture")
	next=app.rules.state.duplicate(true);next.hp=app.rules.max_hp();app.rules.apply(next,"full_health_fixture")
	expect(app.rules.shop("sword",1) and app.rules.use_item("sword") and app.rules.shop("potion",20),"buy real weapon and medicine")
	var quest: Dictionary=EditionRules.Story.quest("story_touch_dragon");var npc: Dictionary=app.rules.story_npc(quest.start_npc)
	app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN)
	expect(app.rules.story_action(quest.id,"accept",npc.id,npc.map,app.world.player.cell),"accept expedition through rules at NPC")
	app.enter_map("d606",Vector2i(69,153));var boss: Dictionary={}
	for entity in app.world.entities:
		if entity.get("reference_name","")=="触龙神":boss=entity;break
	expect(not boss.is_empty(),"original regional boss present")
	if boss.is_empty():quit(1);return
	app.world.entities=[boss];app.world.hide();app.world.paused=false
	var motion: ClassicPlayer=app.world.actors.mover(boss)
	var neighbor:=Vector2i(-1,-1)
	for direction in ClassicNavigation.DIRECTIONS:
		if app.world.navigation.can_step(motion.cell,motion.cell+direction):neighbor=motion.cell+direction;break
	expect(neighbor.x>=0,"boss has melee approach")
	app.world.player.reset(neighbor)
	var hp_start: int=boss.hp;var start: float=app.elapsed;var seen: Dictionary={};var used:=0
	var before_inventory: Dictionary=app.rules.state.inventory.duplicate(true)
	var gold_before: int=app.rules.state.gold
	expect(app.rules.state.get("ground_loot",[]).is_empty(),"isolated fresh world has no prior loot")
	for frame in range(60*180):
		if boss.hp<=0 or app.rules.state.hp<=0:break
		app.elapsed+=1.0/60;app.fight_timer=maxf(0,app.fight_timer-1.0/60);app.resolve_attack()
		app.world.player_stoned=app.rules.stoned(app.elapsed);app.world.player_alive=app.rules.state.hp>0
		if app.rules.state.hp<app.rules.max_hp()*0.6 and app.elapsed>=app.gameplay.potion_ready:
			if app.gameplay.use_type("potion"):used+=1
		app.attack_target()
		app.world.update_world(1.0/60,Vector2(1280,800),false,false);app.gameplay.update(1.0/60)
		seen[boss.get("centipede_phase","")]=true
	expect(seen.has("hidden") and seen.has("emerging") and seen.has("exposed"),"battle includes real emergence lifecycle")
	expect(boss.hp<=0 and app.rules.state.hp>0,"normal attacks defeat boss while alive")
	expect(EditionRules.Story.ready(app.rules.state,quest),"actual kill satisfies expedition objective")
	var loot: Array=app.rules.state.get("ground_loot",[]).filter(func(row):return row.map=="d606")
	expect(not loot.is_empty(),"real boss drops are on ground")
	before_inventory.potion-=used
	if before_inventory.potion==0:before_inventory.erase("potion")
	expect(app.rules.state.inventory==before_inventory and app.rules.state.gold==gold_before,"kill does not deposit ground rewards in inventory or wallet")
	var deposited: Dictionary=app.rules.state.duplicate(true);var hp: int=boss.hp
	app.apply_attack_hit(boss,{"damage":9999})
	expect(boss.hp==hp and app.rules.state==deposited,"dead boss cannot award twice")
	if not loot.is_empty():
		var chosen: Dictionary=loot[0];app.world.player.reset(Vector2i(chosen.cell[0],chosen.cell[1]))
		expect(app.gameplay.pickup(chosen),"ground drop requires explicit pickup")
		var after_pickup: Dictionary=app.rules.state.duplicate(true)
		expect(not app.gameplay.pickup(chosen) and app.rules.state==after_pickup,"same ground drop cannot be collected twice")
	app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN)
	expect(app.rules.story_action(quest.id,"submit",npc.id,npc.map,app.world.player.cell),"return position fixture permits actual task delivery")
	expect(app.store.load_world(app.rules.character.id).quests[quest.id]=="done","completed expedition saved")
	var report:={"checks":checks,"failures":failures,"seconds":app.elapsed-start,"boss_initial_hp":hp_start,"boss_final_hp":boss.hp,"player_hp":app.rules.state.hp,"potion_count":used,"observed_phases":seen.keys(),"ground_stacks":loot.size(),"scope":"real boss stats, normal player attacks, poison/stone/gameplay updates, task kill and delivery, real loot and explicit pickup; level60/budget/prerequisite/positions fixtures, other monsters excluded, no natural route or physical input"}
	FileAccess.open("res://../artifacts/world-story/centipede-quest-combat-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
