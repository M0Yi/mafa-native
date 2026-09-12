extends "res://scripts/edition2011/ui/journal_layout.gd"
var app
var npc: Dictionary={}
var selected: String=""
var tab:=0
var show_completed:=false
var history_button: Button
var progress_rows: Array=[]
var submit_control: Button
var details_revision: int=-1
var quest_states: Dictionary={}
const JOURNEY=[
	["学会活下来","建议 1–7 级 · 银杏 / 边界村","从村内补给开始，准备药品与装备，再到村外熟悉鸡、鹿和稻草人。两个村庄是可选起点，不必依次经过。"],
	["离开村口","建议 7–15 级 · 比奇森林 / 天然洞穴","逐渐远离补给点，留意猫怪、半兽人、雪人与骷髅。出发前修理装备，保留回程补给。"],
	["接触地下世界","建议 15–22 级 · 古墓 / 矿区","地下路线更复杂，观察骷髅与僵尸的围攻。矿石、装备耐久和药品负重都影响一次探索能走多远。"],
	["学会远行","建议 20–28 级 · 蛇谷 / 盟重","把城镇当作补给站，再前往蜈蚣洞与石墓。先辨认出口，衡量随身药品和负重。"],
	["有组织的敌境","建议 25–35 级 · 沃玛 / 祖玛","不同敌群需要不同站位；留意近身、远程和特殊敌人的组合。不要把每座神殿都当成同一种敌境。"],
	["成熟冒险者","建议 30–40+ 级 · 封魔 / 白日门 / 赤月","更长的旅途要求充足补给与协作。观察环境中的威胁，逐步接近更深的区域。"],
	["大陆秩序","建议具备协作能力 · 行会 / 沙巴克","从个人生存走向集体行动。此处介绍世界观中的方向，具体活动以当前版本已开放的功能为准。"]
]
func setup(host,entity: Dictionary={}) -> void:
	app=host;npc=entity;build()
	selected=str(EditionVillage.current(app.rules.state).get("id","nv_arrival"))
	if npc.is_empty():
		for i in range(3):action(toolbar,["村庄委托","旅途指引","区域委托"][i],func():tab=i;refresh())
		action(toolbar,"故事线",func():app.show_story())
	else:
		line(toolbar,"村庄委托",true)
		history_button=action(toolbar,"查看已完成",func():show_completed=not show_completed;refresh())
		var services:=HBoxContainer.new();add_child(services)
		action(services,"故事",func():app.show_story(npc))
		action(services,"恢复",func():
			if near_npc():app.rules.recover_at_village();app.info(app.rules.message))
		action(services,"装备",func():app.show_bag();app.show_character())
		action(services,"仓库",func():
			if near_npc():app.show_warehouse())
		action(services,"村庄地图",app.show_village_map)
		action(services,"其他区域",app.show_travel)
	refresh()
func near_npc() -> bool:
	if app.world.paused:
		app.info("请继续游戏后办理村庄事务");return false
	if not app.rules.story_near("border:elder",app.world.metadata.id,app.world.player.cell):
		app.info("请在存活时回到边界村长身边办理");return false
	return true
