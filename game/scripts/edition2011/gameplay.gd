class_name EditionGameplay
extends Node2D
# Playable single-player rules. Spell VFX and balance are local reconstructions.
const SKILLS=EditionSkills.DEFINITIONS
var app
var pending_pickup:=""
var assist_left:=0.0
var pickup_retry_left:=0.0
var potion_ready:=0.0
var origin:=Vector2i.ZERO
var origin_map:=""
var visuals: Array=[]
var skill_effects
var death_layer: CanvasLayer
var death_feedback: Label
var death_label: Label
var death_box: VBoxContainer
var active_assist:=false
var spell_events: Array=[]
func setup(host) -> void:
	app=host;z_index=2
	skill_effects=preload("res://scripts/edition2011/skill_effects.gd").new()
	skill_effects.app=app;add_child(skill_effects)
func say(text: String) -> void:app.pending_message=text
func available() -> bool:return app.mode=="game" and not app.world.paused and app.rules.state.hp>0
func use_item_uid(uid: String) -> bool:
	if app.mode!="game":say("请先进入游戏再使用物品");return false
	if app.rules.state.hp<=0:say("死亡状态不能使用物品");return false
	if app.world.paused:say("请继续游戏后使用物品");return false
	var item:=EditionInventory.find_item(app.rules.state,uid)
	if item.is_empty():say("物品已不存在，请重新选择");return false
	var spec: Dictionary=EditionRules.ITEMS[item.type]
	if spec.get("utility")=="return" and item.container!="inventory":say("请先把回城物品取回背包");return false
	if (spec.has("heal") or spec.has("mana")) and app.elapsed<potion_ready:say("药品冷却中");return false
	var old_map: String=app.world.metadata.id;var old_cell: Vector2i=app.world.player.cell
	if spec.get("utility")=="return" and not app.enter_map("0",EditionVillage.SPAWN):say("回城地图无法加载，未消耗物品");return false
	var ok: bool=app.rules.inventory_action("use",{"uid":uid},app.region.trap_snapshots(app.world) if spec.get("utility")=="return" else null)
	if not ok and spec.get("utility")=="return":app.enter_map(old_map,old_cell)
	if ok and (spec.has("heal") or spec.has("mana")):potion_ready=app.elapsed+2
	say(app.rules.message);return ok
func use_type(type: String) -> bool:
	for item in app.rules.state.items:
		if item.container=="inventory" and item.type==type:return use_item_uid(item.uid)
	return false
func pickup(loot: Dictionary) -> bool:
	if not available():return false
	var at:=Vector2i(loot.cell[0],loot.cell[1])
	if not line_clear(app.world.player.cell,at):say("掉落物被障碍遮挡");return false
	var ok: bool=app.rules.pickup(loot.uid,app.world.metadata.id,app.world.player.cell);if ok:app.play_sound_id(106 if loot.type=="gold" else EditionRules.item_sound(loot.type))
	say(app.rules.message);return ok
func click(point: Vector2) -> bool:
	if not available():return false
	var cell: Vector2i=app.world.point_to_cell(point)
	for loot in app.rules.state.get("ground_loot",[]):
		if loot.map!=app.world.metadata.id:continue
		var projected: Vector2=(Vector2(loot.cell[0],loot.cell[1])*ClassicPlayer.CELL-app.world.camera)*app.world.zoom
		var title: String="金币" if loot.type=="gold" else EditionRules.ITEMS[loot.type].name
		var density: float=maxf(1,app.world.display_density)
		var width: float=maxf(14,app.font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x)+6
		if not Rect2(projected+Vector2(-width/2,-10)*density,Vector2(width,34)*density).has_point(point):continue
		cell=Vector2i(loot.cell[0],loot.cell[1])
		if (cell-app.world.player.cell).length()<=1.5:pickup(loot)
		else:pending_pickup=loot.uid;app.world.approach(cell)
		return true
	pending_pickup="";return false
func pickup_nearby() -> void:
	for loot in app.rules.state.get("ground_loot",[]):
		if loot.map==app.world.metadata.id and Vector2(loot.cell[0]-app.world.player.cell.x,loot.cell[1]-app.world.player.cell.y).length()<=1.5:
			pickup(loot);return
func line_clear(a: Vector2i,b: Vector2i) -> bool:
	var current:=a
	var steps:=maxi(absi(b.x-a.x),absi(b.y-a.y))
	for i in range(1,steps+1):
		var next:=Vector2i(Vector2(a).lerp(Vector2(b),float(i)/steps).round())
		if not app.world.navigation.can_step(current,next):return false
		current=next
	return true
