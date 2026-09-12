extends VBoxContainer
const Story=preload("res://scripts/edition2011/story.gd")
var app
var binding_parts: Array=[]
var skill_parts: Array=[]
var repair_parts: Array=[]
var progress_parts: Array=[]
var material_clock: int=-1
var material_parts: Array=[]
var status_part: Dictionary={}
var details_revision: int=-1
var quest_states: Dictionary={}
var npc: Dictionary={}
var rows: Array=[]
var cursor:=0
var reading:=false
var abandon_id:=""
var related_from:=""
var prerequisites:=false
var show_completed:=false
var navigation_history: Array=[]
var list:=ItemList.new()
var text:=RichTextLabel.new()
var hint:=Label.new()
func setup(host,person: Dictionary) -> void:
	app=host;npc=person.duplicate(true);size_flags_horizontal=Control.SIZE_EXPAND_FILL
	app.windows.modal.window_input.connect(_abandon_input)
	app.windows.modal.visibility_changed.connect(func():
		if not app.windows.modal.visible:abandon_id="")
	list.custom_minimum_size=Vector2(0,210);list.add_theme_font_size_override("font_size",17);add_child(list)
	list.item_selected.connect(func(index):cursor=index)
	list.item_activated.connect(func(index):cursor=index;open_detail())
	text.custom_minimum_size=Vector2(0,285);text.bbcode_enabled=false;text.add_theme_font_size_override("normal_font_size",15);add_child(text)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_font_size_override("font_size",14);add_child(hint);refresh()
func refresh(preserve_selection: bool=true) -> void:
	quest_states=app.rules.state.get("quests",{}).duplicate(true)
	var selected_id: String=rows[cursor].id if preserve_selection and cursor>=0 and cursor<rows.size() else ""
	rows.clear();list.clear()
	var required: Array=Story.quest(related_from).get("requires",[]) if prerequisites else []
	if prerequisites:
		for id in required:
			var old: Dictionary=EditionVillage.quest(id)
			if not old.is_empty() and visible_task(old,true,true):rows.append({"id":id,"novice":true});list.add_item(old.title+" · "+EditionVillage.progress(app.rules.state,old))
	if related_from.is_empty() and npc.id=="border:elder":
		for q in EditionVillage.quests():
			if visible_task(q,true):rows.append({"id":q.id,"novice":true});list.add_item(q.title+" · "+EditionVillage.progress(app.rules.state,q))
	for q in Story.data().quests:
		if not visible_task(q,false,prerequisites):continue
		if not related_from.is_empty():
			if prerequisites:
				if q.id not in required:continue
			elif related_from not in q.requires:continue
		elif not Story.involves_npc(app.rules.state,q,npc.id):continue
		rows.append({"id":q.id,"novice":false});list.add_item(q.title+" · "+status(q))
	if related_from.is_empty():
		var order: Dictionary={}
		for i in range(rows.size()):order[rows[i].id]=i
		rows.sort_custom(func(a,b):
			var pa:=row_priority(a);var pb:=row_priority(b)
			return pa<pb if pa!=pb else order[a.id]<order[b.id])
		list.clear()
		for row in rows:
			var q: Dictionary=EditionVillage.quest(row.id) if row.novice else Story.quest(row.id)
			list.add_item(q.title+" · "+(EditionVillage.progress(app.rules.state,q) if row.novice else status(q)))
	cursor=clampi(cursor,0,maxi(0,rows.size()-1));reading=false;list.show();text.hide()
	if not selected_id.is_empty():
		for i in range(rows.size()):
			if rows[i].id==selected_id:cursor=i;break
	if not rows.is_empty():list.select(cursor);list.ensure_current_is_visible()
	hint.text="上下选择 · A 查看委托 · B 返回上一任务" if not related_from.is_empty() else "上下选择 · A 查看委托 · B 关闭 · Y 原有服务"
	if related_from.is_empty():hint.text+=" · X 返回当前" if show_completed else " · X 已完成"
	if rows.is_empty():hint.text=("暂无已完成委托。\n" if show_completed else "暂无可办理委托。\n")+hint.text
func visible_task(q: Dictionary,novice:=false,include_history:=false) -> bool:
	if q.get("status","") in ["planned","not_implemented","missing","disabled"]:return false
	if q.has("jobs") and app.rules.character.job not in q.jobs:return false
	var current: String=app.rules.state.quests.get(q.id,"")
	if include_history and current=="done":return true
	if related_from.is_empty() and show_completed:return current=="done"
	if current=="done":return false
	return current=="accepted" or (EditionVillage.available(app.rules.state,q) if novice else Story.available(app.rules.state,q))