func refresh() -> void:
	details_revision=int(app.rules.state.get("revision",0));quest_states=app.rules.state.quests.duplicate(true)
	progress_rows.clear();submit_control=null
	clear(entries);clear(details)
	if is_instance_valid(history_button):history_button.text="返回当前委托" if show_completed else "查看已完成"
	if tab==1:
		for i in range(JOURNEY.size()):action(entries,JOURNEY[i][0],func():show_journey(i))
		show_journey(0);return
	if tab==2:
		line(details,"区域委托",true);line(details,"已勘察 %d / 707 个区域"%app.rules.state.visited.size())
		line(details,"与当地向导交谈，接受和交付当地委托。")
		for key in app.rules.state.quests:
			if str(key).begins_with("nv_") or str(key).begins_with("story_"):continue
			var name: String=app.resources.map_by_id.get(str(key).trim_prefix("ore:"),{}).get("name","其他区域")
			line(details,name+" · "+("已完成" if app.rules.state.quests[key]=="done" else "进行中"))
		return
	var choices: Array=EditionVillage.quests().filter(func(q):return app.rules.state.quests.get(q.id)=="done" if show_completed else app.rules.state.quests.get(q.id)=="accepted" or (app.rules.state.quests.get(q.id)!="done" and EditionVillage.available(app.rules.state,q)))
	if not choices.any(func(q):return q.id==selected):selected=str(choices[0].id) if not choices.is_empty() else ""
	if choices.is_empty():
		line(details,"还没有完成的村庄委托。" if show_completed else "村庄委托已办妥，可以继续探索各地的故事。",true)
		return
	for q in choices:
		action(entries,("◆ " if selected==q.id else "")+q.title,func():selected=q.id;app.play_sound_id(105);refresh())
		progress_rows.append({"label":line(entries,EditionVillage.progress(app.rules.state,q)),"quest":q})
	var q:=EditionVillage.quest(selected)
	if q.is_empty():return
	line(details,q.title,true)
	if not npc.is_empty():line(details,"“出门前先备好行装和药品。认得回村的路，才能走得更远。”")
	progress_rows.append({"label":line(details,EditionVillage.progress(app.rules.state,q)),"quest":q})
	if npc.is_empty():action(details,"前往此任务目标",func():app.navigate_village_objective(selected))
	else:
		var accepted: bool=app.rules.state.quests.get(q.id)=="accepted"
		var done: bool=app.rules.state.quests.get(q.id)=="done"
		submit_control=action(details,"已完成" if done else "交付任务" if accepted else "接受任务",func():
			if not near_npc():return
			var ok: bool=app.rules.novice_quest(selected);app.pending_message=app.rules.message
			if ok and app.rules.state.quests.get(selected)=="done" and int(q.gold)>0:app.play_sound_id(106)
			app.info(app.rules.message);refresh(),not done and EditionVillage.available(app.rules.state,q) and (not accepted or EditionVillage.ready(app.rules.state,q.id)))
	if app.rules.state.quests.get(q.id)=="done":line(details,app.rules.quest_receipt_text(q.id),true)
	line(details,q.description)
	line(details,"目标："+q.objective)
	var rewards: Array=[]
	var reward_items: Dictionary=app.rules.novice_reward_items(q)
	for type in reward_items:rewards.append(EditionRules.ITEMS[type].name+" ×"+str(int(reward_items[type])))
	line(details,"奖励："+("、".join(rewards) if not rewards.is_empty() else "无物品")+"\n"+app.rules.quest_reward_text(int(q.gold),int(q.xp)))
	line(details,"接取 / 交付：边界村长")

	for next in EditionRules.Story.data().quests:
		if q.id not in next.requires or not EditionRules.Story.available(app.rules.state,next):continue
		if app.rules.state.quests.get(next.id)=="done" or next.get("status","") in ["planned","not_implemented","missing","disabled"]:continue
		if next.has("jobs") and app.rules.character.job not in next.jobs:continue
		var state_name: String=app.rules.state.quests.get(next.id,"")
		var status: String="已完成" if state_name=="done" else "进行中" if state_name=="accepted" else "可接取" if EditionRules.Story.available(app.rules.state,next) else "前置未完成"
		action(details,"后续："+str(next.title)+" · "+status,func():app.show_quest_entry(next.id))
func show_journey(index: int) -> void:
	clear(details);var row: Array=JOURNEY[index]
	line(details,row[0],true);line(details,row[1]);line(details,row[2])
	line(details,"可按自己的节奏自由探索；建议等级不限制地图通行。")

func _process(_delta: float) -> void:
	if app==null or not is_visible_in_tree() or tab!=0:return
	var revision:=int(app.rules.state.get("revision",0))
	if revision==details_revision:return
	details_revision=revision
	if quest_states!=app.rules.state.quests:
		var scroll: int=details.get_parent().scroll_vertical
		refresh();details.get_parent().set_deferred("scroll_vertical",scroll)
		return
	for row in progress_rows:
		if is_instance_valid(row.label):row.label.text=EditionVillage.progress(app.rules.state,row.quest)
	if is_instance_valid(submit_control):
		var q:=EditionVillage.quest(selected)
		var current: String=app.rules.state.quests.get(selected,"")
		submit_control.disabled=current=="done" or not EditionVillage.available(app.rules.state,q) or (current=="accepted" and not EditionVillage.ready(app.rules.state,selected))