func learn(id: String) -> void:
	if not available() or not SKILLS.has(id):return
	for item in app.rules.state.items:
		if item.container=="inventory" and EditionRules.ITEMS[item.type].get("skill_book","")==id:
			use_item_uid(item.uid);return
	say("需要《"+SKILLS[id].name+"》技能书，请从书店购买或拾取")

func bind_skill(id: String,key: int) -> void:
	if not available():return
	if not app.rules.state.skills.has(id) or key<0 or key>7:return
	var next: Dictionary=app.rules.state.duplicate(true)
	if not next.has("skill_keys"):next.skill_keys={}
	for existing in next.skill_keys.keys():
		if next.skill_keys[existing]==id:next.skill_keys.erase(existing)
	next.skill_keys[str(key)]=id
	if not app.rules.apply(next,"bind_skill"):say(app.rules.message);return
	say("已更新自动技能顺序")
func cast_key(key: int) -> void:cast(app.rules.state.get("skill_keys",{}).get(str(key),""))
func cast(id: String) -> bool:
	if app.rules.stoned(app.elapsed):say("石化中，暂时无法施法");return false
	if not available() or app.typing() or not SKILLS.has(id) or not app.rules.state.skills.has(id) or SKILLS[id].get("passive",false):return false
	var skill: Dictionary=SKILLS[id]
	if app.rules.character.job!=skill.job or app.rules.state.level<skill.level:return false
	if app.fight_timer>0 or not app.pending_attack.is_empty() or app.elapsed<float(app.rules.state.get("skill_ready",{}).get(id,0)):say("技能冷却中");return false
	if app.rules.state.mp<skill.mp:say("魔法不足");return false
	var targets: Array=[]
	if skill.range>0:
		if EditionRegion.safe(app.world.metadata.id,app.world.player.cell):say("安全区不能攻击");return false
		for e in app.world.entities:
			if not can_target(e):continue
			if id=="trap" and not preload("res://scripts/edition2011/trap_status.gd").eligible(e,int(app.rules.state.level)):continue
			var at:=Vector2i(e.cell[0],e.cell[1]);var d: Vector2i=at-app.world.player.cell
			if maxi(absi(d.x),absi(d.y))<=int(skill.range) and not EditionRegion.safe(app.world.metadata.id,at) and line_clear(app.world.player.cell,at):targets.append(e)
		if targets.is_empty():say("范围内没有可见目标");return false
		targets.sort_custom(func(a,b):return Vector2(a.cell[0]-app.world.player.cell.x,a.cell[1]-app.world.player.cell.y).length_squared()<Vector2(b.cell[0]-app.world.player.cell.x,b.cell[1]-app.world.player.cell.y).length_squared())
		if id!="halfmoon" and skill.get("kind","")!="around":
			var chosen: Dictionary=targets[0]
			for e in targets:
				if e.id==app.selected.get("id",""):chosen=e;break
			match skill.get("kind",""):
				"area":
					targets=targets.filter(func(e):return e.id!=chosen.id and maxi(absi(int(e.cell[0])-int(chosen.cell[0])),absi(int(e.cell[1])-int(chosen.cell[1])))<=1)
					targets.push_front(chosen)
				"line":
					var ray:=Vector2i(signi(int(chosen.cell[0])-app.world.player.cell.x),signi(int(chosen.cell[1])-app.world.player.cell.y))
					targets=targets.filter(func(e):
						var diff: Vector2i=Vector2i(e.cell[0],e.cell[1])-app.world.player.cell
						return diff.x*ray.y==diff.y*ray.x and diff.x*ray.x+diff.y*ray.y>0)
				_:targets=[chosen]
	if skill.range>0 and targets.is_empty():
		say("目标不在技能攻击直线上，请调整站位");return false
	var next: Dictionary=app.rules.state.duplicate(true);next.mp-=int(skill.mp);next.time=app.elapsed;next.map=app.world.metadata.id;next.cell=[app.world.player.cell.x,app.world.player.cell.y]
	for material in EditionSkills.material_costs(id):
		if not app.rules.count_item(next,material,-int(EditionSkills.material_costs(id)[material])):
			say("需要"+str(EditionRules.ITEMS[material].name));return false
	if not next.has("skill_ready"):next.skill_ready={}
	next.skill_ready[id]=app.elapsed+float(skill.cooldown)
	var progress: Dictionary=next.skills[id] if next.skills[id] is Dictionary else {"proficiency":0,"rank":1}
	progress.proficiency=int(progress.get("proficiency",0))+1;progress.rank=mini(3,1+int(progress.proficiency)/100);next.skills[id]=progress
	if id in ["heal","groupheal"]:next.hp=mini(app.rules.max_hp(),int(next.hp)+30+int(next.level)*2)
	if id=="shield":next.shield_until=app.elapsed+30
	if id in ["armor","ghostshield"]:next[id+"_until"]=app.elapsed+60
	if id=="groupheal":
		if not next.has("traveler_health"):next.traveler_health={}
		for e in app.world.entities:
			if e.kind!="traveler" or e.name not in next.party or int(e.get("hp",250))<=0:continue
			if Vector2(e.cell[0]-app.world.player.cell.x,e.cell[1]-app.world.player.cell.y).length()>3:continue
			var health: Dictionary=next.traveler_health.get(e.id,{}).duplicate(true)
			health.merge({"hp":mini(250,int(e.get("hp",250))+30+int(next.level)*2),"generation":int(e.get("generation",0)),"respawn":0},true)
			next.traveler_health[e.id]=health
	app.rules.message="施放 "+skill.name
	if not app.rules.apply(next,"cast_skill"):say(app.rules.message);return false
	app.fight_timer=0.5;app.world.animate(skill.action)
	if not targets.is_empty():
		var delta:=Vector2i(signi(int(targets[0].cell[0])-app.world.player.cell.x),signi(int(targets[0].cell[1])-app.world.player.cell.y))
		if delta!=Vector2i.ZERO:app.world.player.direction=ClassicNavigation.DIRECTIONS.find(delta)
	if skill_effects.MELEE.has(id):skill_effects.melee_id=id
	play_skill_stage(id,0)
	spell_events.append({"at":app.elapsed+skill_release_delay(id),"map":app.world.metadata.id,"skill":id,"stage":1})
	if targets.is_empty():spell_events.append({"at":app.elapsed+0.25,"map":app.world.metadata.id,"skill":id,"stage":2})
	if id=="beam" and not targets.is_empty():skill_effects.launch_beam(targets[0])
	for target in targets:
		if skill_effects.PROJECTILES.has(id):skill_effects.launch_projectile(id,target)
		if skill_effects.PROFILES.has(id) or skill_effects.MELEE.has(id):continue
		visuals.append({"from":app.world.player.anchor,"to":app.world.actors.anchor(target),"until":app.elapsed+0.5,"id":id})
	if not targets.is_empty():
		var hits: Array=[]
		for target in targets:hits.append({"id":target.id,"generation":target.generation})
		app.pending_attack={"id":targets[0].id,"generation":targets[0].generation,"hits":hits,"at":app.elapsed+(0.42 if skill_effects.PROJECTILES.has(id) else 0.25),"range":skill.range,"damage":int((app.rules.roll_melee_damage() if skill.job=="战士" else 8+int(next.level)+app.rules.equipment_bonus("magic" if skill.job=="法师" else "tao")+int(next.get("attributes",{}).get("spirit",0)))*float(skill.power)*(1.0+0.1*(int(progress.rank)-1))),"skill":id}
		if skill.get("kind","")=="area":
			app.pending_attack.effect_at=app.world.actors.anchor(targets[0])
			app.pending_attack.area_cell=targets[0].cell.duplicate()
	else:
		if skill_effects.PROFILES.has(id):skill_effects.add(id,app.world.player.anchor)
		elif id!="shield":visuals.append({"from":app.world.player.anchor,"to":app.world.player.anchor,"until":app.elapsed+0.5,"id":id})
	say(app.rules.message);return true
