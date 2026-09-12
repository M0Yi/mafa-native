extends RefCounted
const Session=preload("res://scripts/edition2011/cook_trial_state.gd")
const NPC="server:merchant:50"
var app
func setup(host) -> void:app=host
func state() -> Dictionary:return app.rules.state.get("cook_trial",{})
func definition() -> Dictionary:
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/cook-trials.json"))
	for trial in config.trials:
		if trial.job==app.rules.character.job:return trial
	return {}
func panel() -> void:
	app.game_panel("森林老人 · 厨师考验")
	app.panel.enable_button_navigation()
	app.label("按职业接受一次考验：一分钟内击败对手，并亲自拾取地上的头盔。时间到后返回老人身边交付；暂停与退出期间不计时。")
	if app.rules.state.quests.get("story_feast_cook_trail","")!="done":
		app.label("请先完成寻找厨师的委托，按线索找到森林老人。")
		return
	if state().get("claimed",false):
		app.label("你已交付头盔，老人答应协助料理。请登记完成“让老人答应出山”，再回朴铁匠处接取“特殊油的线索”。")
	elif state().get("active",false):
		app.label("考验正在进行，请完成挑战并等待返回。")
	elif state().is_empty():
		app.button("接受考验 · 60 秒",enter)
	else:
		app.label("已取得胜利，请将本次拾取的头盔放回背包交付。" if state().get("won",false) and state().get("picked",false) else "本次考验尚未取得完整凭证，可以放弃战果后重试。")
		if state().get("won",false) and state().get("picked",false):app.button("交付头盔 ×1",claim)
		app.button("放弃本次战果并重试",request_reset)
func claim() -> bool:
	if not app.gameplay.available():return false
	var ok: bool=app.rules.finish_cook_trial(app.world.metadata.id,app.world.player.cell)
	var message: String=app.rules.message
	if ok:panel()
	app.info(message)
	return ok
func request_reset() -> void:
	app.windows.confirm("放弃本次未交付战果？旧地面凭证将移除，背包物品保留；需重新击败对手并拾取新凭证。",reset)
func reset() -> bool:
	if not app.gameplay.available():return false
	var ok: bool=app.rules.reset_cook_trial(app.world.metadata.id,app.world.player.cell)
	var message: String=app.rules.message
	if ok:panel()
	app.info(message)
	return ok
func enter() -> bool:
	var npc: Dictionary=app.rules.story_npc(NPC)
	if not app.gameplay.available() or not app.near_reference_npc(npc):app.info("请继续游戏并回到沃玛森林老人身边");return false
	var origin: Vector2i=app.world.player.cell
	var current: Dictionary=app.rules.state.duplicate(true);current.map=app.world.metadata.id
	var session:=Session.begin(current,app.rules.character.job,origin,app.elapsed)
	if session.is_empty():app.info("请先完成寻找厨师的委托，并处理上次考验战果");return false
	var trial:=definition()
	if trial.is_empty():return false
	if not app.enter_map(session.map,Vector2i(trial.proposed_player_cell[0],trial.proposed_player_cell[1]),false):app.enter_map("1",origin,false);return false
	var next: Dictionary=app.rules.state.duplicate(true);next.cook_trial=session;next.map=session.map;next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	if not app.rules.apply(next,"cook_trial_enter"):
		var reason: String=app.rules.message;app.enter_map("1",origin,false);app.info(reason);return false
	ensure_monster();app.windows.close_all();app.pending_message="厨师考验开始，一分钟后返回。战果头盔需从地面拾取。";return true
func snapshot() -> Dictionary:
	if not state().get("active",false) or state().get("won",false) or app.world.metadata.id!=state().map:return {}
	for monster in app.world.entities:
		if monster.get("cook_attempt","")!=state().id or monster.hp<=0:continue
		var brain: Dictionary=app.world.actors.brains.get(monster.id,{})
		var result: Dictionary={"hp":int(monster.hp),"mp":int(monster.get("mp",0)),"cell":monster.cell.duplicate(),"direction":int(monster.get("direction",0)),"cooldown":float(brain.get("cooldown",0)),"wait":maxf(0,float(brain.get("wait",0))),"walk_rest":maxf(0,float(brain.get("walk_rest",0)))}
		var trapped: Dictionary=preload("res://scripts/edition2011/trap_status.gd").snapshot(monster,app.elapsed)
		if not trapped.is_empty():result.trap=trapped
		return result
	return {}