func row_priority(row: Dictionary) -> int:
	if not row.novice:return Story.npc_task_priority(app.rules.state,Story.quest(row.id),npc.id)
	var current: String=app.rules.state.quests.get(row.id,"")
	if current=="done":return 4
	if current=="accepted":return 0 if EditionVillage.ready(app.rules.state,row.id) else 3
	return 2 if EditionVillage.available(app.rules.state,EditionVillage.quest(row.id)) else 5
func open_successors() -> void:
	if not reading or rows.is_empty():return
	var id: String=rows[cursor].id
	if not Story.data().quests.any(func(q):return id in q.requires and actionable_successor(q)):return
	navigation_history.append({"related_from":related_from,"cursor":cursor,"reading":reading,"prerequisites":prerequisites})
	related_from=id;prerequisites=false;cursor=0;refresh(false)
func actionable_successor(q: Dictionary) -> bool:
	return q.get("status","") not in ["planned","not_implemented","missing","disabled"] and (not q.has("jobs") or app.rules.character.job in q.jobs) and app.rules.state.quests.get(q.id)!="done" and Story.available(app.rules.state,q)
func open_prerequisites() -> void:
	if not reading or rows.is_empty() or rows[cursor].novice:return
	var id: String=rows[cursor].id
	if Story.quest(id).requires.is_empty():return
	navigation_history.append({"related_from":related_from,"cursor":cursor,"reading":reading,"prerequisites":prerequisites})
	related_from=id;prerequisites=true;cursor=0;refresh(false)
func back() -> void:
	if reading:refresh();return
	if not navigation_history.is_empty():
		var previous: Dictionary=navigation_history.pop_back()
		related_from=previous.related_from;prerequisites=previous.prerequisites;cursor=previous.cursor;refresh(false)
		if previous.reading:open_detail()
	else:app.windows.close("手柄人物委托")
func status(q: Dictionary) -> String:
	if q.has("jobs") and app.rules.state.get("story_job","") not in q.jobs:return "限定职业："+"、".join(q.jobs)
	if app.rules.state.quests.get(q.id)=="done":return "已完成"
	if app.rules.state.quests.get(q.id)=="accepted":return "可交付" if Story.ready(app.rules.state,q) else "进行中"
	return "可接取" if Story.available(app.rules.state,q) else "前置未完成"