func usable_skills() -> Array:
	var result: Array=[]
	for id in SKILLS:
		if app.rules.state.skills.has(id) and not SKILLS[id].get("passive",false) and SKILLS[id].job==app.rules.character.job and app.rules.state.level>=SKILLS[id].level:result.append(id)
	return result
func auto_skills() -> Array:
	var available_skills:=usable_skills()
	var bindings: Dictionary=app.rules.state.get("skill_keys",{})
	var keys: Array=bindings.keys()
	keys.sort_custom(func(a,b):return int(a)<int(b))
	var ordered: Array=[]
	for key in keys:
		var id: String=str(bindings[key])
		if id in available_skills and id not in ordered:ordered.append(id)
	# Existing bindings are an explicit selection, even if none is usable now.
	return available_skills if bindings.is_empty() else ordered
func current_skill() -> String:
	var choices:=usable_skills()
	var selected: String=app.rules.state.get("active_skill","")
	return selected if selected in choices else str(choices[0]) if not choices.is_empty() else ""
func select_skill(id: String) -> void:
	if not available() or id not in usable_skills():return
	var next: Dictionary=app.rules.state.duplicate(true);next.active_skill=id
	if app.rules.apply(next,"select_skill"):say("当前技能："+SKILLS[id].name+" · Q / 手柄 Y 施放")
	else:say(app.rules.message)
