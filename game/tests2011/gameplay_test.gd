extends SceneTree
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():
	if DisplayServer.get_name()=="headless":
		printerr("gameplay_test requires a graphical display for viewport captures and frame_post_draw; run without --headless")
		quit(2);return
	call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func find_button(n: Node,text: String):
	if n is BaseButton and n.text==text:return n
	for child in n.get_children():
		var found=find_button(child,text)
		if found!=null:return found
	return null
func find_quick(n: Node,index: int):
	if n is EditionQuickSlot and n.index==index:return n
	for c in n.get_children():
		var found=find_quick(c,index)
		if found!=null:return found
	return null
func find_item(n: Node):
	if n is EditionItemSlot and n.item.get("type")=="potion":return n
	for c in n.get_children():
		var found=find_item(c)
		if found!=null:return found
	return null
func mouse(at: Vector2,press: int=-1,relative:=Vector2.ZERO) -> void:
	if press<0:
		var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true)
	else:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=press==1;root.push_input(event,true)
	await settle()
func run() -> void:
	root.size=Vector2i(1280,800)
	if "--small-window" in OS.get_cmdline_user_args():root.size=Vector2i(800,600)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-gameplay-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"gameplay","name":"操作验收","gender":"男","job":"战士"});app.world.paused=false
	app.show_bag();await settle()
	if "--capture-bag" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/closeout-bag-small.png")
		var bag_window=app.windows.windows["冒险面板"]
		bag_window.scroll.scroll_vertical=int(bag_window.scroll.get_v_scroll_bar().max_value)
		await settle();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/closeout-bag-small-bottom.png")
		bag_window.scroll.scroll_vertical=0;await settle()
	var source=find_item(app);var target=find_quick(app,3)
	expect(source!=null and target!=null,"inventory source and drop target exist")
	var count: int=app.rules.state.inventory.potion
	if source!=null and target!=null:
		var a: Vector2=source.get_global_rect().get_center();var b: Vector2=target.get_global_rect().get_center()
		await mouse(a,0);await mouse(a,-1);await mouse(a,1);await mouse(a+Vector2(32,0),-1,Vector2(32,0))
		expect(root.gui_is_dragging(),"mouse movement initiates engine drag")
		await mouse(b,-1,b-a-Vector2(32,0))
		print("DRAG ",a," -> ",b," hovered=",root.gui_get_hovered_control()," data=",root.gui_get_drag_data()," target=",target.get_global_rect())
		var hovered=root.gui_get_hovered_control()
		if hovered!=null:print("DRAG HIT ",hovered.get_path()," rect=",hovered.get_global_rect()," text=",hovered.text if hovered is BaseButton else ""," target_path=",target.get_path())
		await mouse(b,0)
		expect(app.rules.state.quickbar[3]=="potion","real mouse drag binds quick slot")
		expect(app.rules.state.inventory.potion==count,"binding leaves inventory stack untouched")
	app.windows.close_all();await settle()
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=20000;next.level=40;next.hp=400;next.mp=300
	expect(app.rules.apply(next,"fund_fixture"),"fund gameplay fixture")
	app.enter_map("0",Vector2i(300,618));app.world.entities=[]
	var monster:={"id":"drop_fixture","cell":[300,618],"name":"掉落检查"}
	next=app.rules.state.duplicate(true);app.rules.add_ground(next,monster,"potion",2);app.rules.add_ground(next,monster,"gold",123)
	expect(app.rules.apply(next,"drop_fixture"),"ground loot commits")
	var uid: String=app.rules.state.ground_loot[0].uid
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.pickup(uid,"0",Vector2i(300,618)),"failed DB write refuses pickup")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.state.ground_loot.size()==2 and app.rules.state.inventory.potion==count,"failed pickup retains loot and inventory")
	expect(app.rules.pickup(uid,"0",Vector2i(300,618)),"pickup succeeds")
	expect(not app.rules.pickup(uid,"0",Vector2i(300,618)) and app.rules.state.inventory.potion==count+2,"same loot cannot be awarded twice")
	var stored: Dictionary=app.store.load_world(app.rules.character.id)
	expect(stored.ground_loot.size()==1,"unpicked loot persists")
	var before_full: Dictionary=app.rules.state.duplicate(true)
	next=app.rules.state.duplicate(true);next.items=[]
	for slot in range(48):next.items.append(EditionInventory.make_item("potion",1,"inventory",slot))
	EditionInventory.mirror(next);app.rules.add_ground(next,monster,"ore",1)
	expect(app.rules.apply(next,"full_bag_fixture"),"full backpack fixture")
	var full_uid: String=app.rules.state.ground_loot.back().uid
	expect(not app.rules.pickup(full_uid,"0",Vector2i(300,618)),"full backpack rejects a new item type")
	expect(app.rules.state.ground_loot.back().uid==full_uid and app.rules.state.items.size()==48,"full bag retains ground drop")
	before_full.revision=app.rules.state.revision
	expect(app.rules.apply(before_full,"restore_full_fixture"),"restore temporary full-bag state")
	var gold: int=app.rules.state.gold
	var kill:={"id":"test-spawn","spawn_id":"test-source","cell":[300,618],"name":"掉落怪","exp":1,"respawn_seconds":60,"drops":[{"name":"金币","prob":"1/1","count":5},{"name":EditionRules.ITEMS.potion.name,"prob":"1/1","count":1}]}
	expect(app.rules.reward_kill("gameplay-kill","",kill,app.elapsed),"kill commits loot separately")
	expect(app.rules.state.gold==gold and app.rules.state.inventory.potion==count+2 and app.rules.state.ground_loot.size()>1,"kill does not directly grant currency or items")
	expect(app.rules.allocate("strength"),"level points can be allocated")
	expect(app.rules.shop("reset_stone",1),"reset stone purchasable")
	expect(app.gameplay.use_type("reset_stone") and app.rules.state.attributes.is_empty(),"reset returns allocated points")
	expect(app.rules.shop("return_stone",1),"return stone purchasable")
	app.enter_map("3",Vector2i(330,330));expect(app.gameplay.use_type("return_stone") and app.world.metadata.id=="0","return stone consumes and travels")
	for id in EditionGameplay.SKILLS:
		app.rules.character.job=EditionGameplay.SKILLS[id].job
		next=app.rules.state.duplicate(true);next.gold=100000
		app.rules.apply(next,"book_funds")
		for item_id in EditionRules.ITEMS:
			if EditionRules.ITEMS[item_id].get("skill_book","")==id:expect(app.rules.shop(item_id,1),"buy book "+id);break
		app.gameplay.learn(id);expect(app.rules.state.skills.has(id),"learn "+id)
		if EditionGameplay.SKILLS[id].get("passive",false):continue
		app.gameplay.bind_skill(id,0);expect(app.rules.state.skill_keys["0"]==id,"bind "+id)
		app.enter_map("0",Vector2i(300,618));app.world.entities=[];app.world.player_alive=true
		var empty: Array[Vector2i]=[];app.world.navigation.set_occupied(empty)
		var e:={"id":"skill-target","kind":"monster","name":"技能目标","cell":[301,618],"origin":[301,618],"hp":10000,"max_hp":10000,"generation":1,"ac":0,"race":81,"passive":true,"profile":{"sounds":{},"actions":{}},"appearance":0}
		app.world.entities=[e];app.selected=e;app.fight_timer=0;app.pending_attack.clear();app.elapsed+=40
		next=app.rules.state.duplicate(true);next.mp=1000;next.hp=200;app.rules.apply(next,"skill_fixture")
		var mp: int=app.rules.state.mp
		expect(app.gameplay.cast(id),"cast "+id)
		expect(not app.gameplay.cast(id),"duplicate cast blocked "+id)
		expect(app.rules.state.mp==mp-int(EditionGameplay.SKILLS[id].mp),"single mana debit "+id)
		app.elapsed+=0.3;app.resolve_attack()
		if id=="trap":expect(e.hp==10000 and preload("res://scripts/edition2011/trap_status.gd").active(e.get("trap_status",{}),e,app.elapsed),"trap controls eligible target without damage")
		elif EditionGameplay.SKILLS[id].range>0:expect(e.hp<10000,"skill damages target "+id)
		elif id=="heal":expect(app.rules.state.hp>200,"heal restores HP")
		elif id=="shield":expect(app.rules.state.shield_until>app.elapsed,"shield status persists")
	# Label rectangles fit one tile at every tested render scale; labels share
	# the standing artwork center, including its source frame offsets.
	app.enter_map("0",Vector2i(300,618))
	for scale in [1.0,2.0,4.0]:
		app.world.zoom=scale
		for entity in app.world.entities:
			if entity.kind!="monster":continue
			var info: Dictionary=app.world.labels.layout(entity)
			expect(info.name_rect.size.x<=ClassicPlayer.CELL.x*scale+1,"monster name fits a tile")
			expect(info.health_rect.size.x<=ClassicPlayer.CELL.x*scale,"monster bar fits a tile")
			expect(absf(info.head.x-(app.world.actors.anchor(entity).x+app.world.actor_idle_bounds(entity,true).get_center().x-app.world.camera.x)*scale)<0.01,"monster head centered on standing artwork")
	app.world.entities=[]
	next=app.rules.state.duplicate(true);next.hp=10;next.mp=10;app.rules.apply(next,"assist_fixture")
	var hp_before: int=app.rules.state.hp;var potion_before: int=app.rules.state.inventory.get("potion",0)
	app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(app.rules.state.hp==hp_before,"assist defaults do not consume potions")
	app.rules.set_assist("hp",true);app.gameplay.potion_ready=0;app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(app.rules.state.hp>hp_before and app.rules.state.inventory.get("potion",0)==potion_before-1,"auto HP consumes a real potion")
	app.rules.set_assist("hp",false)
	expect(app.store.load_world(app.rules.character.id).assist.hp==false,"assist choice persists")
	app.rules.set_assist("mp",true);app.gameplay.potion_ready=0;app.gameplay.assist_left=0
	next=app.rules.state.duplicate(true);next.mp=1;app.rules.apply(next,"blue_fixture");app.gameplay.update(0.5)
	expect(app.rules.state.mp>1,"auto MP consumes a real potion")
	app.rules.set_assist("mp",false)
	app.rules.shop("return_stone",1);app.enter_map("3",Vector2i(330,330));app.rules.set_assist("return",true)
	next=app.rules.state.duplicate(true);next.hp=1;app.rules.apply(next,"return_fixture");app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(app.world.metadata.id=="0" and app.rules.state.inventory.get("return_stone",0)==0,"low-health protection consumes return stone")
	app.rules.set_assist("return",false)
	app.enter_map("0",Vector2i(300,618));app.world.entities=[];app.gameplay.origin_map="0";app.gameplay.origin=app.world.player.cell
	next=app.rules.state.duplicate(true);next.ground_loot=[];app.rules.add_ground(next,{"cell":[300,618]},"gold",10);app.rules.apply(next,"filter_fixture")
	app.rules.set_assist("pickup",true);app.rules.set_assist("gold",false);app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(app.rules.state.ground_loot.size()==1,"gold pickup filter respected")
	app.rules.set_assist("gold",true);app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(app.rules.state.ground_loot.is_empty(),"enabled auto pickup claims nearby loot")
	app.rules.set_assist("pickup",false)
	var enemy:={"id":"auto-target","kind":"monster","name":"自动目标","cell":[301,618],"origin":[301,618],"hp":10000,"max_hp":10000,"generation":1,"ac":0,"race":81,"passive":true,"profile":{"sounds":{},"actions":{}},"appearance":0}
	app.world.entities=[enemy];app.fight_timer=0;app.pending_attack.clear();app.rules.set_assist("attack",true);app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(not app.pending_attack.is_empty(),"auto attack schedules an ordinary hit")
	app.pending_attack.clear();app.fight_timer=0;app.gameplay.origin=Vector2i.ZERO;app.gameplay.assist_left=0;app.gameplay.update(0.5)
	expect(app.pending_attack.is_empty(),"outside activity radius stops automated attacks")
	app.rules.set_assist("attack",false);app.world.entities=[]
	app.rules.character.job="道士";app.gameplay.bind_skill("heal",0);app.gameplay.bind_skill("talisman",1)
	app.rules.set_assist("attack",true);app.rules.set_assist("skill",true)
	app.world.entities=[enemy];app.gameplay.origin=app.world.player.cell;app.gameplay.origin_map=app.world.metadata.id
	app.elapsed+=40;app.fight_timer=0;app.pending_attack.clear()
	next=app.rules.state.duplicate(true);next.hp=app.rules.max_hp();next.mp=100;app.rules.apply(next,"auto_skill_fixture")
	app.gameplay.assist_left=0;app.gameplay.update(0.5)
	print("AUTO SKILL DIAG ",{"pending":app.pending_attack,"message":app.pending_message,"skills":app.gameplay.usable_skills(),"keys":app.rules.state.skill_keys,"route":app.world.player.route,"progress":app.world.player.progress,"manual_until":app.world.manual_control_until,"world_time":app.world.elapsed})
	expect(app.pending_attack.get("skill")=="talisman","auto skills skip full-health healing and use next binding")
	app.rules.set_assist("attack",false);app.rules.set_assist("skill",false);app.world.entities=[];app.pending_attack.clear()
	# A bound function key goes through the actual viewport keyboard dispatch.
	app.rules.character.job="道士";app.gameplay.bind_skill("heal",0);app.gameplay.select_skill("heal");app.fight_timer=0;app.elapsed+=40
	next=app.rules.state.duplicate(true);next.hp=10;next.mp=100;app.rules.apply(next,"key_fixture")
	var key:=InputEventKey.new();key.keycode=KEY_Q;key.physical_keycode=KEY_Q;key.pressed=true;root.push_input(key,true)
	key=key.duplicate();key.pressed=false;root.push_input(key,true)
	expect(app.rules.state.hp>10,"Q viewport key invokes the mapped healing skill")
	var after_q: int=app.rules.state.hp
	key=InputEventKey.new();key.keycode=KEY_F1;key.physical_keycode=KEY_F1;key.pressed=true;root.push_input(key,true)
	expect(app.rules.state.hp==after_q,"F1 no longer casts")
	app.gameplay.cycle_skill();expect(app.gameplay.current_skill()=="talisman","R cycle selects next learned class skill")
	expect(app.store.load_world(app.rules.character.id).active_skill=="talisman","current skill selection persists")
	app.controller_button(JOY_BUTTON_LEFT_SHOULDER);expect(app.gameplay.current_skill()=="heal","controller shoulder cycles backwards")
	app.elapsed+=40;app.fight_timer=0
	next=app.rules.state.duplicate(true);next.hp=10;app.rules.apply(next,"controller_fixture")
	var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_Y;joy.pressed=true;root.push_input(joy,true)
	expect(app.rules.state.hp>10,"controller Y input casts current skill")

	app.world.entities=[];app.rules.character.job="战士";app.pending_attack.clear()
	next=app.rules.state.duplicate(true);next.hp=0;next.erase("death_due");app.rules.apply(next,"death_fixture")
	app.gameplay.update(0);var due: float=app.rules.state.death_due
	expect(absf(due-app.elapsed-30)<0.01,"death waits thirty seconds")
	expect(not app.gameplay.use_type("potion"),"dead player cannot use potion to bypass death")
	app.world.paused=true;app._process(10);expect(app.elapsed<due,"pause freezes countdown")
	app.world.paused=false;app._process(1);expect(app.rules.state.hp==0 and app.world.metadata.id=="0","no instant resurrection")
	expect(app.save_world(),"dead position and countdown save")
	var profile: Dictionary=app.rules.character.duplicate(true)
	expect(app.rules.attach(profile),"dead character reloads")
	app.gameplay.clear_death();await settle();app.gameplay.ensure_death()
	expect(absf(float(app.rules.state.death_due)-due)<0.001 and app.rules.state.hp==0,"relogin does not reset or bypass death countdown")
	await settle();await RenderingServer.frame_post_draw
	expect(app.gameplay.death_box.get_global_rect().get_center().distance_to(Vector2(root.size)/2)<2,"reloaded death dialog centered before next gameplay tick")
	expect("秒后返回新手村" in app.gameplay.death_label.text,"reloaded death countdown immediately visible")
	root.get_texture().get_image().save_png("res://../artifacts/gameplay-0.10.0/death.png")
	var back=find_button(app,"保存并返回角色选择")
	expect(back!=null,"death screen exposes return-to-roster button")
	if back!=null:
		await mouse(back.get_global_rect().get_center(),1);await mouse(back.get_global_rect().get_center(),0)
		expect(app.mode!="game","death screen mouse click returns to roster")
		app.start_character(profile);await settle()
		expect(app.rules.state.hp==0 and absf(float(app.rules.state.death_due)-due)<0.001,"selecting dead character retains remaining countdown")
	# JSON reload may shift the deadline by a fraction of a nanosecond.
	# Exercise the first actual frame after the deadline rather than a zero tick.
	app.elapsed=due;app._process(1.0/60)
	if app.rules.state.hp<=0:print("DEATH DIAG ",{"due":due,"at":app.death_return_at,"elapsed":app.elapsed,"paused":app.world.paused,"message":app.rules.message,"mode":app.mode,"stored_due":app.rules.state.get("death_due"),"remaining_precise":"%.15f"%(float(app.rules.state.get("death_due",0))-app.elapsed)})
	expect(app.rules.state.hp>0 and not app.rules.state.has("death_due"),"death returns after delay")
	app.gameplay.show_assist();await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/gameplay-0.10.0/assist.png")
	var report:={"checks":checks,"failures":failures,"resource_errors":app.resources.errors}
	FileAccess.open("res://../artifacts/gameplay-0.10.0/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	var fixture_path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file: String=fixture_path+suffix
		if FileAccess.file_exists(file):
			var error:=DirAccess.remove_absolute(file)
			if error!=OK:failures.append("Cannot clean isolated test database: "+file);printerr(failures.back())
	print("Fixture cleanup complete: ",fixture_path)
	quit(0 if failures.is_empty() else 1)