func open_detail() -> void:
	quest_states=app.rules.state.get("quests",{}).duplicate(true)
	binding_parts.clear();skill_parts.clear();repair_parts.clear();progress_parts.clear();material_parts.clear();status_part={};details_revision=-1
	if rows.is_empty():return
	reading=true;list.hide();text.show();text.scroll_to_line(0)
	var row: Dictionary=rows[cursor]
	var q: Dictionary=EditionVillage.quest(row.id) if row.novice else Story.quest(row.id)
	if row.novice:
		status_part={"value":EditionVillage.progress(app.rules.state,q),"quest":q,"novice":true}
		text.text=q.title+"\n\n"+q.description+"\n\n"+status_part.value+"\n"+app.rules.quest_reward_text(int(q.gold),int(q.xp))
		var rewards: Dictionary=app.rules.novice_reward_items(q)
		for id in rewards:text.text+="\n"+str(EditionRules.ITEMS[id].name)+" ×"+str(rewards[id])
	else:
		status_part={"value":q.title+" · "+status(q),"quest":q}
		text.text=status_part.value+"\n\n"+(q.completion if app.rules.state.quests.get(q.id)=="done" else q.dialogue)
		if app.rules.state.quests.get(q.id)=="done":text.text+="\n\n"+Story.recap(app.rules.state,q)
		var response: String=Story.npc_dialogue(app.rules.state,q,npc.id)
		if not response.is_empty():text.text="人物回应：\n"+response+"\n\n"+text.text
		for i in range(q.objectives.size()):
			var objective_line:=Story.objective_text(app.rules.state,q,i)
			progress_parts.append({"value":objective_line,"quest":q,"index":i})
			text.text+="\n"+objective_line
			if q.objectives[i].type=="binding" and Story.progress(app.rules.state,q,i)<int(q.objectives[i].count):
				var value:=Story.binding_brief(app.rules.state,q.objectives[i],EditionRules.ITEMS)
				binding_parts.append({"value":value,"objective":q.objectives[i],"quest":q,"index":i});text.text+="\n"+value
			if app.rules.state.quests.get(q.id)!="done" and q.objectives[i].type=="skill":
				var value:=Story.skill_brief(app.rules.state,q.objectives[i],app.rules.character.job)
				skill_parts.append({"value":value,"objective":q.objectives[i]})
				text.text+="\n"+value+"\n"+Story.skill_sources_text(app.rules.state,q.objectives[i],EditionRules.ITEMS,app.rules.character.job)
			if app.rules.state.quests.get(q.id)!="done" and q.objectives[i].type=="skill":
				var drop_text: String=Story.skill_drop_text(q.objectives[i],EditionRules.ITEMS,app.rules.character.job,app.resources.map_by_id)
				if not drop_text.is_empty():text.text+="\n"+drop_text
				for merchant in Story.skill_book_merchants(app.rules.state,q.objectives[i],EditionRules.ITEMS,app.rules.character.job):
					text.text+="\n售书人物："+str(merchant.name)+" · "+str(app.resources.map_by_id.get(merchant.map,{}).get("name",merchant.map))+"（价格及库存以商店为准）"
			if app.rules.state.quests.get(q.id)!="done" and q.objectives[i].type=="repair" and Story.progress(app.rules.state,q,i)<int(q.objectives[i].count):
				var value: String=app.rules.story_repair_brief(q.objectives[i].npc)
				repair_parts.append({"value":value,"quest":q,"index":i,"objective":q.objectives[i]});text.text+="\n"+value
			if q.objectives[i].type=="kill":text.text+="\n"+Story.combat_brief(q.objectives[i])
		var materials: String=app.rules.story_materials_text(q,app.elapsed)
		if not materials.is_empty():
			material_parts.append({"value":materials,"quest":q});text.text+="\n\n"+materials
		text.text+="\n\n"+app.rules.quest_reward_text(int(q.rewards.gold),int(q.rewards.xp))
		if q.has("guild_delivery"):text.text+="\n"+app.rules.story_guild_reward_text(q)
		for pair in [["接取",q.start_npc],["交付",q.end_npc]]:
			var person: Dictionary=app.rules.story_npc(pair[1])
			var location: String=app.resources.map_by_id.get(person.get("map",""),{}).get("name","")
			text.text+="\n"+str(pair[0])+"："+str(person.get("name",pair[1]))+(" · "+location if not location.is_empty() else "")
		var rewards: Dictionary=app.rules.story_reward_items(q)
		for id in rewards:text.text+="\n"+EditionRules.story_reward_label(id,int(rewards[id]))
	if app.rules.state.quests.get(row.id)=="done":text.text+="\n\n"+app.rules.quest_receipt_text(row.id)
	hint.text="B 返回列表 · 上下滚动归档 · Y 原有服务" if app.rules.state.quests.get(row.id)=="done" else "A 接取 / 交付 · B 返回列表\n上下滚动详情 · X 追踪已接故事任务 · Y 原有服务"
	if has_repair_service():hint.text=hint.text.replace("Y 原有服务","Y 修理衣物 / 装备")
	if not row.novice and q.objectives.any(func(o):return o.type=="skill" and o.has("skills_by_job")):hint.text+=" · L3 掉书来源"
	elif not row.novice and q.objectives.any(func(o):return o.type=="skill"):hint.text+=" · L3 技能指引"
	if not row.novice and not q.objectives.any(func(o):return o.type=="skill" and o.has("skills_by_job")) and q.objectives.any(func(o):return o.type in ["visit","kill"]) and app.rules.state.quests.get(row.id)!="done":hint.text+=" · L3 远行补给"
	if not row.novice and app.rules.state.quests.get(row.id)=="accepted":hint.text+=" · R3 放弃（需确认）"
	if not row.novice and not q.requires.is_empty():hint.text+=" · LB 前置委托"
	if Story.data().quests.any(func(candidate):return row.id in candidate.requires and actionable_successor(candidate)):hint.text+=" · RB 后续委托"
	if not row.novice and q.has("jobs") and app.rules.character.job not in q.jobs:hint.text="此委托不适用于当前职业 · B 返回列表 · 上下滚动 · Y 原有服务"

func has_repair_service() -> bool:
	if not reading or rows.is_empty() or rows[cursor].novice:return false
	var q: Dictionary=Story.quest(rows[cursor].id)
	return q.objectives.any(func(o):return o.type=="repair" and o.npc==npc.id)

