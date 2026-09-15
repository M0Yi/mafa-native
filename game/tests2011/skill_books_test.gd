extends SceneTree
var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func book_for(id: String) -> String:
	for key in EditionRules.ITEMS:
		if EditionRules.ITEMS[key].get("skill_book","")==id:return key
	return ""
func reset_inventory() -> void:
	var next: Dictionary=app.rules.state.duplicate(true);next.items=[];next.inventory={};next.equipment={};next.warehouse={};next.gold=1000000;next.level=60;next.hp=500;next.mp=1000
	expect(app.rules.apply(next,"test_inventory"),"reset isolated inventory")
func find_book(n: Node,id: String):
	if n is EditionItemSlot and n.item.get("type")==id:return n
	for child in n.get_children():
		var found=find_book(child,id)
		if found!=null:return found
	return null
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-books-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"books","name":"技能书验收","gender":"男","job":"战士"});app.world.paused=false
	app.sound_started.connect(func(id):sounds.append(id))
	for id in EditionSkills.DEFINITIONS:
		var spec: Dictionary=EditionSkills.DEFINITIONS[id]
		reset_inventory();app.rules.character.job=spec.job
		app.gameplay.learn(id);expect(not app.rules.state.skills.has(id),"no book cannot learn "+id)
		var type:=book_for(id);expect(not type.is_empty(),"reference book exists "+id)
		if type.is_empty():continue
		expect(app.rules.shop(type,2),"purchase books "+id)
		var gold: int=app.rules.state.gold
		app.rules.character.job="法师" if spec.job!="法师" else "战士"
		expect(not app.rules.use_item(type),"wrong job refuses "+id);app.rules.character.job=spec.job
		app.rules.state.level=1;expect(not app.rules.use_item(type),"low level refuses "+id);app.rules.state.level=60
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.use_item(type),"write failure refuses book "+id)
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.state.inventory[type]==2 and not app.rules.state.skills.has(id),"failed learning preserves books "+id)
		expect(app.rules.use_item(type),"book learns "+id)
		expect(app.rules.state.gold==gold and app.rules.state.inventory[type]==1,"only one book consumed "+id)
		expect(not app.rules.use_item(type) and app.rules.state.inventory[type]==1,"repeat learning preserves book "+id)
		expect(app.store.load_world(app.rules.character.id).skills.has(id),"learning persisted "+id)
		if spec.get("passive",false):expect(app.rules.passive_bonus(id)>0 and id not in app.gameplay.usable_skills(),"passive works without cast key "+id)
	# A real mouse double-click learns the visible frame-zero book.
	reset_inventory();app.rules.character.job="法师"
	var next: Dictionary=app.rules.state.duplicate(true);next.skills.erase("fireball");app.rules.apply(next,"unlearn_fixture")
	app.rules.shop(book_for("fireball"),1);app.show_bag();await settle()
	var slot=find_book(app,book_for("fireball"));expect(slot!=null,"book visible in bag")
	if slot!=null:
		var event:=InputEventMouseButton.new();event.position=slot.get_global_rect().get_center();event.global_position=event.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.double_click=true;root.push_input(event,true)
		event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
		expect(app.rules.state.skills.has("fireball"),"actual mouse double-click learns")
	app.windows.close_all();app.enter_map("0",Vector2i(300,618));app.world.paused=false;app.elapsed+=50
	var ally:={"id":"ally","kind":"traveler","name":"云游客","cell":[301,618],"hp":250,"generation":0,"pk_points":0}
	var enemy:=ally.duplicate(true);enemy.id="enemy";enemy.name="敌方";enemy.pk_points=200
	var mob:={"kind":"monster","hp":1};var npc:={"kind":"npc","name":"商人"}
	next=app.rules.state.duplicate(true);next.party=["云游客"];next.guild={"members":["云游客"]};app.rules.apply(next,"relations")
	for mode in EditionCombat.MODES:
		expect(app.rules.set_attack_mode(mode),"mode saves "+mode)
		expect(EditionCombat.eligible(app.rules.state,mob) and not EditionCombat.eligible(app.rules.state,npc),"monsters allowed NPC protected "+mode)
		expect(EditionCombat.eligible(app.rules.state,ally)==(mode=="all"),"ally filtering "+mode)
		expect(EditionCombat.eligible(app.rules.state,enemy)==(mode!="peace"),"enemy filtering "+mode)
		expect(app.store.load_world(app.rules.character.id).attack_mode==mode,"mode persists "+mode)
	app.rules.set_attack_mode("all");app.world.entities=[enemy];app.selected=enemy;app.fight_timer=0;app.attack_target()
	app.rules.set_attack_mode("peace");app.elapsed+=1;app.resolve_attack();expect(enemy.hp==250,"mode rechecked at impact")
	app.rules.set_attack_mode("all");var gold: int=app.rules.state.gold
	app.apply_attack_hit(enemy,{"damage":50});expect(enemy.hp==200,"AI takes real damage")
	app.gameplay.sync_travelers()
	expect(enemy.hp==200 and app.store.load_world(app.rules.character.id).traveler_health.enemy.hp==200,"AI damage persists")
	app.apply_attack_hit(enemy,{"damage":1000});expect(enemy.hp==0 and app.rules.state.gold==gold,"AI defeat has no copied loot")
	app.elapsed+=29;app.gameplay.sync_travelers();expect(enemy.hp==0,"AI waits thirty seconds")
	app.elapsed+=1;app.gameplay.sync_travelers();expect(enemy.hp==250,"AI revives after thirty seconds")
	app.world.player.reset(EditionVillage.SPAWN);enemy.cell=[EditionVillage.SPAWN.x,EditionVillage.SPAWN.y];app.apply_attack_hit(enemy,{"damage":50});expect(enemy.hp==250,"safe area blocks direct impact")
	# Repeated identical pickups are separate scrollable chat records.
	app.world.player.reset(Vector2i(300,618));app.world.entities=[]
	app.append_chat("测试","[color=red]原样显示，不解释标签[/color]")
	for i in range(3):
		next=app.rules.state.duplicate(true);app.rules.add_ground(next,{"id":"loot","cell":[300,618]},"gold",1);app.rules.apply(next,"chat_loot")
		app.gameplay.pickup(app.rules.state.ground_loot.back())
	expect(app.chat_history.filter(func(x):return "拾取 金币 ×1" in x).size()==3,"identical pickups each logged")
	for i in range(205):app.append_chat("测试","记录 "+str(i))
	expect(app.chat_history.size()==200 and "204" in app.chat_history.back(),"chat bounded history retains latest")
	await settle();expect("204" in app.classic_hud.messages.text and not app.classic_hud.messages.bbcode_enabled,"chat displays latest safely")
	# Poison ticking pauses and never damages a safe-zone target.
	var target:={"id":"poison-test","kind":"monster","name":"毒术目标","hp":1000,"max_hp":1000,"generation":0,"cell":[301,618],"profile":{"sounds":{},"actions":{}},"race":81}
	app.world.entities=[target];app.rules.set_attack_mode("peace");app.apply_attack_hit(target,{"damage":5,"skill":"poison"})
	var hp: int=target.hp;app.elapsed+=2;app.gameplay.update(0);expect(target.hp<hp,"poison periodic tick")
	hp=target.hp;app.world.paused=true;app.elapsed+=2;app.gameplay.update(0);expect(target.hp==hp,"pause prevents poison tick")
	app.world.paused=false;target.cell=[EditionVillage.SPAWN.x,EditionVillage.SPAWN.y];app.elapsed+=2;app.gameplay.update(0);expect(target.hp==hp,"poison respects safe zones")
	# Buffs and group healing have rule effects, not only labels.
	app.rules.character.job="道士";app.elapsed+=80;app.fight_timer=0;app.pending_attack.clear()
	next=app.rules.state.duplicate(true);next.mp=1000;next.hp=200;app.rules.apply(next,"buff_fixture")
	var defense: int=app.rules.defense(app.elapsed)
	expect(app.gameplay.cast("armor") and app.rules.defense(app.elapsed)==defense+8,"armor increases defense")
	app.elapsed+=61;expect(app.rules.defense(app.elapsed)==defense,"armor expires")
	app.fight_timer=0;expect(app.gameplay.cast("ghostshield"),"ghostshield casts")
	var hp_before: int=app.rules.state.hp
	app.world.monster_hit.emit({"magic_attack":true},20)
	expect(app.rules.state.hp==hp_before-maxi(1,20-defense-8),"ghostshield reduces magic event damage")
	app.elapsed+=10;app.fight_timer=0;ally.hp=100;ally.cell=[301,618];app.world.entities=[ally]
	next=app.rules.state.duplicate(true);next.traveler_health[ally.id]={"hp":100,"generation":0,"respawn":0};app.rules.apply(next,"healing_fixture")
	expect(app.gameplay.cast("groupheal"),"group heal casts");app.gameplay.sync_travelers();expect(ally.hp>100,"group heal restores party HP")
	app.world.entities=[target];target.cell=[301,618]
	# Audio stages dispatch once even when update spans their deadlines.
	app.gameplay.spell_events.clear();app.rules.character.job="法师";target.cell=[301,618];app.selected=target;app.fight_timer=0;app.pending_attack.clear();app.elapsed+=50
	next=app.rules.state.duplicate(true);next.mp=1000;app.rules.apply(next,"sound_fixture");sounds.clear()
	expect(app.gameplay.cast("fireball"),"fireball stages start")
	app.elapsed+=0.4;app.gameplay.update_spell_effects();app.resolve_attack();app.gameplay.update_spell_effects();app.resolve_attack()
	for id in [10010,10011,10012]:expect(sounds.count(id)==1,"one sound stage "+str(id))
	next=app.rules.state.duplicate(true);next.mp=app.rules.max_mp();app.rules.apply(next,"preview_mana")
	app.enter_map("0",EditionVillage.SPAWN);app.world.entities=EditionVillage.travelers();app.world.player_alive=true
	app.chat_history.clear();app.chat_revision+=1
	app.rules.shop(book_for("fireball"),1);app.pending_message=app.rules.message
	for pair in [["gold",123],["potion",2]]:
		next=app.rules.state.duplicate(true);app.rules.add_ground(next,{"id":"preview","cell":[app.world.player.cell.x,app.world.player.cell.y]},pair[0],pair[1]);app.rules.apply(next,"preview_loot");app.gameplay.pickup(app.rules.state.ground_loot.back())
	app.append_chat("系统","技能书学习、拾取、交易与攻击模式记录已接入")
	app.world.update_world(0,Vector2(root.size),false,false)
	app.show_bag()
	expect(app.save_world(),"chat and world save together")
	expect(app.store.load_world(app.rules.character.id).chat_log==app.chat_history,"chat history persists with character")
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/skills-0.12.0/chat.png")
	var report:={"checks":checks,"failures":failures,"resource_errors":app.resources.errors,"runtime_skills":EditionSkills.DEFINITIONS.size()}
	FileAccess.open("res://../artifacts/skills-0.12.0/focused-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
