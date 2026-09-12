extends RefCounted
const NPC="server:merchant:104"
# Dialogue topology follows 9Equ-0148. Company-directed wording is adapted
# to the local world; the random-5 branch is reconstructed as one in five.
const NODES={
 "first":{"text":"如果我不给你朋友托付的礼物，你会怎样？","options":[["没有任何感觉","calm"],["给不给都没有关系","generous"],["会很不开心","angry"]]},
 "world":{"text":"那你对我们生活的这个世界有什么感觉？","options":[["没有特别的感觉","indifferent"],["有很多不满","unhappy"],["很喜欢这里","happy"]]},
 "friend":{"text":"最后一个问题：你觉得托你准备宴席的那位朋友怎样？","options":[["是个有趣的人","funny"],["有些让人讨厌","dislike"]]}}
static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("bonus") is bool or not value.get("answers") is Array or not value.get("rewards") is Dictionary:return false
	if value.answers.is_empty() or value.answers.size()>3:return false
	var stage:="first"
	var expected: Dictionary={}
	for answer in value.answers:
		if not answer is String or not NODES.has(stage) or not NODES[stage].options.any(func(o):return o[1]==answer):return false
		stage="world" if answer=="generous" else "friend" if answer=="unhappy" else "done"
		if stage=="done":
			if answer in ["calm","happy","funny"]:expected={"ref:159":1}
			elif answer=="dislike":
				expected={"ref:193":1}
				if value.bonus:expected["ref:159"]=1
	if value.get("stage","")!=stage or value.rewards.size()!=expected.size():return false
	for item in expected:
		var count=value.rewards.get(item,null)
		if not (count is int or count is float) or count!=1:return false
	return true
static func choose(rules,answer: String,map_id: String,cell: Vector2i) -> bool:
	if rules.state.hp<=0 or not rules.story_near(NPC,map_id,cell):rules.message="请到客栈林小姐身边交谈";return false
	if rules.state.quests.get("story_feast_delivery","")!="done":rules.message="请先完成宴席送达";return false
	var current: Dictionary=rules.state.get("feast_gift",{})
	var stage: String=current.get("stage","first")
	if stage=="done":rules.message="这份谢礼已经结算，请去寻找刘老头";return false
	if not NODES.has(stage) or not NODES[stage].options.any(func(o):return o[1]==answer):rules.message="此回答不属于当前问题";return false
	var next: Dictionary=rules.state.duplicate(true)
	var gift: Dictionary=current.duplicate(true) if not current.is_empty() else {"stage":"first","bonus":randi_range(0,4)==0,"answers":[],"rewards":{}}
	gift.answers.append(answer)
	gift.stage="world" if answer=="generous" else "friend" if answer=="unhappy" else "done"
	if gift.stage=="done":
		if answer in ["calm","happy","funny"]:gift.rewards={"ref:159":1}
		elif answer=="dislike":
			gift.rewards={"ref:193":1}
			if gift.bonus:gift.rewards["ref:159"]=1
		for item in gift.rewards:rules.count_item(next,item,int(gift.rewards[item]))
	next.feast_gift=gift
	rules.message="回答已记录" if gift.stage!="done" else "谢礼已结算："+("这次没有物品" if gift.rewards.is_empty() else "、".join(gift.rewards.keys().map(func(id):return str(rules.ITEMS[id].name)+" ×1")))+"。接下来寻找刘老头。"
	return rules.apply(next,"feast_gift_answer")
static func panel(app) -> void:
	app.game_panel("林小姐 · 宴席谢礼")
	app.panel.enable_button_navigation()
	if app.rules.state.quests.get("story_feast_delivery","")!="done":app.label("先替朋友办妥宴席，再来谈谢礼吧。");return
	var stage: String=app.rules.state.get("feast_gift",{}).get("stage","first")
	if stage=="done":app.label("你的回答与谢礼已经记录，不能重复领取。下一段线索是刘老头。");return
	app.label(NODES[stage].text)
	for option in NODES[stage].options:
		var answer: String=option[1]
		app.button(option[0],func():
			if not app.gameplay.available():return
			var ok:=choose(app.rules,answer,app.world.metadata.id,app.world.player.cell)
			var message: String=app.rules.message
			if ok:panel(app)
			app.info(message))
