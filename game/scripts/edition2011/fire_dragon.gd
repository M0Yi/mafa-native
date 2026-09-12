class_name EditionFireDragon
extends RefCounted
const MAP="d2083"
const ENTRANCE="server:npc:10"
const GUARD="fire-dragon:guide"
const LANDING=Vector2i(44,84)
const GUARD_CELL=Vector2i(45,84)
const SURVEY=Vector2i(75,75)
const RENDER_BOUNDS=Rect2i(25,17,76,97)
var app
var warned_session:=""
func setup(host) -> void:app=host
func state() -> Dictionary:return app.rules.state.get("fire_dragon",{})
func objective_text() -> String:
	var lines: PackedStringArray=[]
	for id in ["story_dragon_trial","story_dragon_forge"]:
		if app.rules.state.quests.get(id)!="accepted":continue
		var quest: Dictionary=EditionRules.Story.quest(id)
		if EditionRules.Story.ready(app.rules.state,quest):
			lines.append(str(quest.title)+"：条件已满足，请返回任务人物交付。")
		else:
			lines.append(str(quest.title))
			for index in range(quest.objectives.size()):
				lines.append(EditionRules.Story.objective_text(app.rules.state,quest,index))
	if not lines.is_empty():
		lines.append("鳞片从地面拾取；已留在神殿的鳞片可找回，回程请找神殿接引员。")
		return "\n".join(lines)
	return "中央勘察已完成，可返回盟重办理交付；首领远征需先接取对应委托。" if state().get("surveyed",false) else "前往神殿中央完成勘察，再由接引员返回盟重。"

func supply_merchant() -> Dictionary:
	var regional: Dictionary=EditionRegion.data()
	var candidates: Array=[]
	for npc in regional.npcs:
		if not npc.get("enabled",false):continue
		var shop: Dictionary=regional.shops.get(npc.id,{})
		var goods: Array=shop.get("goods",[])
		if not goods.any(func(g):return g.get("type","")=="charm"):continue
		if not goods.any(func(g):return EditionRules.ITEMS.get(g.get("type",""),{}).get("material_bundle",{}).get("type","")=="poison"):continue
		candidates.append(npc)
	candidates.sort_custom(func(a,b):
		var pa:=0 if a.map==app.world.metadata.get("id","") else 1 if a.map=="3" else 2
		var pb:=0 if b.map==app.world.metadata.get("id","") else 1 if b.map=="3" else 2
		if pa!=pb:return pa<pb
		if pa==0:
			var da:=Vector2i(a.cell[0],a.cell[1]).distance_squared_to(app.world.player.cell)
			var db:=Vector2i(b.cell[0],b.cell[1]).distance_squared_to(app.world.player.cell)
			if da!=db:return da<db
		return str(a.id)<str(b.id))
	return {} if candidates.is_empty() else candidates[0]

func supplies_text() -> String:
	var lines: PackedStringArray=["出发准备 · 当前魔法 %d / %d"%[int(app.rules.state.mp),app.rules.max_mp()]]
	for id in ["talisman","poison"]:
		var skill: Dictionary=EditionSkills.DEFINITIONS[id]
		if app.rules.character.job!=skill.job:continue
		var learned: bool=app.rules.state.skills.has(id)
		lines.append(str(skill.name)+(" · 已学会" if learned else " · 尚未学会，需使用技能书"))
		for material in EditionSkills.material_costs(id):
			var count:=int(app.rules.state.inventory.get(material,0))
			lines.append("每次需要 %d 魔法、%s ×%d；背包 %d，仓库物品不能直接施法。"%[int(skill.mp),str(EditionRules.ITEMS[material].name),int(EditionSkills.material_costs(id)[material]),count])
	lines.append("红蓝药共用使用冷却；先留好回程与拾取空位，再决定是否出发。")
	return "\n".join(lines)

