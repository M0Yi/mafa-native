extends "res://scripts/edition2011/ui/journal_layout.gd"
const Story=preload("res://scripts/edition2011/story.gd")
var app
var binding_lines: Array=[]
var skill_lines: Array=[]
var repair_lines: Array=[]
var progress_lines: Array=[]
var material_clock: int=-1
var material_lines: Array=[]
var status_lines: Array=[]
var submit_control: Button
var submit_quest: Dictionary={}
var details_revision: int=-1
var quest_states: Dictionary={}
var visible_quest_ids: Array=[]
var npc: Dictionary={}
var selected:=""
var displayed:=""
var active_only:=false
var available_only:=false
var chapter_id:=""
var status_filter:=""
var status_picker:=OptionButton.new()
var chapter_picker:=OptionButton.new()
var search:=LineEdit.new()
var summary:=Label.new()
var search_index: Dictionary={}
func setup(host,person: Dictionary={}) -> void:
	app=host;npc=person;build()
	action(toolbar,"当前委托",func():active_only=true;available_only=false;status_filter="";status_picker.select(0);refresh())
	action(toolbar,"任务列表",func():reset_filters())
	action(toolbar,"可接取",func():active_only=false;available_only=true;status_filter="";status_picker.select(0);refresh())
	chapter_picker.add_item("全部地区");chapter_picker.set_item_metadata(0,"")
	for chapter in Story.data().chapters:
		chapter_picker.add_item(chapter.title);chapter_picker.set_item_metadata(chapter_picker.item_count-1,chapter.id)
	chapter_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;toolbar.add_child(chapter_picker)
	chapter_picker.item_selected.connect(func(index):chapter_id=str(chapter_picker.get_item_metadata(index));refresh())
	search.placeholder_text="查找任务、人物、地图或怪物";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var filters:=HBoxContainer.new();add_child(filters);move_child(filters,1)
	filters.add_child(search)
	for value in ["可进行","进行中","待交付","已完成"]:status_picker.add_item(value)
	status_picker.tooltip_text="按任务状态筛选；可与地区和名称组合"
	filters.add_child(status_picker)
	status_picker.item_selected.connect(select_status)
	search.text_changed.connect(func(_value):refresh())
	summary.add_theme_font_size_override("font_size",13);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(summary);move_child(summary,2)
	refresh()
func select_status(index: int) -> void:
	status_filter="" if index==0 else status_picker.get_item_text(index)
	active_only=false;available_only=false;refresh()
func reset_filters() -> void:
	active_only=false;available_only=false;status_filter="";status_picker.select(0);chapter_id="";chapter_picker.select(0);search.text="";refresh()
func show_prerequisite(id: String) -> void:
	if Story.quest(id).is_empty():app.show_quest_entry(id);return
	var target: Dictionary=Story.quest(id)
	if npc.get("id","") not in [target.start_npc,target.end_npc]:npc={}
	selected=id;reset_filters()
	if app.rules.state.quests.get(id)=="done":select_status(3)
func status(q: Dictionary) -> String:
	if q.has("jobs") and app.rules.state.get("story_job","") not in q.jobs:return "限定职业："+"、".join(q.jobs)
	if app.rules.state.quests.get(q.id)=="done":return "已完成"
	if Story.ready(app.rules.state,q):return "待交付"
	if app.rules.state.quests.get(q.id)=="accepted":return "进行中"
	return "可接取" if Story.available(app.rules.state,q) else "前置未完成"
func search_text(q: Dictionary) -> String:
	if search_index.has(q.id):return search_index[q.id]
	var terms: PackedStringArray=[q.title,q.kind]
	var people: Array=[q.start_npc,q.end_npc]
	var maps: Array=[]
	for objective in q.objectives:
		if objective.type in ["talk","repair","warehouse","purchase","binding","craft"]:people.append(objective.npc)
		if objective.type=="visit":maps.append(objective.map)
		if objective.type=="kill":maps.append_array(objective.maps);terms.append_array(objective.names)
	for id in people:
		var person: Dictionary=app.rules.story_npc(id)
		terms.append(str(person.get("name","")))
		if person.has("map"):maps.append(person.map)
	for id in maps:terms.append(str(app.resources.map_by_id.get(id,{}).get("name","")))
	search_index[q.id]=" ".join(terms)
	return search_index[q.id]