func cycle_skill(step:=1) -> void:
	var choices:=usable_skills()
	if choices.is_empty():say("请先在技能页学习技能");return
	select_skill(choices[posmod(choices.find(current_skill())+step,choices.size())])
func cast_current() -> void:
	var id:=current_skill()
	if id.is_empty():say("请先在技能页学习技能");return
	cast(id)
func show_skills() -> void:
	app.show_adventure(3)
func show_assist() -> void:
	var zoom:=EditionDisplay.ui_zoom(app.get_viewport_rect().size,app.windows.requested_scale,app.display_density)
	app.game_panel("内挂设置",app.get_viewport_rect().size/zoom-Vector2(24,24))
	app.panel.pin_notice()
	var view=load("res://scripts/edition2011/ui/assist_panel.gd").new();app.form.add_child(view);view.setup(app)

func auto_profession(cfg: Dictionary) -> bool:
	if app.fight_timer>0 or not app.pending_attack.is_empty():return false
	var wanted: Array=[]
	if cfg.get("auto_shield",false) and float(app.rules.state.get("shield_until",0))<=app.elapsed+2:wanted.append("shield")
	if cfg.get("auto_heal",false) and float(app.rules.state.hp)/app.rules.max_hp()*100<=int(cfg.get("hp_threshold",50)):wanted.append("heal")
	if cfg.get("auto_armor",false) and float(app.rules.state.get("armor_until",0))<=app.elapsed+2:wanted.append("armor")
	for id in wanted:
		if id in usable_skills() and app.rules.state.mp>=SKILLS[id].mp and app.elapsed>=float(app.rules.state.get("skill_ready",{}).get(id,0)):
			if cast(id):return true
	return false

func assisted_strike() -> bool:
	if not app.rules.state.get("assist",{}).get("auto_thrust",false) or "thrust" not in usable_skills():return false
	if app.elapsed>=float(app.rules.state.get("skill_ready",{}).get("thrust",0)):cast("thrust")
	return true

func show_utilities() -> void:
	app.game_panel("加点与便利用品 · 单机")
	app.label("每级获得 2 点，可分配 %d 点；洗点返还全部已分配点。"%app.rules.attribute_points())
	for row in [["strength","力量：每点攻击 +1"],["vitality","体力：每点生命上限 +5"],["spirit","精神：每点伤害技能威力 +1"]]:
		app.button(row[1]+" · 已加 %d"%int(app.rules.state.get("attributes",{}).get(row[0],0)),func():app.rules.allocate(row[0]);show_utilities();app.info(app.rules.message))
	for type in ["return_stone","reset_stone"]:
		app.button("购买 %s · %d 金币"%[EditionRules.ITEMS[type].name,EditionRules.ITEMS[type].price],func():
			if app.rules.state.hp>0:app.rules.shop(type,1);app.info(app.rules.message))
func revive_after_wait() -> bool:
	if app.mode!="game" or app.world.paused or app.rules.state.hp>0 or not app.rules.state.has("death_due") or app.elapsed<float(app.rules.state.death_due):return false
	var origin: String=app.world.metadata.id;var cell: Vector2i=app.world.player.cell
	var due: float=app.rules.state.death_due
	if not app.enter_map("0",EditionVillage.SPAWN,false):
		say("回城地图无法加载，请重试或返回选角");return false
	if not app.rules.revive_after_wait(app.world.player.cell,app.elapsed,app.region.trap_snapshots(app.world)):
		var reason: String=app.rules.message;app.enter_map(origin,cell,false);app.death_return_at=due;say(reason);return false
	clear_death();app.world.player_alive=true;say(app.rules.message)
	return true
