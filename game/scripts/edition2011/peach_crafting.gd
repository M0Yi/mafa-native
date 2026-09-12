extends RefCounted
const NPC="server:merchant:126"
static func recipes() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/peach-recipes.json")).recipes
static func craft(rules,map_id: String,cell: Vector2i,product: String,revision: int) -> bool:
	if not rules.story_near(NPC,map_id,cell) or rules.state.hp<=0:rules.message="请到桃源合成师身边办理";return false
	if int(rules.state.get("revision",0))!=revision:rules.message="物品状态已变化，请重新查看配方后确认";return false
	var matches: Array=recipes().filter(func(r):return r.product==product)
	if matches.is_empty():rules.message="此人物没有这项配方";return false
	var recipe: Dictionary=matches[0]
	if int(rules.state.gold)<int(recipe.cost):rules.message="合成需要 %d 金币"%int(recipe.cost);return false
	for id in recipe.materials:
		if int(rules.state.inventory.get(id,0))<int(recipe.materials[id]):rules.message="背包材料不足："+str(EditionRules.ITEMS[id].name);return false
	var next: Dictionary=rules.state.duplicate(true)
	for id in recipe.materials:rules.count_item(next,id,-int(recipe.materials[id]))
	rules.count_item(next,product,1);next.gold-=int(recipe.cost)
	EditionRules.Story.observe(next,"craft",{"npc":NPC,"item":product})
	rules.message="合成获得："+str(recipe.name)
	return rules.apply(next,"peach_craft")
static func panel(app,npc: Dictionary) -> void:
	app.game_panel("桃源合成",Vector2(480,440));app.story_npc_button(npc)
	app.label("选择配方后确认材料。仅使用背包物品，穿戴和仓库中的物品不参与。")
	for recipe in recipes():
		app.button("材料来源 · "+str(recipe.name),func():sources_panel(app,recipe))
		app.button(str(recipe.name)+" · "+str(int(recipe.cost))+" 金币",func():
			if not app.near_reference_npc(npc):app.info("请回到合成师身边，并继续游戏后办理");return
			var text:=confirmation_text(app.rules,recipe)
			var revision:=int(app.rules.state.get("revision",0))
			app.windows.confirm(text,func():
				if not app.near_reference_npc(npc):app.info("请回到合成师身边，并继续游戏后办理");return
				if craft(app.rules,app.world.metadata.id,app.world.player.cell,recipe.product,revision):app.play_sound_id(106)
				app.info(app.rules.message)))
	app.panel.enable_button_navigation()

static func material_sources(type: String) -> Array:
	if type=="ref:226":return [{"exchange":"server:merchant:105","cost":1002000}]
	var catalog:=EditionRegion.data();var result: Array=[]
	var name: String=EditionRules.ITEMS.get(type,{}).get("name","")
	for monster in catalog.monsters:
		var definition: Dictionary=catalog.monsters[monster]
		if not definition.enabled:continue
		var drops: Array=definition.drops.filter(func(d):return d.get("name","")==name)
		if drops.is_empty():continue
		var maps: Array=[]
		for spawn in catalog.spawns:
			if spawn.name==monster and int(spawn.get("placed_count",0))>0 and spawn.get("status","") in ["enabled","placement_gap"]:
				var mid: String=spawn.mapName.to_lower()
				if mid not in maps:maps.append(mid)
		if maps.is_empty():continue
		result.append({"monster":monster,"level":int(definition.raw.lvl),"maps":maps,"prob":drops[0].prob})
	result.sort_custom(func(a,b):return a.level<b.level if a.level!=b.level else a.monster<b.monster)
	return result