func time_text() -> String:
	if app.world.metadata.get("id","")!=MAP or not state().get("active",false):return ""
	var remaining:=maxi(0,ceili(float(state().get("deadline",0))-app.elapsed))
	return "神殿剩余 %02d:%02d"%[remaining/60,remaining%60]

func near(id: String) -> bool:
	if not app.gameplay.available():return false
	for npc in app.world.entities:
		if npc.id==id and Vector2(npc.cell[0]-app.world.player.cell.x,npc.cell[1]-app.world.player.cell.y).length()<=4:return true
	return false
func commit(next: Dictionary,action: String) -> bool:
	var ok: bool=app.rules.apply(next,action)
	if not ok:app.pending_message=app.rules.message
	return ok
func buy_permit() -> bool:
	if not near(ENTRANCE):app.pending_message="请回到盟重传送员身边";return false
	if app.rules.state.gold<500:app.pending_message="勘察凭证需要 500 金币";return false
	var next: Dictionary=app.rules.state.duplicate(true);next.fire_dragon=state().duplicate(true)
	next.gold-=500;next.fire_dragon.permits=int(state().get("permits",0))+1
	if not commit(next,"fire_dragon_permit"):return false
	app.play_sound_id(106);app.pending_message="已取得勘察凭证（单机任务计数）";return true
func enter() -> bool:
	if not near(ENTRANCE):app.pending_message="请回到盟重传送员身边";return false
	return enter_with_permit(LANDING)
func enter_passage(route: Dictionary) -> bool:
	if not app.gameplay.available() or route.get("target_map")!=MAP or route.get("map")!=app.world.metadata.id:return false
	if app.world.player.cell!=Vector2i(route.cell[0],route.cell[1]):return false
	return enter_with_permit(Vector2i(route.target_cell[0],route.target_cell[1]))
func enter_with_permit(destination: Vector2i) -> bool:
	if not app.gameplay.available():return false
	if int(state().get("permits",0))<1:app.pending_message="需要一张勘察凭证，请先向盟重传送员购买。";return false
	var old_map: String=app.world.metadata.id
	var old_cell: Vector2i=app.world.player.cell
	if not app.enter_map(MAP,destination,false):app.enter_map(old_map,old_cell,false);app.pending_message="神殿加载失败，凭证未扣除";return false
	var next: Dictionary=app.rules.state.duplicate(true);next.fire_dragon=state().duplicate(true)
	next.fire_dragon.permits=int(state().get("permits",0))-1;next.fire_dragon.active=true;next.fire_dragon.deadline=app.elapsed+1200
	next.map=MAP;next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	EditionRules.Story.observe(next,"visit",{"map":MAP,"arrival":old_map!=MAP})
	if not commit(next,"fire_dragon_enter"):
		var failure: String=app.rules.message
		app.enter_map(old_map,old_cell,false);app.pending_message=failure+"；凭证未扣除，已留在原入口。";return false
	app.windows.close_all();app.pending_message=objective_text()+"\n本次停留时限 20 分钟。";return true
func leave(expired:=false) -> bool:
	if not app.gameplay.available() or app.world.metadata.id!=MAP:return false
	if not expired and not near(GUARD):app.pending_message="请靠近神殿接引员";return false
	var old_cell: Vector2i=app.world.player.cell
	if not app.enter_map("3",EditionRegion.destination("3"),false):app.enter_map(MAP,old_cell,false);return false
	var next: Dictionary=app.rules.state.duplicate(true);next.fire_dragon=state().duplicate(true);next.fire_dragon.active=false
	next.map="3";next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	EditionRules.Story.observe(next,"visit",{"map":"3","arrival":true})
	if not commit(next,"fire_dragon_return"):
		app.enter_map(MAP,old_cell,false);return false
	app.windows.close_all();app.pending_message="已返回盟重安全区";return true
