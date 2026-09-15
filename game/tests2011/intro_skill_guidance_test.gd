extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var objective: Dictionary=EditionRules.Story.quest("story_book").objectives[0]
	for job in ["战士","法师","道士"]:
		var starter: String={"战士":"basic","法师":"fireball","道士":"heal"}[job]
		var book: String={"战士":"ref:16","法师":"ref:14","道士":"ref:15"}[job]
		var state:={"story_job":job,"level":1,"skills":{},"inventory":{},"warehouse":{},"quests":{}}
		var text:=EditionRules.Story.skill_brief(state,objective)
		expect("任意一种本职业技能" in text and EditionSkills.DEFINITIONS[starter].name in text,"generic task suggests correct starter without restricting objective")
		expect("还需提升 6 级" in text and "尚无对应技能书" in text,"missing book and level gap explicit")
		expect(not "客栈后面的日常" in text,"locked errand not suggested")
		state.quests.story_letter="done";text=EditionRules.Story.skill_brief(state,objective)
		expect("客栈后面的日常（可接取）" in text and not "药铺里的旧配方" in text,"only available city errands suggested")
		state.quests.story_bichon_inn="done";state.quests.story_bichon_apothecary="accepted";text=EditionRules.Story.skill_brief(state,objective)
		expect(not "客栈后面的日常" in text and "药铺里的旧配方（进行中）" in text,"completed errand removed and accepted followup shown")
		state.warehouse[book]=1;text=EditionRules.Story.skill_brief(state,objective)
		expect("先取回背包" in text,"stored starter book guidance")
		state.warehouse.clear();state.inventory[book]=1;text=EditionRules.Story.skill_brief(state,objective)
		expect("技能书已在背包" in text and "未达等级使用不会消耗" in text,"owned book still needs level and explicit use")
		state.level=7;text=EditionRules.Story.skill_brief(state,objective)
		expect(not "还需提升" in text and not "城内见闻" in text,"level met removes obsolete level gap and leveling errands")
		var other: String={"战士":"flame","法师":"shield","道士":"spirit"}[job]
		var other_book:=""
		for id in EditionRules.ITEMS:
			if EditionRules.ITEMS[id].get("skill_book","")==other:other_book=id;break
		expect(not other_book.is_empty(),"higher profession skill has a usable book mapping")
		state.inventory.clear();state.inventory[other_book]=1;state.level=7
		text=EditionRules.Story.skill_brief(state,objective)
		expect("入门建议" in text and EditionSkills.DEFINITIONS[starter].name in text,"unusable higher book does not displace starter guidance")
		state.level=int(EditionSkills.DEFINITIONS[other].level)
		text=EditionRules.Story.skill_brief(state,objective)
		expect("已有且达到学习等级" in text and "需要学会："+EditionSkills.DEFINITIONS[other].name in text and "技能书已在背包" in text,"usable owned profession book takes priority")
		state.inventory.clear();state.warehouse[other_book]=1
		text=EditionRules.Story.skill_brief(state,objective)
		expect("需要学会："+EditionSkills.DEFINITIONS[other].name in text and "先取回背包" in text,"usable stored book takes priority over missing starter")
		state.inventory[book]=1;text=EditionRules.Story.skill_brief(state,objective)
		expect("需要学会："+EditionSkills.DEFINITIONS[starter].name in text and "技能书已在背包" in text,"bag book preferred over stored book")
		state.skills[other]={"rank":1,"proficiency":0};text=EditionRules.Story.skill_brief(state,objective)
		expect("已满足学习目标" in text and EditionSkills.DEFINITIONS[other].name in text and not "入门建议" in text,"other learned profession skill satisfies generic guidance")
	var report:={"checks":checks,"failures":failures,"scope":"three-job generic skill guidance with prepared level/book/skill state, not natural learning or rendered UI"}
	FileAccess.open("res://../artifacts/world-story/intro-skill-guidance-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