func ensure_death() -> void:
	if is_instance_valid(death_layer):return
	active_assist=false;pending_pickup="";spell_events.clear();visuals.clear();skill_effects.clear();queue_redraw();app.pending_attack.clear();app.world.player.route.clear()
	if not app.rules.state.has("death_due"):
		var next: Dictionary=app.rules.state.duplicate(true);next.death_due=app.elapsed+30;next.time=app.elapsed;next.map=app.world.metadata.id;next.cell=[app.world.player.cell.x,app.world.player.cell.y]
		if not app.rules.apply(next,"death_countdown"):say(app.rules.message);return
	app.death_return_at=float(app.rules.state.death_due)
	death_layer=CanvasLayer.new();death_layer.layer=80;app.add_child(death_layer)
	var grey:=ColorRect.new();grey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);grey.mouse_filter=Control.MOUSE_FILTER_STOP;death_layer.add_child(grey)
	var shader:=Shader.new();shader.code="shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_nearest; void fragment(){vec4 c=texture(screen_texture,SCREEN_UV);float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(vec3(g)*0.65,1.0);}"
	var material:=ShaderMaterial.new();material.shader=shader;grey.material=material
	var box:=VBoxContainer.new();death_box=box;box.custom_minimum_size=Vector2(420,100);grey.add_child(box)
	death_label=Label.new();death_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(death_label)
	var current_layer:=death_layer
	var resume:=Button.new();resume.text="继续倒计时（暂停时）";box.add_child(resume)
	resume.pressed.connect(func():
		if not is_instance_valid(current_layer) or current_layer!=death_layer or current_layer.is_queued_for_deletion():return
		if app.windows.modal.visible:app.windows.modal.canceled.emit()
		app.windows.modal.hide();app.windows.pause_reason="";app.world.paused=false)
	var back:=Button.new();back.text="返回选角（重新进入即可就近复活）";box.add_child(back)
	death_feedback=Label.new();death_feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;death_feedback.custom_minimum_size.x=420;box.add_child(death_feedback)
	back.pressed.connect(func():
		if not is_instance_valid(current_layer) or current_layer!=death_layer or current_layer.is_queued_for_deletion():return
		if app.save_world():clear_death();app.show_roster()
		else:death_feedback.text="保存未完成："+app.pending_message)
	update_death_layout()
	call_deferred("update_death_layout")
func update_death_layout() -> void:
	if not is_instance_valid(death_box):return
	var zoom:=EditionDisplay.ui_zoom(app.get_viewport_rect().size,app.windows.requested_scale,app.display_density)
	death_box.scale=Vector2.ONE*zoom;death_box.position=((app.get_viewport_rect().size-death_box.size*zoom)/2).round()
	death_label.text="你已死亡\n%d 秒后返回新手村"%maxi(0,ceili(float(app.rules.state.get("death_due",app.elapsed+30))-app.elapsed))
func clear_death() -> void:
	if is_instance_valid(death_layer):death_layer.queue_free()
	death_layer=null
func update(delta: float) -> void:
	if app.mode!="game":clear_death();return
	if app.rules.state.hp<=0:
		ensure_death()
		update_death_layout()
		return
	clear_death()
	if not available():return
	pickup_retry_left=maxf(0,pickup_retry_left-delta)
	if app.rules.tick_green_poison(app.elapsed):
		say(app.rules.message)
		if app.rules.state.hp<=0:app.world.player.route.clear();app.pending_attack.clear();ensure_death();return
	if app.rules.tick_traveler_poison(app.elapsed):say(app.rules.message)
	sync_travelers()
	update_spell_effects()
	if origin_map!=app.world.metadata.id:origin=app.world.player.cell;origin_map=app.world.metadata.id;pending_pickup=""
	if not pending_pickup.is_empty():
		for loot in app.rules.state.get("ground_loot",[]):
			if loot.uid==pending_pickup and loot.map==origin_map and Vector2(loot.cell[0]-app.world.player.cell.x,loot.cell[1]-app.world.player.cell.y).length()<=1.5:pickup(loot);pending_pickup="";break
	visuals=visuals.filter(func(v):return v.until>app.elapsed);queue_redraw()
	assist_left-=delta
	if assist_left>0 or app.typing():return
	assist_left=0.3
	var cfg: Dictionary=app.rules.state.get("assist",{})
	var hp: float=float(app.rules.state.hp)/app.rules.max_hp()*100
	if cfg.get("return",false) and hp<=int(cfg.get("return_threshold",15)):
		if use_type("return_stone"):return
	if cfg.get("hp",false) and hp<=int(cfg.get("hp_threshold",50)):auto_potion("heal")
	if cfg.get("mp",false) and float(app.rules.state.mp)/app.rules.max_mp()*100<=int(cfg.get("mp_threshold",30)):auto_potion("mana")
	if cfg.get("pickup",false):auto_pickup_underfoot(cfg)
	if auto_profession(cfg):return
	if not cfg.get("attack",false):return
	# Finish the player's chosen route/step before selecting an automatic target.
	if app.world.elapsed<app.world.manual_control_until or not app.world.player.route.is_empty() or app.world.player.progress<1.0:return
	var radius:=int(cfg.get("radius",6))
	if (app.world.player.cell-origin).length()>radius:return
	var nearest: Dictionary={};var distance:=float(radius+1)
	for e in app.world.entities:
		if not can_target(e) or EditionRegion.safe(origin_map,Vector2i(e.cell[0],e.cell[1])):continue
		if (Vector2(e.cell[0],e.cell[1])-Vector2(origin)).length()>radius:continue
		var d: float=Vector2(e.cell[0]-app.world.player.cell.x,e.cell[1]-app.world.player.cell.y).length()
		if d<distance:nearest=e;distance=d
	if nearest.is_empty():return
	app.selected=nearest
	if cfg.get("skill",false):
		for id in auto_skills():
			if id=="heal" and hp>=80:continue
			if id=="shield" and float(app.rules.state.get("shield_until",0))>app.elapsed+3:continue
			if cast(id):return
	if distance<=1.5:app.attack_target()
	elif app.world.player.route.is_empty():approach_target(nearest)
