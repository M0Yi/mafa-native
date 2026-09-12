extends RefCounted
const MAP="m001"
const NPC="server:merchant:103"
const DURATION=180*60
var app
var warning_session:=""
var warning_stage:=0
func setup(host) -> void:app=host
func state() -> Dictionary:return app.rules.state.get("dark_temple",{})
func panel() -> void:
	app.game_panel("未知暗殿 · 老人的指引")
	app.panel.enable_button_navigation()
	app.label("老人可送你进入未知暗殿，停留三小时后返回出发处。当前资料没有实际扣除凭证或金币的命令。单机落点采用可通行位置，人数限制按本机玩家一人处理；不计怪物。")
	app.label("世界暂停时计时停止，退出期间不计时。提前使用回城石会回到边界村，并结束本次停留；离开暗殿也会结束计时。回到老人身边才能交付这里的委托。")
	app.button("进入未知暗殿 · 免费 · 180 分钟",enter)
func enter() -> bool:
	var npc: Dictionary=app.rules.story_npc(NPC)
	if not app.near_reference_npc(npc):app.info("请到连接通道的老人身边，并继续游戏后进入。");return false
	if state().get("active",false):app.info("已有暗殿行程，请先结束本次行程。");return false
	var origin: String=app.world.metadata.id
	var cell: Vector2i=app.world.player.cell
	if not app.enter_map(MAP,EditionRegion.destination(MAP),false):app.enter_map(origin,cell,false);return false
	var next: Dictionary=app.rules.state.duplicate(true)
	next.dark_temple={"active":true,"deadline":app.elapsed+DURATION,"return_map":origin,"return_cell":[cell.x,cell.y]}
	next.map=MAP;next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	EditionRules.Story.observe(next,"visit",{"map":MAP,"arrival":origin!=MAP})
	if not app.rules.apply(next,"dark_temple_enter"):
		var reason: String=app.rules.message
		app.enter_map(origin,cell,false);app.info(reason);return false
	app.windows.close_all();app.pending_message="已进入未知暗殿，三小时后返回老人身边；请留意怪物实际强弱。";return true
func expire() -> bool:
	if not app.gameplay.available() or not state().get("active",false) or app.world.metadata.id!=MAP:return false
	if app.elapsed<float(state().get("deadline",0)):return false
	var old_cell: Vector2i=app.world.player.cell
	var session: Dictionary=state().duplicate(true)
	var return_cell:=Vector2i(session.return_cell[0],session.return_cell[1])
	if not app.enter_map(session.return_map,return_cell,false):app.enter_map(MAP,old_cell,false);return false
	var next: Dictionary=app.rules.state.duplicate(true);next.dark_temple=session;next.dark_temple.active=false
	next.map=session.return_map;next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	EditionRules.Story.observe(next,"visit",{"map":next.map,"arrival":true})
	if not app.rules.apply(next,"dark_temple_recall"):
		var reason: String=app.rules.message
		app.enter_map(MAP,old_cell,false);app.pending_message=reason;return false
	app.windows.close_all();app.pending_message="暗殿停留时间已到，已返回老人所在通道。";return true
func update() -> void:
	if app.mode!="game" or app.world.paused or not state().get("active",false):return
	if app.world.metadata.id!=MAP or app.rules.state.hp<=0:
		var next: Dictionary=app.rules.state.duplicate(true);next.dark_temple=state().duplicate(true);next.dark_temple.active=false
		app.rules.apply(next,"dark_temple_end");return
	if app.elapsed>=float(state().deadline):expire();return
	var session: String=str(app.rules.character.id)+":"+str(state().deadline)
	if session!=warning_session:warning_session=session;warning_stage=0
	var remaining: float=float(state().deadline)-app.elapsed
	var stage:=2 if remaining<=60 else 1 if remaining<=300 else 0
	if stage>warning_stage:
		warning_stage=stage
		app.pending_message="暗殿停留%s，到时会返回老人所在通道。请先拾取需要的地面物品，停止不必要的追击；已保存的任务进度会保留。"%("不足一分钟" if stage==2 else "不足五分钟")
func time_text() -> String:
	if app.world.metadata.id!=MAP or not state().get("active",false):return ""
	var remaining:=maxi(0,ceili(float(state().deadline)-app.elapsed))
	return "暗殿剩余 %02d:%02d:%02d"%[remaining/3600,(remaining/60)%60,remaining%60]
