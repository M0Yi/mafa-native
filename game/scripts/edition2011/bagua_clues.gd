extends RefCounted
const NPC="server:merchant:108"
const COSTS=[3000,5000,10000,5000]
const CLUES=["第一阵：震 → 巽 → 坎 → 坤 → 离 → 兑 → 乾 → 艮 → 震。","第二阵：离 → 坤 → 兑 → 乾 → 坎 → 艮 → 震 → 巽 → 离。","第三阵：乾 → 兑 → 离 → 震 → 巽 → 坎 → 艮 → 坤 → 乾。","方位残记：离为十二时，坤为一时，震为九时，巽为十一时。其余方位原记录未写全。"]
static func valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=4
static func buy(rules,index: int,map_id: String,cell: Vector2i) -> bool:
	if rules.state.hp<=0 or not rules.story_near(NPC,map_id,cell):rules.message="请到老翁身边购买线索";return false
	var current:=int(rules.state.get("bagua_clues",0))
	if index!=current or index<0 or index>=COSTS.size():rules.message="这段线索已购买，或前一段尚未听完";return false
	if int(rules.state.gold)<COSTS[index]:rules.message="这段线索需要 %d 金币"%COSTS[index];return false
	var next: Dictionary=rules.state.duplicate(true);next.gold-=COSTS[index];next.bagua_clues=current+1
	rules.message=CLUES[index]
	return rules.apply(next,"bagua_clue","bagua-clue:"+str(rules.character.id)+":"+str(index))
static func panel(app) -> void:
	app.game_panel("老翁 · 八卦阵线索")
	app.panel.enable_button_navigation()
	var current:=int(app.rules.state.get("bagua_clues",0))
	for index in range(current):app.label(CLUES[index])
	app.label("已购买的线索保存在本机，之后可免费查看。")
	if current>=4:
		app.label("四段线索已记录。进入后可沿迷宫寻找制作商人，由商人免费送回这里（单机重建返程）。现有地图仍包含单机补建通路。")
		app.button("进入八卦迷宫",func():travel(app,false))
		return
	app.button("听第 %d 段线索 · %d 金币"%[current+1,COSTS[current]],func():
		if not app.gameplay.available():return
		var ok:=buy(app.rules,current,app.world.metadata.id,app.world.player.cell)
		var message: String=app.rules.message
		if ok:panel(app)
		app.info(message))

static func travel(app,returning: bool) -> bool:
	var source: Dictionary=app.rules.story_npc("server:merchant:109" if returning else NPC)
	if not app.gameplay.available() or not app.near_reference_npc(source):app.info("请继续游戏并回到办理传送的人物身边");return false
	if not returning and int(app.rules.state.get("bagua_clues",0))<4:app.info("请先听完四段阵法线索");return false
	var original_map: String=app.world.metadata.id;var original_cell: Vector2i=app.world.player.cell
	var target: String="q011" if returning else "q014"
	var cell:=Vector2i(138,120) if returning else Vector2i(54,54)
	if not app.enter_map(target,cell,false):app.enter_map(original_map,original_cell,false);return false
	var next: Dictionary=app.rules.state.duplicate(true);next.map=target;next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	EditionRules.Story.observe(next,"visit",{"map":target,"arrival":original_map!=target})
	if not app.rules.apply(next,"bagua_return" if returning else "bagua_enter"):
		var message: String=app.rules.message;app.enter_map(original_map,original_cell,false);app.info(message);return false
	app.windows.close_all();app.pending_message="已返回老翁身边 · 单机重建返程" if returning else "已进入八卦迷宫，找到制作商人后可免费返回老翁处"
	return true