func auto_pickup_underfoot(cfg: Dictionary) -> void:
	if not cfg.get("pickup",false) or not available() or pickup_retry_left>0:return
	for loot in app.rules.state.get("ground_loot",[]).duplicate(true):
		if loot.map!=app.world.metadata.id or Vector2i(loot.cell[0],loot.cell[1])!=app.world.player.cell:continue
		var category: String="gold" if loot.type=="gold" else "equipment" if EditionRules.ITEMS.get(loot.type,{}).has("slot") else "materials"
		if not cfg.get(category,true):continue
		if not pickup(loot):pickup_retry_left=2

func auto_potion(effect: String) -> void:
	if app.elapsed<potion_ready:return
	for item in app.rules.state.items:
		if item.container=="inventory" and EditionRules.ITEMS[item.type].has(effect):use_item_uid(item.uid);return
func _draw() -> void:
	if app==null or app.mode!="game":return
	for loot in app.rules.state.get("ground_loot",[]):
		if loot.map!=app.world.metadata.id:continue
		var at:=Vector2(loot.cell[0],loot.cell[1])*ClassicPlayer.CELL
		if at.distance_to(app.world.player.anchor)>1000:continue
		# Keep ground items small in display points, independent of map zoom.
		var density: float=maxf(1,app.world.display_density)
		draw_set_transform(at,0,Vector2.ONE*density/app.world.zoom)
		if loot.type=="gold":
			draw_circle(Vector2(-2,-2),3,Color.GOLD);draw_circle(Vector2(2,-4),3,Color("bf8c27"))
		else:
			var frame: Dictionary=app.resources.frame("items",int(EditionRules.ITEMS[loot.type].icon))
			if not frame.is_empty():
				var factor:=minf(1,14.0/maxf(frame.size.x,frame.size.y))
				draw_texture_rect(frame.texture,Rect2(-frame.size*factor/2,frame.size*factor),false)
		var title: String="金币" if loot.type=="gold" else EditionRules.ITEMS[loot.type].name
		var width: float=app.font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		var baseline:=Vector2(-width/2,20)
		draw_string_outline(app.font,baseline,title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,2,Color.BLACK)
		draw_string(app.font,baseline,title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("dfcf98"))
		draw_set_transform(Vector2.ZERO)
	for v in visuals:
		var alpha:=clampf((v.until-app.elapsed)*2,0,1)
		var color:=Color(0.4,0.8,1,alpha) if v.id=="lightning" else Color(1,0.55,0.15,alpha)
		if v.from==v.to:draw_arc(v.to,24,0,TAU,24,Color(0.3,1,0.5,alpha),2)
		else:draw_line(v.from-Vector2(0,35),v.to-Vector2(0,25),color,3);draw_circle(v.to-Vector2(0,25),8*alpha,color)

