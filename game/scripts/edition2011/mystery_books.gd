extends RefCounted
const NPC="server:merchant:109"
const PRICE=1200000
const WEAPONS={"战士":{"product":"ref:35","count":5},"法师":{"product":"ref:55","count":3},"道士":{"product":"ref:32","count":4}}
const BOOKS={"战士":"ref:158","法师":"ref:188","道士":"ref:149"}
static func purchase(rules,map_id: String,cell: Vector2i) -> bool:
	if rules.state.hp<=0 or not rules.story_near(NPC,map_id,cell):rules.message="请到神秘商人成男身边购买";return false
	var item: String=BOOKS.get(rules.character.job,"")
	if item.is_empty() or not rules.ITEMS.get(item,{}).has("skill_book"):rules.message="本职业技能书配置缺失";return false
	if int(rules.state.gold)<PRICE:rules.message="购买技能书需要 1200000 金币";return false
	var next: Dictionary=rules.state.duplicate(true);next.gold-=PRICE;rules.count_item(next,item,1)
	rules.message="已购买"+str(rules.ITEMS[item].name)+"技能书，请在背包中使用学习"
	return rules.apply(next,"mystery_skill_book")
const PAGE_IDS=["成男 · 神秘商店技能书","成男 · 神秘武器配方","神秘打造 · 采矿说明","成男 · 祝福油配方"]
static func open_page(app,title: String,dimensions:=Vector2(416,360)) -> void:
	# These pages are one NPC flow; unrelated inventory/quest windows remain open.
	for id in PAGE_IDS:
		if id!=title:app.windows.close(id)
	app.game_panel(title,dimensions)

static func panel(app) -> void:
	open_page(app,"成男 · 神秘商店技能书")
	app.panel.enable_button_navigation()
	var item: String=BOOKS.get(app.rules.character.job,"")
	if item.is_empty():app.label("本职业商品配置缺失");return
	if not app.rules.ITEMS[item].has("skill_book"):
		app.label("困魔咒 · 1200000 金币：学习与技能效果尚未接入，目前不能购买，不扣金币。")
		return
	app.label(app.rules.skill_book_brief(item))
	app.label("购买只把技能书放入背包，使用后才学习。")
	app.button("查看本职业武器配方与材料来源",func():materials_panel(app))
	app.button("制作祝福油",func():oil_panel(app))
	app.button("购买"+str(app.rules.ITEMS[item].name)+" · 1200000 金币",func():
		if not app.gameplay.available():return
		purchase(app.rules,app.world.metadata.id,app.world.player.cell)
		app.info(app.rules.message))

static func material_summary(state: Dictionary,job: String) -> String:
	if not WEAPONS.has(job):return "本职业配方配置缺失"
	var recipe: Dictionary=WEAPONS[job]
	var qualified:=0
	var unknown:=0
	for item in state.get("items",[]):
		if item.get("container")!="inventory" or item.get("type")!="ref:132":continue
		if not item.has("purity"):unknown+=int(item.count)
		elif int(item.purity)>=18:qualified+=int(item.count)
	return "%s：金条 ×1、纯度至少18的金矿 ×%d\n背包合格金矿 %d/%d · 未知纯度 %d"%[EditionRules.ITEMS[recipe.product].name,recipe.count,qualified,recipe.count,unknown]+"\n金条：背包%d / 仓库%d（需要1根）"%[int(state.get("inventory",{}).get("ref:226",0)),int(state.get("warehouse",{}).get("ref:226",0))]

static func materials_panel(app) -> void:
	open_page(app,"成男 · 神秘武器配方",Vector2(520,450))
	app.label(material_summary(app.rules.state,app.rules.character.job))
	app.label("未知纯度矿石不计入材料；制作成功后返回刘老头所在矿区。")
	app.label("金条兑换价：1002000金币；仓库材料请先取回。")
	var revision:=int(app.rules.state.get("revision",0))
	app.button("确认材料并制作",func():
		app.windows.confirm(material_summary(app.rules.state,app.rules.character.job)+"\n消耗以上材料制作一把武器，并返回刘老头所在矿区。",func():craft(app,revision)))
	app.button("采矿方法与配方说明",func():mining_help(app))
	app.button("寻找出售鹤嘴锄的比奇铁匠",func():app.approach_story_npc("server:merchant:56"))
	app.button("寻找金条兑换员",func():app.approach_story_npc("server:merchant:105"))
	app.button("查看金矿采集与掉落来源",func():
		preload("res://scripts/edition2011/peach_crafting.gd").sources_panel(app,{"name":"金矿来源（打造需要纯度至少18）","materials":{"ref:132":WEAPONS.get(app.rules.character.job,{"count":0}).count}}))
	app.button("返回技能书商店",func():panel(app))
	app.panel.enable_button_navigation()