func ensure_monster(override: Dictionary={}) -> void:
	if not state().get("active",false) or state().get("won",false) or app.world.metadata.id!=state().map:return
	var id: String="cook:"+str(state().id)
	if app.world.entities.any(func(e):return e.id==id):return
	var saved: Dictionary=override if not override.is_empty() else state().get("monster",{})
	var trial:=definition();var preferred:=Vector2i(trial.proposed_monster_cell[0],trial.proposed_monster_cell[1])
	if not saved.is_empty():preferred=Vector2i(saved.cell[0],saved.cell[1])
	var candidates: Array[Vector2i]=[]
	for y in range(app.world.navigation.size.y):
		for x in range(app.world.navigation.size.x):
			var cell:=Vector2i(x,y)
			if cell!=app.world.player.cell and app.world.navigation.walkable(cell):candidates.append(cell)
	candidates.sort_custom(func(a,b):return a.distance_squared_to(preferred)<b.distance_squared_to(preferred))
	for cell in candidates:
		if app.world.navigation.path(app.world.player.cell,cell).is_empty():continue
		var source:={"runtime_id":id,"name":trial.source_monster,"interval":60,"range":10,"x":cell.x,"y":cell.y}
		var monster: Dictionary=EditionRegion.entity_from(source,{"raw":trial.monster_raw,"profile":trial.monster_profile,"drops":[]},id,-1,cell,0)
		monster.cook_attempt=state().id;monster.map=state().map;monster.passive=false
		if not saved.is_empty():
			monster.hp=clampi(int(saved.hp),1,int(monster.max_hp));monster.mp=clampi(int(saved.mp),0,int(monster.max_mp));monster.direction=int(saved.direction)
		if saved.has("trap"):preload("res://scripts/edition2011/trap_status.gd").restore(monster,saved.trap,app.elapsed)
		app.world.entities.append(monster)
		app.world.actors.mover(monster)
		if not saved.is_empty():
			var brain: Dictionary=app.world.actors.brains.get(id,{})
			for key in ["cooldown","wait","walk_rest"]:brain[key]=float(saved[key])
			app.world.actors.brains[id]=brain
		return
	app.pending_message="挑战怪物没有可达落点，请退出后重试"
func expire() -> bool:
	if not app.gameplay.available() or not Session.due(state(),app.elapsed) or app.world.metadata.id!=state().map:return false
	var original: Dictionary=state().duplicate(true);var old_cell: Vector2i=app.world.player.cell
	var live_monster:=snapshot()
	var target:=Vector2i(original.return_cell[0],original.return_cell[1])
	if not app.enter_map(original.return_map,target,false):app.enter_map(original.map,old_cell,false);return false
	var next: Dictionary=app.rules.state.duplicate(true);next.cook_trial=original.duplicate(true);next.cook_trial.active=false;next.map=original.return_map;next.cell=[app.world.player.cell.x,app.world.player.cell.y];next.time=app.elapsed
	next.trapped_monsters=app.region.trap_snapshots(app.world)
	if not app.rules.apply(next,"cook_trial_recall"):
		var reason: String=app.rules.message;app.enter_map(original.map,old_cell,false);ensure_monster(live_monster);app.pending_message=reason;return false
	app.windows.close_all();app.pending_message="考验时间已到，已返回沃玛森林老人身边";return true
func update() -> void:
	if app.mode!="game" or app.world.paused or not state().get("active",false):return
	if app.world.metadata.id!=state().map or app.rules.state.hp<=0:
		var next: Dictionary=app.rules.state.duplicate(true);next.cook_trial=state().duplicate(true);next.cook_trial.active=false;app.rules.apply(next,"cook_trial_end");return
	if Session.due(state(),app.elapsed):expire();return
	ensure_monster()
func time_text() -> String:
	if not state().get("active",false) or app.world.metadata.id!=state().map:return ""
	return "厨师考验剩余 %02d 秒"%maxi(0,ceili(float(state().deadline)-app.elapsed))
