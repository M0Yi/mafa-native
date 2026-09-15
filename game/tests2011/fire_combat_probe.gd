extends SceneTree
var app
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(1):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/fire-combat-probe-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var job:="战士"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-job="):job=arg.trim_prefix("--probe-job=")
	if job not in ["战士","法师","道士"]:quit(1);return
	var skill: String={"战士":"","法师":"lightning","道士":"talisman"}[job]
	app.start_character({"id":"probe","name":"战斗测量","gender":"男","job":job});app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.hp=1000;next.mp=560;next.gold=100000
	if not app.rules.apply(next,"level_and_budget_fixture"):printerr(app.rules.message);quit(1);return
	if not app.rules.shop("potion",99 if skill.is_empty() else 30):printerr(app.rules.message);quit(1);return
	if not skill.is_empty():
		var book:=""
		for key in EditionRules.ITEMS:
			if EditionRules.ITEMS[key].get("skill_book","")==skill:book=key;break
		if book.is_empty() or not app.rules.shop(book,1) or not app.rules.use_item(book):printerr("book learning failed: "+app.rules.message);quit(1);return
		if not app.rules.shop("mana",99):printerr(app.rules.message);quit(1);return
		if job=="道士" and not app.rules.shop("charm",99):printerr(app.rules.message);quit(1);return
	if not app.rules.shop("sword",1) or not app.rules.use_item("sword"):printerr(app.rules.message);quit(1);return
	app.enter_map(EditionFireDragon.MAP)
	var bosses: Array=app.world.entities.filter(func(e):return e.get("reference_name","")=="火龙教主")
	if bosses.is_empty():printerr("missing real boss");quit(1);return
	var boss: Dictionary=bosses[0];app.world.entities=[boss];app.selected=boss
	var motion: ClassicPlayer=app.world.actors.mover(boss)
	var initial_hp: int=boss.hp;var initial_attack: int=app.rules.attack();var start: float=app.elapsed
	app.world.hide();app.world.paused=false;app.world.player_alive=true
	var landing:=Vector2i(-1,-1)
	for direction in ClassicNavigation.DIRECTIONS:
		if app.world.navigation.can_step(motion.cell,motion.cell+direction):landing=motion.cell+direction;break
	if landing.x<0:printerr("boss has no melee neighbor");quit(1);return
	app.world.player.reset(landing)
	print(JSON.stringify({"player":landing,"boss":motion.cell,"safe":EditionRegion.safe(app.world.metadata.id,landing),"paused":app.world.paused,"player_alive":app.world.player_alive}))
	var potions:=0;var mana_used:=0;var casts:=0;var swings:=0;var dodges:=0;var rethink:=0.0;var warning_at:=-1.0
	for frame in range(30*1200):
		if boss.hp<=0 or app.rules.state.hp<=0:break
		app.elapsed+=1.0/30;app.fight_timer=maxf(0,app.fight_timer-1.0/30);app.resolve_attack()
		if app.rules.state.hp<app.rules.max_hp()*0.65 and app.elapsed>=app.gameplay.potion_ready:
			if app.gameplay.use_type("potion"):potions+=1
		elif not skill.is_empty() and app.rules.state.mp<app.rules.max_mp()*0.5 and app.elapsed>=app.gameplay.potion_ready:
			if app.gameplay.use_type("mana"):mana_used+=1
		app.gameplay.update_spell_effects()
		if boss.has("dragon_warning"):
			if warning_at!=float(boss.dragon_warning.at):
				warning_at=float(boss.dragon_warning.at)
				var area: Array[Vector2i]=EditionDragonAttack.area(app.world,boss.dragon_warning.cell)
				var choices: Array[Vector2i]=[]
				for y in range(-3,4):
					for x in range(-3,4):
						var at: Vector2i=app.world.player.cell+Vector2i(x,y)
						if at not in area and app.world.navigation.walkable(at):choices.append(at)
				choices.sort_custom(func(a,b):return a.distance_squared_to(app.world.player.cell)<b.distance_squared_to(app.world.player.cell))
				for at in choices:
					if app.world.approach(at):dodges+=1;break
		else:
			if app.elapsed>=rethink:
				rethink=app.elapsed+0.5
				if Vector2(motion.cell-app.world.player.cell).length()>=1.5:app.world.approach(motion.cell)
			if not skill.is_empty() and app.fight_timer<=0 and app.elapsed>=float(app.rules.state.get("skill_ready",{}).get(skill,0)):
				if app.gameplay.cast(skill):casts+=1
			if app.fight_timer<=0:
				app.attack_target()
				if not app.pending_attack.is_empty():swings+=1
		app.world.update_world(1.0/30,Vector2(1280,800),false,false)
		if frame%1800==0:print(JSON.stringify({"seconds":app.elapsed-start,"boss_hp":boss.hp,"player_hp":app.rules.state.hp,"potions":potions}))
	var report:={"job":job,"skill":skill,"casts":casts,"mana_potions":mana_used,"final_mp":app.rules.state.mp,"remaining_charms":app.rules.state.inventory.get("charm",0),"boss_initial_hp":initial_hp,"boss_final_hp":boss.hp,"player_hp":app.rules.state.hp,"seconds":app.elapsed-start,"potions_used":potions,"swings":swings,"dodges":dodges,"attack":initial_attack,"outcome":"boss_defeated" if boss.hp<=0 else "player_dead" if app.rules.state.hp<=0 else "time_limit","scope":"level60, purchased sword; warrior buys99 red, casters30 red99 blue and Taoist99 charms, starting inventory retained; spells learned via purchased book and actual consumption/cooldowns; scripted immediate dodge and melee fallback, starting position/budget fixtures, guards removed; not full expedition acceptance"}
	FileAccess.open("res://../artifacts/world-story/fire-combat-probe-"+(skill if not skill.is_empty() else "warrior")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit()