static func craft(app,revision: int,make_oil:=false) -> bool:
	if not app.gameplay.available() or not app.near_reference_npc(app.rules.story_npc(NPC)):
		app.info("请继续游戏并回到成男身边制作");return false
	if int(app.rules.state.get("revision",0))!=revision:
		app.info("材料状态已变化，请重新打开配方确认");return false
	var recipe: Dictionary={"product":"ref:135"} if make_oil else WEAPONS.get(app.rules.character.job,{})
	if recipe.is_empty():app.info("本职业配方配置缺失");return false
	var next: Dictionary=app.rules.state.duplicate(true)
	if make_oil:
		if int(next.gold)<500000:app.info("制作祝福油需要500000金币");return false
		if int(next.inventory.get("ref:193",0))<5:app.info("背包中需要5瓶强效太阳水");return false
		next.gold-=500000;app.rules.count_item(next,"ref:193",-5)
	else:
		if int(next.inventory.get("ref:226",0))<1:app.info("背包中需要一根金条");return false
		if not EditionInventory.consume_graded_ore(next,"ref:132",int(recipe.count),18):
			app.info("背包中需要 %d 块纯度至少18的金矿，未知纯度不计入"%int(recipe.count));return false
		app.rules.count_item(next,"ref:226",-1)
	app.rules.count_item(next,recipe.product,1)
	if not EditionInventory.reconcile(next):app.info("背包没有空格容纳制成物品");return false
	var origin: String=app.world.metadata.id
	var origin_cell: Vector2i=app.world.player.cell
	if not app.enter_map("d002",Vector2i(-1,-1),false):
		app.enter_map(origin,origin_cell,false);app.info("返回地图加载失败，材料已保留");return false
	next.map="d002";next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	EditionRules.Story.observe(next,"craft",{"npc":NPC,"item":recipe.product})
	EditionRules.Story.observe(next,"visit",{"map":"d002","arrival":true})
	if not app.rules.apply(next,"mystery_oil" if make_oil else "mystery_weapon"):
		var reason: String=app.rules.message
		app.enter_map(origin,origin_cell,false);app.info(reason);return false
	app.windows.close_all();app.play_sound_id(106)
	app.pending_message="制作获得："+str(EditionRules.ITEMS[recipe.product].name)+" · 已返回刘老头所在矿区"
	return true

static func mining_help(app) -> void:
	open_page(app,"神秘打造 · 采矿说明",Vector2(520,450))
	app.label("比奇铁匠出售鹤嘴锄，22级可装备。到废矿入口至废矿区南部，面向矿壁使用攻击操作，矿石落地后拾取。矿镐损坏后需找铁匠修理。")
	app.label("单机采矿规则：纯度1–20，每处矿壁可挥镐200次，采空后10分钟游戏时间恢复。暂停和退出不推进游戏时间。")
	app.label("武器材料配方来自成男旧对白；矿脉位置、概率和纯度分布为单机重建。制作后按旧脚本返回刘老头所在矿区，落点使用单机默认位置。")
	app.button("返回本职业配方",func():materials_panel(app))
	app.panel.enable_button_navigation()

static func oil_panel(app) -> void:
	open_page(app,"成男 · 祝福油配方",Vector2(520,450))
	app.label("祝福油 ×1：500000金币、强效太阳水 ×5。")
	app.label("背包强效太阳水 %d/5 · 当前金币 %d"%[int(app.rules.state.inventory.get("ref:193",0)),int(app.rules.state.gold)])
	app.label("制作后返回刘老头所在矿区。使用会作用于当前武器，可能祝福、诅咒或无变化；无变化也消耗一瓶。")
	app.label("这不是宴席用的神秘水。材料在确认制作时扣除，仓库材料请先取回。")
	var revision:=int(app.rules.state.get("revision",0))
	app.button("确认材料并制作祝福油",func():app.windows.confirm("消耗500000金币和5瓶强效太阳水，获得1瓶祝福油并返回矿区？",func():craft(app,revision,true)))
	app.button("查看强效太阳水来源",func():preload("res://scripts/edition2011/peach_crafting.gd").sources_panel(app,{"name":"祝福油材料","materials":{"ref:193":5}}))
	app.button("返回技能书商店",func():panel(app))
	app.panel.enable_button_navigation()