func play_spell_sound(name: String) -> void:
	for id in app.resources.audio_catalog.get("sound_ids",{}):
		if str(app.resources.audio_catalog.sound_ids[id]).to_lower()==name.to_lower():app.play_sound_id(int(id),0,"Combat");return

func approach_target(entity: Dictionary) -> void:
	var target:=Vector2i(entity.cell[0],entity.cell[1]);var best: Array[Vector2i]=[]
	var player: ClassicPlayer=app.world.player
	var start:=player.destination if player.progress<1.0 else player.cell
	var reserved: Array[Vector2i]=app.world.actors.player_reserved_cells()
	if target not in reserved:reserved.append(target)
	var avoid: Array[Vector2i]=player.path_avoid.duplicate();avoid.append_array(reserved)
	for direction in ClassicNavigation.DIRECTIONS:
		var candidate: Vector2i=target+direction
		if candidate in avoid or not app.world.navigation.can_step(candidate,target):continue
		var route: Array[Vector2i]=app.world.navigation.path_avoiding(start,candidate,avoid)
		if route.is_empty() or target in route:continue
		if best.is_empty() or route.size()<best.size():best=route
	if not best.is_empty():player.go_to(best.back(),reserved)

func show_books() -> void:
	app.game_panel("技能书商店")
	app.label("购买后在背包双击技能书学习；职业、等级不符或已学会时保留原书。")
	for id in EditionRules.ITEMS:
		var item: Dictionary=EditionRules.ITEMS[id]
		if not item.has("skill_book") or SKILLS[item.skill_book].job!=app.rules.character.job:continue
		app.button("《%s》 · %d 金币"%[item.name,item.price],func():app.rules.shop(id,1);say(app.rules.message))

func can_target(entity: Dictionary) -> bool:
	return EditionCombat.eligible(app.rules.state,entity)
func cycle_attack_mode() -> void:
	if not available() or app.typing():return
	var keys: Array=EditionCombat.MODES.keys()
	var at:=keys.find(app.rules.state.get("attack_mode","peace"))
	if app.rules.set_attack_mode(keys[posmod(at+1,keys.size())]):
		app.pending_attack.clear()
	say(app.rules.message)
func guild_mana() -> void:
	if not available():say("请继续游戏后办理行会补给");return
	if app.rules.guild_mana():app.play_sound_id(EditionItemAudio.sound("mana","use"),0,"Interface")
	say(app.rules.message)

func guild_aid() -> void:
	if not available():say("请继续游戏后办理行会补给");return
	var candidates: Array=app.world.entities.filter(func(e):return e.kind=="traveler" and e.name in app.rules.state.party and e.name in app.rules.state.guild.get("members",[]) and int(e.get("hp",250))>0 and int(e.get("hp",250))<250 and Vector2i(e.cell[0],e.cell[1]).distance_to(app.world.player.cell)<=4)
	if candidates.is_empty():say("附近没有需要补给的同队行会成员");return
	candidates.sort_custom(func(a,b):return int(a.hp)<int(b.hp))
	if app.rules.guild_aid(candidates[0],app.world.metadata.id,app.world.player.cell):
		sync_travelers();app.play_sound_id(EditionItemAudio.sound("potion","use"),0,"Interface")
	say(app.rules.message)

func sync_travelers(emit_events:=true) -> void:
	if available():
		var ids: Array=app.world.entities.filter(func(e):return e.kind=="traveler").map(func(e):return e.id)
		app.rules.recover_travelers(ids,app.elapsed)
	for entity in app.world.entities:
		if entity.kind!="traveler":continue
		var health: Dictionary=app.rules.state.get("traveler_health",{}).get(entity.id,{})
		apply_traveler_health(entity,health,emit_events)

func apply_traveler_health(entity: Dictionary,health: Dictionary,emit_events:=true) -> void:
	# Presentation consumes committed health; a repeated sync is not a new hit.
	# Initial map/save snapshots restore poses silently instead of replaying death.
	var previous_hp:=int(entity.get("hp",250))
	entity.green_poison=health.get("green_poison",{}).duplicate(true)
	entity.max_hp=250;entity.hp=int(health.get("hp",250));entity.generation=int(health.get("generation",0))
	entity.respawn=float(health.get("respawn",0));entity.stone_until=float(health.get("stone_until",0))
	if previous_hp>0 and entity.hp<=0:
		entity.motion="die";entity.motion_time=app.world.elapsed
		app.world.actors.mover(entity).route.clear()
		if emit_events:app.world.actors.sound(entity,"die")
	elif previous_hp<=0 and entity.hp>0:
		entity.motion="stand";entity.motion_time=app.world.elapsed
		app.world.actors.mover(entity).reset(Vector2i(entity.cell[0],entity.cell[1]))
	elif entity.hp>0 and entity.hp<previous_hp and emit_events:
		entity.motion="hurt";entity.motion_time=app.world.elapsed
		app.world.actors.sound(entity,"hurt")
