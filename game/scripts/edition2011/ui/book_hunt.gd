extends VBoxContainer
const Story=preload("res://scripts/edition2011/story.gd")
const Planner=preload("res://scripts/edition2011/story_routes.gd")
var app
var rows: Array=[]
var cursor:=0
var list:=ItemList.new()
var detail:=Label.new()
var route: Array=[]
var source_map:=""
var transport: Dictionary={}
func setup(host,objective: Dictionary) -> void:
	app=host
	list.custom_minimum_size=Vector2(0,245);add_child(list)
	for drop in Story.skill_book_drops(objective,EditionRules.ITEMS,app.rules.character.job):
		for mid in drop.maps:
			if not app.resources.map_by_id.has(mid):continue
			rows.append({"monster":drop.monster,"map":mid,"prob":drop.prob})
			list.add_item("%s · %s · %s"%[drop.monster,app.resources.map_by_id[mid].name,drop.prob])
	list.item_selected.connect(func(index):cursor=index)
	list.item_activated.connect(func(index):cursor=index;choose())
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.text="选择怪物与区域 · A 查看路线 · B 关闭\n配置概率不保证掉书；到达后自行战斗、拾取并使用技能书。";add_child(detail)
	var go:=Button.new();go.text="查看路线 / 步行下一入口";go.pressed.connect(choose);add_child(go)
	if not rows.is_empty():list.select(0)
func choose() -> void:
	if not app.gameplay.available():app.info("请继续游戏后寻找技能书来源");return
	if not transport.is_empty():
		if app.world.metadata.id!=source_map:
			transport.clear();list.show();detail.text="地图已变化，请重新选择来源。";return
		app.approach_story_npc(transport.npc);return
	if not route.is_empty():
		if app.world.metadata.id!=source_map:route.clear();list.show();detail.text="地图已变化，请重新选择来源。";return
		var at:=Vector2i(route[0].cell[0],route[0].cell[1])
		if app.world.player.cell==at:detail.text="已在门槛，请先离开一格再进入。";return
		if app.world.player.go_to(at):app.windows.close_all();app.pending_message="正在步行前往掉书区域的下一入口；换图后可重新查看来源。"
		else:detail.text="到入口的道路受阻，请调整位置后重试。"
		return
	if rows.is_empty():return
	var row: Dictionary=rows[cursor]
	if row.map==app.world.metadata.id:
		app.approach_story_objective({"type":"kill","maps":[row.map],"names":[row.monster],"count":1});return
	if row.map==EditionFireDragon.MAP:app.show_story_route(row.map);return
	source_map=app.world.metadata.id
	transport=app.story_transport(row.map)
	if not transport.is_empty():
		list.hide();detail.text="%s · %s\n%s\nA %s · B 返回来源"%[row.monster,app.resources.map_by_id[row.map].name,transport.text,transport.button];return
	route=Planner.plan(app.resources.connections.by_map,source_map,row.map,app.world.player.cell,app.world.navigation)
	if route.is_empty():detail.text="当前位置没有可步行路线，请向本地传送员询问。";return
	list.hide();detail.text="%s · %s\n共 %d 段通路。A 步行下一入口 · B 返回来源\n"%[row.monster,app.resources.map_by_id[row.map].name,route.size()]
	for leg in route.slice(0,4):detail.text+="%s → %s\n"%[app.resources.map_by_id[leg.map].name,app.resources.map_by_id[leg.target_map].name]
	if route.size()>4:detail.text+="其余 %d 段换图后继续确认。"%(route.size()-4)
func _input(event: InputEvent) -> void:
	if app==null or app.mode!="game" or app.windows.has_modal() or app.windows.order.is_empty() or app.windows.order.back()!="技能书掉落来源":return
	if not event is InputEventJoypadButton or not event.pressed:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_A:choose()
		JOY_BUTTON_B:
			if not route.is_empty() or not transport.is_empty():route.clear();transport.clear();list.show();detail.text="选择来源 · A 查看路线 · B 关闭"
			else:app.windows.close("技能书掉落来源")
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			if route.is_empty() and transport.is_empty() and not rows.is_empty():
				cursor=posmod(cursor+(1 if event.button_index==JOY_BUTTON_DPAD_DOWN else -1),rows.size());list.select(cursor);list.ensure_current_is_visible()