static func sources_panel(app,recipe: Dictionary,page:=0) -> void:
	app.game_panel("合成材料来源",Vector2(520,450))
	page=maxi(0,page)
	var has_more:=false
	app.label(str(recipe.name)+" · 所需材料与当前背包 · 第%d页"%(page+1))
	for type in recipe.materials:
		app.label("%s ×%d · 背包%d / 仓库%d"%[EditionRules.ITEMS[type].name,int(recipe.materials[type]),int(app.rules.state.inventory.get(type,0)),int(app.rules.state.warehouse.get(type,0))])
		var mineable: bool=type in preload("res://scripts/edition2011/mining.gd").ORES
		if mineable:
			app.label("采矿：22级装备鹤嘴锄，在废矿矿壁挥镐，产出后地面拾取。纯度1–20，矿种与纯度随机（单机重建）。")
			if type=="ref:132":app.label("成男打造仅计入纯度至少18的金矿；怪物掉落未标纯度时不能用于该配方。")
			app.button("前往废矿寻找矿壁",func():
				var current: String=app.world.metadata.id
				var target: String=current if current in preload("res://scripts/edition2011/mining.gd").MAPS else "d401"
				app.approach_story_objective({"type":"mine","map":target,"count":1}))
		var sources:=material_sources(type)
		if sources.is_empty() and not mineable:app.label("暂未找到已接入的获取来源。")
		for row in sources.slice(page*3,page*3+3):
			if row.has("exchange"):
				var npc: Dictionary=app.rules.story_npc(row.exchange)
				app.label("%s · %s：1002000金币兑换金条×1"%[npc.name,app.resources.map_by_id[npc.map].name])
				app.button("寻找金条兑换人物",func():app.approach_story_npc(row.exchange))
			else:
				var names: PackedStringArray=[]
				for mid in row.maps.slice(0,2):names.append(str(app.resources.map_by_id.get(mid,{}).get("name",mid)))
				app.label("%s · 等级%d · %s · 基础掉落%s"%[row.monster,row.level,"、".join(names),row.prob])
				app.button("查看分布与路线 · "+str(row.monster),func():source_maps_panel(app,recipe,row,page))
		if sources.size()>(page+1)*3:has_more=true
		if sources.size()>3:app.label("共%d种已登记来源，本页第%d–%d种。"%[sources.size(),mini(page*3+1,sources.size()),mini(page*3+3,sources.size())])
	app.label("怪物来源优先列出较低等级者；概率为目录中的单次基础值，并非保证掉落。掉落物需在地面拾取，仓库材料需先取回背包。")
	if page>0:app.button("上一页来源",func():sources_panel(app,recipe,page-1))
	if has_more:app.button("下一页来源",func():sources_panel(app,recipe,page+1))
	app.panel.enable_button_navigation()

static func confirmation_text(rules,recipe: Dictionary) -> String:
	var text:="合成 "+str(recipe.name)+"\n手续费："+str(int(recipe.cost))+" 金币\n将消耗："
	for id in recipe.materials:
		var remaining:=int(recipe.materials[id]);var candidates: Array=rules.state.items.filter(func(i):return i.container=="inventory" and i.type==id);candidates.reverse()
		for item in candidates:
			var count:=mini(remaining,int(item.count));remaining-=count
			text+="\n%s ×%d · 背包格%d%s"%[EditionRules.ITEMS[id].name,count,int(item.slot)+1," · 耐久%d%%"%int(item.durability) if EditionRules.ITEMS[id].has("slot") else ""]
			if remaining==0:break
		if remaining>0:text+="\n还缺 %s ×%d"%[EditionRules.ITEMS[id].name,remaining]
	return text

static func source_maps_panel(app,recipe: Dictionary,source: Dictionary,source_page: int,page:=0) -> void:
	app.game_panel("材料怪物分布",Vector2(520,450))
	page=maxi(0,page)
	app.label(str(source.monster)+" · 已登记分布 · 第%d页"%(page+1))
	app.label("地图有刷新记录不代表当前有存活目标；路线沿用现有房门和传送规则，入场费用与凭证仍需满足。")
	for mid in source.maps.slice(page*6,page*6+6):
		var name: String=str(app.resources.map_by_id.get(mid,{}).get("name",mid))
		app.button("查看路线 · "+name,func():app.show_story_route(mid))
	if page>0:app.button("上一页地图",func():source_maps_panel(app,recipe,source,source_page,page-1))
	if (page+1)*6<source.maps.size():app.button("下一页地图",func():source_maps_panel(app,recipe,source,source_page,page+1))
	app.button("返回材料来源",func():
		app.windows.close("材料怪物分布")
		sources_panel(app,recipe,source_page))
	app.panel.enable_button_navigation()