func hit_traveler(entity: Dictionary,attack: Dictionary) -> void:
	if entity.get("kind","")!="traveler" or int(entity.get("hp",0))<=0:return
	var magical: bool=bool(attack.get("magic_attack",false)) or EditionSkills.DEFINITIONS.get(attack.get("skill",""),{}).get("job","战士")!="战士"
	var defense_key: String="mac" if magical else "ac"
	var damage:=maxi(1,int(attack.damage)-int(entity.get(defense_key,0)))
	var next: Dictionary=app.rules.state.duplicate(true)
	if not next.has("traveler_health"):next.traveler_health={}
	var hp:=maxi(0,int(entity.hp)-damage)
	var generation:=int(entity.get("generation",0))+(1 if hp==0 else 0)
	var health: Dictionary=next.traveler_health.get(entity.id,{}).duplicate(true)
	health.merge({"hp":hp,"generation":generation,"respawn":app.elapsed+30 if hp==0 else 0,"name":str(entity.name)},true)
	if hp<=0:health.erase("green_poison");health.erase("stone_until")
	elif attack.get("green_poison",false) and float(health.get("green_poison",{}).get("until",0))<=app.elapsed+60:
		health.green_poison={"until":app.elapsed+60,"next":app.elapsed+1,"power":3}
	if hp>0 and attack.get("skill","")=="poison" and not attack.get("periodic",false):
		health.green_poison={"until":app.elapsed+10,"next":app.elapsed+1.5,"interval":1.5,"power":maxi(1,3+int(app.rules.state.level)/5-int(entity.get("mac",0)))}
	if hp>0 and attack.get("stone",false):health.stone_until=maxf(float(health.get("stone_until",0)),app.elapsed+5)
	next.traveler_health[entity.id]=health
	app.rules.message="%s 受到 %d 点伤害%s"%[entity.name,damage,"，30 秒后复活" if hp==0 else ""]
	if not app.rules.apply(next,"traveler_damage"):say(app.rules.message);return
	apply_traveler_health(entity,health)
	say(app.rules.message)

static func melee_skill_sound(id: String) -> int:
	# mirgo actorsound.go: Long/Wide/FireHit play their dedicated sound at frame 2.
	return int({"thrust":132,"halfmoon":133,"flame":137}.get(id,-1))

static func skill_release_delay(id: String) -> float:
	if melee_skill_sound(id)<0:return 0.12
	return 2.0*float(EditionAnimation.HUMAN[SKILLS[id].action].ms)/1000.0

func play_skill_stage(id: String,stage: int) -> void:
	if not SKILLS.has(id) or SKILLS[id].get("passive",false):return
	var melee:=melee_skill_sound(id)
	if melee>=0:
		if stage==1:
			var weapon: String=app.rules.state.equipment.get("weapon","")
			app.play_sound_id(51 if weapon=="wood_sword" else 52 if weapon=="sword" else 57,0,"Combat")
			app.play_sound_id(melee,0,"Combat")
		return
	var sound_id:=10000+int(SKILLS[id].serial)*10+stage
	# Play only indexed stages; missing stages remain an audio-audit gap.
	var name: String=app.resources.audio_catalog.get("sound_ids",{}).get(str(sound_id),"")
	if not name.is_empty():app.play_sound_id(sound_id,0,"Combat")

func update_spell_effects() -> void:
	for event in spell_events.duplicate():
		if event.map!=app.world.metadata.id:spell_events.erase(event);continue
		if app.elapsed>=float(event.at):spell_events.erase(event);play_skill_stage(event.skill,event.stage)
	for entity in app.world.entities:
		if entity.kind!="monster" or entity.hp<=0 or not entity.has("poison_until"):continue
		if app.elapsed>=float(entity.poison_until):entity.erase("poison_until");continue
		if app.elapsed<float(entity.get("poison_next",0)):continue
		entity.poison_next=app.elapsed+1.5
		app.apply_attack_hit(entity,{"damage":3+int(app.rules.state.level)/5,"skill":"poison","periodic":true})