func journal_priority(q: Dictionary) -> int:
	if q.has("jobs") and app.rules.character.job not in q.jobs:return 6
	var current: String=app.rules.state.quests.get(q.id,"")
	if current=="done":return 5
	if current=="accepted":
		if Story.ready(app.rules.state,q):return 0
		return 1 if app.rules.state.get("tracked_story","")==q.id else 2
	return 3 if Story.available(app.rules.state,q) else 4

func filtered_choices() -> Array:
	var choices: Array=[]
	for q in Story.data().quests:
		if q.has("jobs") and app.rules.character.job not in q.jobs:continue
		if q.get("status","") in ["planned","not_implemented","missing","disabled"]:continue
		var current: String=app.rules.state.quests.get(q.id,"")
		if current.is_empty() and not Story.available(app.rules.state,q):continue
		if current=="done" and status_filter!="已完成":continue
		if not npc.is_empty() and not Story.involves_npc(app.rules.state,q,npc.id):continue
		if active_only and app.rules.state.quests.get(q.id)!="accepted":continue
		if available_only and (app.rules.state.quests.has(q.id) or not Story.available(app.rules.state,q)):continue
		if not status_filter.is_empty() and status(q)!=status_filter:continue
		if not chapter_id.is_empty() and q.chapter!=chapter_id:continue
		if not search.text.strip_edges().is_empty() and not search_text(q).contains(search.text.strip_edges()):continue
		choices.append(q)
	if not npc.is_empty():
		choices.sort_custom(func(a,b):
			var pa: int=Story.npc_task_priority(app.rules.state,a,npc.id);var pb: int=Story.npc_task_priority(app.rules.state,b,npc.id)
			return pa<pb if pa!=pb else Story.data().quests.find(a)<Story.data().quests.find(b))
	else:
		var priorities: Dictionary={}
		var positions: Dictionary={}
		for i in range(choices.size()):priorities[choices[i].id]=journal_priority(choices[i]);positions[choices[i].id]=i
		choices.sort_custom(func(a,b):return priorities[a.id]<priorities[b.id] if priorities[a.id]!=priorities[b.id] else positions[a.id]<positions[b.id])
	return choices

func update_summary(shown: int) -> void:
	summary.text="没有符合筛选的委托" if shown==0 else "%d 项已完成"%shown if status_filter=="已完成" else "%d 项委托"%shown
	summary.tooltip_text=""

