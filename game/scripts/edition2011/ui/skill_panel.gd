extends "res://scripts/edition2011/ui/journal_layout.gd"
var app
var selected: String=""
var filter:=0
func setup(host) -> void:
	app=host;build()
	for i in range(3):action(toolbar,["本职业","已学习","未学习"][i],func():filter=i;refresh())
	line(self,"Q 施放 · R 切换 · 手柄 Y 施放 / LB、RB 切换")
	action(self,"技能书商店",app.gameplay.show_books)
	action(self,"客户端技能说明（含尚未实现条目）",app.show_skill_catalog)
	refresh()
func refresh() -> void:
	clear(entries);clear(details)
	var ids: Array=[]
	for id in EditionSkills.DEFINITIONS:
		if EditionSkills.DEFINITIONS[id].job!=app.rules.character.job:continue
		var learned: bool=app.rules.state.skills.has(id)
		if filter==1 and not learned or filter==2 and learned:continue
		ids.append(id)
	ids.sort_custom(func(a,b):return EditionSkills.DEFINITIONS[a].level<EditionSkills.DEFINITIONS[b].level)
	if selected not in ids:selected=str(ids[0]) if not ids.is_empty() else ""
	for id in ids:
		var skill: Dictionary=EditionSkills.DEFINITIONS[id]
		var button:=action(entries,("◆ " if selected==id else "")+skill.name+" · "+str(skill.level)+"级",func():selected=id;app.play_sound_id(105);refresh())
		button.tooltip_text="已学习" if app.rules.state.skills.has(id) else "需要对应技能书"
	if selected.is_empty():line(details,"此分类暂无技能");return
	var skill: Dictionary=EditionSkills.DEFINITIONS[selected]
	line(details,skill.name,true)
	line(details,"职业："+str(app.rules.character.job))
	line(details,"学习等级 %d　当前等级 %d\n魔法 %d　冷却 %.1f 秒"%[skill.level,app.rules.state.level,skill.mp,skill.cooldown])
	var owned:=0
	for type in app.rules.state.inventory:
		if EditionRules.ITEMS.get(type,{}).get("skill_book","")==selected:owned+=int(app.rules.state.inventory[type])
	var learned: bool=app.rules.state.skills.has(selected)
	line(details,"已学会 · 被动生效" if learned and skill.get("passive",false) else "已学会" if learned else "未学习 · 只能使用对应技能书")
	if selected=="spirit":line(details,"普通近战准确 +2 / 技能等级（单机暂定数值）；不增加法术伤害。当前准确：%d"%app.rules.melee_accuracy())
	line(details,"背包《%s》技能书 ×%d"%[skill.name,owned])
	if not learned:action(details,"使用《"+skill.name+"》技能书",func():app.gameplay.learn(selected);refresh(),owned>0 and app.rules.state.level>=skill.level)
	elif not skill.get("passive",false):action(details,"设为当前技能",func():app.gameplay.select_skill(selected);refresh())
	if app.gameplay.current_skill()==selected:line(details,"当前施放技能 · Q / 手柄 Y")
	if not learned and owned==0:line(details,"先获得技能书，再在此使用；也可从背包直接使用。")