func operate() -> void:
	if rows.is_empty() or app.world.paused or app.rules.state.hp<=0:return
	if not app.rules.story_near(npc.id,app.world.metadata.id,app.world.player.cell):app.info("请回到任务人物身边");return
	var row: Dictionary=rows[cursor]
	var ok:=false
	if row.novice:
		if npc.id!="border:elder":app.info("新手委托请返回边界村村长处办理");return
		ok=app.rules.novice_quest(row.id)
	elif npc.id not in [Story.quest(row.id).start_npc,Story.quest(row.id).end_npc]:
		app.info("此人物提供相关见闻或服务，请向交付人物办理委托");return
	else:ok=app.rules.story_action(row.id,"submit" if app.rules.state.quests.get(row.id)=="accepted" else "accept",npc.id,app.world.metadata.id,app.world.player.cell)
	app.pending_message=app.rules.message;app.info(app.rules.message)
	if ok:
		app.play_sound_id(106 if app.rules.state.quests.get(row.id)=="done" else 105)
		if not row.novice:preload("res://scripts/edition2011/ui/story_cinematic.gd").play(app,Story.quest(row.id),"submit" if app.rules.state.quests.get(row.id)=="done" else "accept")
		refresh()
func request_abandon() -> void:
	if app.windows.has_modal() or not reading or rows.is_empty() or rows[cursor].novice or app.world.paused or app.rules.state.hp<=0:return
	var id: String=rows[cursor].id
	if app.rules.state.quests.get(id)!="accepted":return
	abandon_id=id
	app.windows.confirm("放弃“"+str(Story.quest(id).title)+"”？\n任务记录进度将清除，物品、技能和财富保留。\nA 确认 · B 取消",func():finish_abandon(id))
func finish_abandon(id: String) -> void:
	abandon_id=""
	if app.world.paused:app.info("请继续游戏后办理任务");return
	app.rules.abandon_story(id);app.pending_message=app.rules.message;refresh()

func _abandon_input(event: InputEvent) -> void:
	if app!=null and not abandon_id.is_empty() and app.windows.modal.visible and app.windows.pause_reason.is_empty():
		if event is InputEventJoypadButton and event.pressed:
			get_viewport().set_input_as_handled()
			if event.button_index==JOY_BUTTON_B:app.windows.modal.hide();abandon_id=""
			elif event.button_index==JOY_BUTTON_A:
				var id:=abandon_id;app.windows.modal.hide();finish_abandon(id)
		return

func _input(event: InputEvent) -> void:
	var confirming:=not abandon_id.is_empty()
	_abandon_input(event)
	if confirming:return
	if app==null or app.mode!="game" or app.windows.has_modal() or app.windows.order.is_empty() or app.windows.order.back()!="手柄人物委托":return
	if not event is InputEventJoypadButton or not event.pressed:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_B,JOY_BUTTON_BACK:
			back()
		JOY_BUTTON_LEFT_STICK:
			if reading and not rows.is_empty() and not rows[cursor].novice:
				var quest: Dictionary=Story.quest(rows[cursor].id)
				for objective in quest.objectives:
					if objective.type=="skill" and objective.has("skills_by_job"):
						app.show_story_book_hunt(objective);return
					if objective.type=="skill":
						app.game_panel("手柄技能指引",Vector2(480,360))
						var guide=load("res://scripts/edition2011/ui/controller_skill_guide.gd").new();app.form.add_child(guide);guide.setup(app,objective);return
				if app.rules.state.quests.get(quest.id)!="done" and quest.objectives.any(func(o):return o.type in ["visit","kill"]):app.show_story_supplies()
		JOY_BUTTON_RIGHT_STICK:request_abandon()
		JOY_BUTTON_RIGHT_SHOULDER:open_successors()
		JOY_BUTTON_LEFT_SHOULDER:open_prerequisites()
		JOY_BUTTON_A:
			if reading:operate()
			else:open_detail()
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			var step:=1 if event.button_index==JOY_BUTTON_DPAD_DOWN else -1
			if reading:text.get_v_scroll_bar().value+=step*48
			elif not rows.is_empty():cursor=posmod(cursor+step,rows.size());list.select(cursor);list.ensure_current_is_visible()
		JOY_BUTTON_Y:
			if app.world.paused or app.rules.state.hp<=0:return
			if not app.rules.story_near(npc.id,app.world.metadata.id,app.world.player.cell):app.info("请回到任务人物身边");return
			if npc.id=="server:merchant:126":
				app.game_panel("手柄桃源合成",Vector2(500,430))
				var crafting=load("res://scripts/edition2011/ui/controller_crafting.gd").new();app.form.add_child(crafting);crafting.setup(app,npc);return
			if has_repair_service():
				app.game_panel("手柄修理",Vector2(480,280))
				var service=load("res://scripts/edition2011/ui/controller_repair.gd").new();app.form.add_child(service);service.setup(app,npc);return
			app.windows.close("手柄人物委托");app.interact(npc)
		JOY_BUTTON_X:
			if not reading and related_from.is_empty():show_completed=not show_completed;refresh(false)
			elif reading and not rows.is_empty() and not rows[cursor].novice:
				app.rules.track_story(rows[cursor].id);app.info(app.rules.message)