func refresh() -> void:
	quest_states=app.rules.state.get("quests",{}).duplicate(true)
	binding_lines.clear();skill_lines.clear();repair_lines.clear();progress_lines.clear();material_lines.clear();status_lines.clear();submit_control=null;submit_quest={};details_revision=-1
	clear(entries);clear(details)
	var choices:=filtered_choices()
	visible_quest_ids=choices.map(func(q):return q.id)
	update_summary(choices.size())
	if choices.is_empty():
		line(details,"没有符合筛选的已完成委托。" if status_filter=="已完成" else "这里暂时没有可办理的委托。\n完成当前任务后，再来看看。",true)
		if status_filter!="已完成" and not EditionVillage.current(app.rules.state).is_empty():
			action(details,"继续村庄委托",func():app.approach_story_npc("border:elder"))
		return
	if not choices.any(func(q):return q.id==selected):selected=choices[0].id
	var changed: bool=displayed!=selected;displayed=selected
	if changed:details.get_parent().set_deferred("scroll_vertical",0)
	for q in choices:
		var row_button: Button=action(entries,("◆ " if selected==q.id else "")+q.title,func():selected=q.id;app.play_sound_id(105);refresh())
		if changed and selected==q.id:call_deferred("reveal_entry",row_button)
		status_lines.append({"label":line(entries,status(q)),"quest":q})
	var q: Dictionary=Story.quest(selected)
	line(details,q.title+" · "+q.kind,true);status_lines.append({"label":line(details,status(q)),"quest":q})
	var accepted: bool=app.rules.state.quests.get(q.id)=="accepted"
	var done: bool=app.rules.state.quests.get(q.id)=="done"
	if accepted:
		var tracking: bool=app.rules.state.get("tracked_story","")==q.id
		action(details,"取消追踪" if tracking else "追踪此任务",func():
			app.rules.track_story("" if tracking else q.id);app.info(app.rules.message);refresh())
		var quest_id: String=q.id
		action(details,"放弃此任务",func():
			if app.world.paused:app.info("请继续游戏后办理任务");return
			app.windows.confirm("放弃“"+str(q.title)+"”？\n本任务到访、交谈、击杀等进度将清除；物品、技能和财富保留。\n以后需回原任务人物处重新接取。",func():
				app.rules.abandon_story(quest_id);app.pending_message=app.rules.message
				if is_instance_valid(self):refresh()))
	if done:line(details,app.rules.quest_receipt_text(q.id),true)
	var materials: String=app.rules.story_materials_text(q,app.elapsed)
	if not materials.is_empty():material_lines.append({"label":line(details,materials,true),"quest":q})
	var target: String=q.end_npc if accepted or done else q.start_npc
	if not npc.is_empty() and npc.id==target:
		submit_quest=q
		submit_control=action(details,"已完成" if done else "交付委托" if accepted else "接受委托",func():
			if app.world.paused:app.info("暂停时不能办理任务");return
			var operation: String="submit" if app.rules.state.quests.get(q.id)=="accepted" else "accept"
			var ok: bool=app.rules.story_action(q.id,operation,npc.id,app.world.metadata.id,app.world.player.cell)
			app.pending_message=app.rules.message;app.info(app.rules.message)
			if ok:
				app.play_sound_id(106 if operation=="submit" else 105)
				preload("res://scripts/edition2011/ui/story_cinematic.gd").play(app,q,operation)
			refresh(),not done and Story.available(app.rules.state,q) and (not accepted or Story.ready(app.rules.state,q)))
	else:action(details,"寻找任务人物",func():app.approach_story_npc(target))
	if not npc.is_empty():
		var response: String=Story.npc_dialogue(app.rules.state,q,npc.id)
		if not response.is_empty():line(details,"人物回应：\n"+response,true)
	line(details,("归档结论\n"+str(q.completion)) if done else q.dialogue)
	if done:line(details,Story.recap(app.rules.state,q))
	if q.objectives.is_empty():line(details,"将口信带给交付人物。")
	if not done and app.rules.state.guild.is_empty() and q.objectives.any(func(o):return o.type=="relationship" and o.get("field","")=="guild"):
		line(details,"可在玛法旅人面板快捷成立行会；若要自定名称，请到比奇宫殿国王处办理本地登记。")
		action(details,"前往国王命名登记",app.show_story_guild_registration)
	if not done and q.objectives.any(func(o):return o.type in ["visit","kill"]):
		action(details,"出发前查看补给",app.show_story_supplies)
	for index in range(q.objectives.size()):
		var objective: Dictionary=q.objectives[index]
		progress_lines.append({"label":line(details,Story.objective_text(app.rules.state,q,index)),"quest":q,"index":index})
		if objective.type=="binding" and Story.progress(app.rules.state,q,index)<int(objective.count):
			binding_lines.append({"label":line(details,Story.binding_brief(app.rules.state,objective,EditionRules.ITEMS)),"objective":objective,"quest":q,"index":index})
		if accepted and objective.type=="relationship":action(details,"打开玛法旅人",func():app.approach_story_objective(objective))
		if not done and objective.type=="skill":
			skill_lines.append({"label":line(details,Story.skill_brief(app.rules.state,objective,app.rules.character.job)),"objective":objective})
			var target_skill: String=objective.get("skills_by_job",{}).get(app.rules.character.job,"")
			if not objective.has("skills_by_job"):target_skill=Story.skill_suggestion(app.rules.state,app.rules.character.job).get("skill","")
			if EditionSkills.DEFINITIONS.has(target_skill):
				action(details,"打开技能："+str(EditionSkills.DEFINITIONS[target_skill].name) if objective.has("skills_by_job") else "打开当前推荐技能",func():app.show_story_skill(objective))
			for source in Story.skill_book_sources(app.rules.state,objective,EditionRules.ITEMS,app.rules.character.job):
				line(details,source.name+" · "+source.status)
				action(details,"查看领书委托："+str(source.title),func():show_prerequisite(source.quest))
			var drop_text: String=Story.skill_drop_text(objective,EditionRules.ITEMS,app.rules.character.job,app.resources.map_by_id)
			if not drop_text.is_empty():
				line(details,drop_text)
				action(details,"寻找掉书怪物",func():app.show_story_book_hunt(objective))
			var merchants: Array=Story.skill_book_merchants(app.rules.state,objective,EditionRules.ITEMS,app.rules.character.job)
			if not merchants.is_empty():line(details,"也可向以下商人购买，价格和库存以商店窗口为准。")
			for merchant in merchants:
				var names: PackedStringArray=[]
				for book in merchant.books:names.append(book.name)
				line(details,"、".join(names))
				action(details,"寻找书商："+str(merchant.name)+" · "+str(app.resources.map_by_id.get(merchant.map,{}).get("name",merchant.map)),func():app.approach_story_npc(merchant.npc))
		if not done and objective.type=="repair" and Story.progress(app.rules.state,q,index)<int(objective.count):repair_lines.append({"label":line(details,app.rules.story_repair_brief(objective.npc)),"quest":q,"index":index,"objective":objective})
		if objective.type=="kill":
			line(details,Story.combat_brief(objective))
			var map_names: Array=[]
			for id in objective.maps:map_names.append(str(app.resources.map_by_id[id].name))
			line(details,"区域："+"、".join(map_names))
		if accepted and objective.type=="warehouse" and npc.get("id","")==objective.npc and index==q.objectives.find(Story.next_objective(app.rules.state,q)):
			action(details,"打开仓库",func():
				var keeper: Dictionary=app.rules.story_npc(objective.npc)
				if not app.near_reference_npc(keeper):app.info("请回到保管员身边，并继续游戏后办理");return
				app.show_warehouse())
		if accepted and objective.type in ["purchase","binding","craft"] and npc.get("id","")==objective.npc and index==q.objectives.find(Story.next_objective(app.rules.state,q)):
			action(details,"打开捆扎服务" if objective.type=="binding" else "打开合成服务" if objective.type=="craft" else "打开商店",func():
				var merchant: Dictionary=app.rules.story_npc(objective.npc)
				if not app.near_reference_npc(merchant):app.info("请回到商人身边，并继续游戏后办理");return
				if objective.type=="craft" and merchant.id=="server:merchant:109":preload("res://scripts/edition2011/mystery_books.gd").materials_panel(app)
				else:app.show_reference_npc(merchant))
		if accepted and objective.type=="repair" and npc.get("id","")==objective.npc and Story.progress(app.rules.state,q,index)<int(objective.count):
			action(details,"打开修理服务",func():
				var smith: Dictionary=app.rules.story_npc(objective.npc)
				if not app.near_reference_npc(smith):app.info("请回到铁匠身边，并继续游戏后办理");return
				app.show_reference_npc(smith))
		if accepted and objective.type!="relationship" and Story.navigable(objective) and Story.progress(app.rules.state,q,index)<int(objective.count):
			action(details,"寻找材料 / 地面物品" if objective.type=="collect" else "前往此目标",func():app.approach_story_objective(objective))
	for pair in [["接取",q.start_npc],["交付",q.end_npc]]:
		var person: Dictionary=app.rules.story_npc(pair[1])
		if not person.is_empty():line(details,pair[0]+"："+person.name+" · "+str(app.resources.map_by_id[person.map].name))
	var rewards: Array=[]
	var reward_items: Dictionary=app.rules.story_reward_items(q)
	for id in reward_items:rewards.append(EditionRules.story_reward_label(id,int(reward_items[id])))
	if q.rewards.has("equipment_by_job"):line(details,"本职业装备兑换 · 交付时消耗列出的材料，仍需满足装备要求。")
	if q.rewards.has("books_by_job"):line(details,"本职业技能书奖励 · 领取后需从背包使用，遵守学习等级。")
	line(details,app.rules.quest_reward_text(int(q.rewards.gold),int(q.rewards.xp))+"\n"+"、".join(rewards))
	if q.has("guild_delivery"):line(details,app.rules.story_guild_reward_text(q))
	var successors: Array=Story.data().quests.filter(func(candidate):return q.id in candidate.requires and Story.available(app.rules.state,candidate) and app.rules.state.quests.get(candidate.id)!="done" and (not candidate.has("jobs") or app.rules.character.job in candidate.jobs))
	if not successors.is_empty():
		line(details,"后续委托",true)
		for successor in successors:
			action(details,"后续："+str(successor.title)+" · "+status(successor),func():show_prerequisite(successor.id))
	if not Story.available(app.rules.state,q):
		for id in q.requires:
			var previous: Dictionary=Story.quest(id)
			if previous.is_empty():previous=EditionVillage.quest(id)
			var complete: bool=app.rules.state.quests.get(id)=="done"
			action(details,("已完成：" if complete else "查看前置：")+str(previous.get("title",id)),func():show_prerequisite(id),not complete)