func claim() -> bool:
	if not near(ENTRANCE):return false
	if not state().get("surveyed",false) or state().get("claimed",false):app.pending_message="尚未完成勘察，或奖励已领取";return false
	var next: Dictionary=app.rules.state.duplicate(true);next.fire_dragon=state().duplicate(true);next.fire_dragon.claimed=true;next.gold+=500
	app.rules.add_xp(next,200)
	if not commit(next,"fire_dragon_survey_reward"):return false
	app.play_sound_id(106);app.pending_message="首次勘察完成：500 金币与基础经验 200（仅一次）";return true
func update() -> void:
	if app.mode!="game" or not state().get("active",false):return
	if not app.gameplay.available():return
	if app.world.metadata.id!=MAP:
		var next: Dictionary=app.rules.state.duplicate(true);next.fire_dragon=state().duplicate(true);next.fire_dragon.active=false;commit(next,"fire_dragon_session_end");return
	if app.elapsed>=float(state().get("deadline",0)):leave(true);return
	var session: String=str(app.rules.character.id)+":"+str(state().get("deadline",0))
	if float(state().get("deadline",0))-app.elapsed<=60 and warned_session!=session:
		warned_session=session
		app.pending_message="神殿停留不足一分钟，到时将返回盟重；请及时拾取地面鳞片，背包里的材料会保留，未拾取鳞片可再次入殿找回。"

	if not state().get("surveyed",false) and (app.world.player.cell-SURVEY).length()<=2:
		var next: Dictionary=app.rules.state.duplicate(true);next.fire_dragon=state().duplicate(true);next.fire_dragon.surveyed=true
		if commit(next,"fire_dragon_survey"):app.pending_message="神殿中央勘察完成，请返回盟重传送员领取首次奖励"
func panel(npc: Dictionary) -> void:
	app.game_panel("火龙神殿 · 单机勘察")
	app.panel.enable_button_navigation()
	app.label(objective_text())
	app.label(supplies_text())
	if npc.id==ENTRANCE and app.rules.character.job=="道士":
		var merchant:=supply_merchant()
		if not merchant.is_empty():
			app.label("补给商出售护身符与药粉包；药粉买回后需在背包使用拆分，价格及库存以商店为准。")
			app.button("寻找道术补给："+str(merchant.name),func():app.approach_story_npc(merchant.id))

	if not time_text().is_empty():app.label(time_text()+" · 到时返回盟重")
	app.label("入口、费用和勘察任务为单机适配；首领地火预警为单机重建；完整历史机制尚未核验。\n地面出现红框时及时离开，1.2 秒后结算该区域。")
	if npc.id==ENTRANCE:
		app.label("勘察凭证：%d · 首次奖励：%s"%[int(state().get("permits",0)),"已领取" if state().get("claimed",false) else "待交付" if state().get("surveyed",false) else "未完成"])
		app.button("购买勘察凭证 · 500 金币",func():buy_permit();panel(npc))
		app.button("消耗一张凭证进入火龙殿",enter)
		var claimed: bool=state().get("claimed",false)
		var surveyed: bool=state().get("surveyed",false)
		var reward_button: Button=app.button("首次勘察奖励已领取" if claimed else "领取首次勘察奖励",func():claim();panel(npc))
		reward_button.name="SurveyReward"
		reward_button.disabled=claimed or not surveyed
		reward_button.tooltip_text="这份首次奖励已经领取，故事委托可从下方入口办理。" if claimed else "先完成神殿中央勘察，再回到盟重领取。" if not surveyed else "领取首次勘察奖励；不替代故事委托交付。"
		app.label("故事委托需另行接取和交付；首次勘察奖励不代替故事奖励。")
		app.button("查看勘察与远征委托",func():
			if near(ENTRANCE):app.show_story(npc))
		app.button("手柄勘察与远征委托",func():
			if near(ENTRANCE):app.show_controller_story(npc))
	else:
		app.label("中央勘察点 [75,75]；可随时由此返回盟重。")
		app.button("前往中央勘察点",func():
			if near(GUARD):app.world.player.go_to(SURVEY);app.windows.close_all())
		app.button("返回盟重安全区",leave)