func _process(_delta: float) -> void:
	if app==null or not is_visible_in_tree():return
	if reading and int(app.elapsed)!=material_clock:
		material_clock=int(app.elapsed)
		for part in material_parts:
			var value: String=app.rules.story_materials_text(part.quest,app.elapsed)
			if value!=part.value:
				var scroll: float=text.get_v_scroll_bar().value
				text.text=text.text.replace(part.value,value);part.value=value;text.get_v_scroll_bar().value=scroll
	var revision:=int(app.rules.state.get("revision",0))
	if revision==details_revision:return
	details_revision=revision
	if not reading:
		if quest_states!=app.rules.state.get("quests",{}):refresh();return
		for i in range(rows.size()):
			var row: Dictionary=rows[i]
			var q: Dictionary=EditionVillage.quest(row.id) if row.novice else Story.quest(row.id)
			var value: String=q.title+" · "+(EditionVillage.progress(app.rules.state,q) if row.novice else status(q))
			if list.get_item_text(i)!=value:list.set_item_text(i,value)
		return
	if quest_states!=app.rules.state.get("quests",{}):
		var previous: String=rows[cursor].id if cursor<rows.size() else ""
		var scroll: float=text.get_v_scroll_bar().value
		refresh()
		if not rows.is_empty() and rows[cursor].id==previous:
			open_detail();text.get_v_scroll_bar().set_deferred("value",scroll)
		return
	if not status_part.is_empty():
		var value: String=EditionVillage.progress(app.rules.state,status_part.quest) if status_part.get("novice",false) else status_part.quest.title+" · "+status(status_part.quest)
		if value!=status_part.value:
			var scroll: float=text.get_v_scroll_bar().value
			text.text=text.text.replace(status_part.value,value);status_part.value=value;text.get_v_scroll_bar().value=scroll
	for part in material_parts:
		var value: String=app.rules.story_materials_text(part.quest,app.elapsed)
		if value!=part.value:
			var scroll: float=text.get_v_scroll_bar().value
			text.text=text.text.replace(part.value,value);part.value=value;text.get_v_scroll_bar().value=scroll
	for part in progress_parts:
		var value:=Story.objective_text(app.rules.state,part.quest,part.index)
		if value!=part.value:
			var scroll: float=text.get_v_scroll_bar().value
			text.text=text.text.replace(part.value,value);part.value=value;text.get_v_scroll_bar().value=scroll
	for part in repair_parts:
		var value: String="修理目标已完成。" if Story.progress(app.rules.state,part.quest,part.index)>=int(part.objective.count) else app.rules.story_repair_brief(part.objective.npc)
		if value!=part.value:
			var scroll: float=text.get_v_scroll_bar().value
			text.text=text.text.replace(part.value,value);part.value=value;text.get_v_scroll_bar().value=scroll
	for part in skill_parts:
		var value:=Story.skill_brief(app.rules.state,part.objective,app.rules.character.job)
		if value!=part.value:
			var scroll: float=text.get_v_scroll_bar().value
			text.text=text.text.replace(part.value,value);part.value=value;text.get_v_scroll_bar().value=scroll
	for part in binding_parts:
		var value: String="捆扎已完成" if Story.progress(app.rules.state,part.quest,part.index)>=int(part.objective.count) else Story.binding_brief(app.rules.state,part.objective,EditionRules.ITEMS)
		if value!=part.value:
			var scroll: float=text.get_v_scroll_bar().value
			text.text=text.text.replace(part.value,value);part.value=value;text.get_v_scroll_bar().value=scroll