func _process(_delta: float) -> void:
	if app==null or not is_visible_in_tree():return
	if int(app.elapsed)!=material_clock:
		material_clock=int(app.elapsed)
		for row in material_lines:
			if is_instance_valid(row.label):row.label.text=app.rules.story_materials_text(row.quest,app.elapsed)
	var revision:=int(app.rules.state.get("revision",0))
	if revision==details_revision:return
	details_revision=revision
	update_summary(visible_quest_ids.size())
	if quest_states!=app.rules.state.get("quests",{}) or filtered_choices().map(func(q):return q.id)!=visible_quest_ids:
		var previous:=selected
		var scroll: int=details.get_parent().scroll_vertical
		refresh()
		if selected==previous:details.get_parent().set_deferred("scroll_vertical",scroll)
		return
	for row in status_lines:
		if is_instance_valid(row.label):row.label.text=status(row.quest)
	if is_instance_valid(submit_control):
		var state_name: String=app.rules.state.quests.get(submit_quest.id,"")
		submit_control.disabled=state_name=="done" or not Story.available(app.rules.state,submit_quest) or (state_name=="accepted" and not Story.ready(app.rules.state,submit_quest))
	for row in material_lines:
		if is_instance_valid(row.label):row.label.text=app.rules.story_materials_text(row.quest,app.elapsed)
	for row in progress_lines:
		if not is_instance_valid(row.label):continue
		var value:=Story.objective_text(app.rules.state,row.quest,row.index)
		if row.label.text!=value:row.label.text=value
	for row in repair_lines:
		if not is_instance_valid(row.label):continue
		var value: String="修理目标已完成。" if Story.progress(app.rules.state,row.quest,row.index)>=int(row.objective.count) else app.rules.story_repair_brief(row.objective.npc)
		if row.label.text!=value:row.label.text=value
	for row in skill_lines:
		if not is_instance_valid(row.label):continue
		var value:=Story.skill_brief(app.rules.state,row.objective,app.rules.character.job)
		if row.label.text!=value:row.label.text=value
	for row in binding_lines:
		if not is_instance_valid(row.label):continue
		row.label.visible=Story.progress(app.rules.state,row.quest,row.index)<int(row.objective.count)
		if row.label.visible:
			var value:=Story.binding_brief(app.rules.state,row.objective,EditionRules.ITEMS)
			if row.label.text!=value:row.label.text=value

func reveal_entry(row: Control) -> void:
	if not is_instance_valid(row) or row.is_queued_for_deletion():return
	var scroll=entries.get_parent()
	if scroll is ScrollContainer and scroll.is_ancestor_of(row):scroll.ensure_control_visible(row)
