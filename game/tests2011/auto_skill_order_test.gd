extends SceneTree
func _initialize() -> void:
	var gameplay:=EditionGameplay.new()
	var state:={"level":40,"skills":{"heal":{},"talisman":{},"trap":{},"fireball":{}},"skill_keys":{"2":"talisman","0":"heal","1":"heal"}}
	gameplay.app={"rules":{"state":state,"character":{"job":"道士"}}}
	assert(gameplay.auto_skills()==["heal","talisman"])
	state.skill_keys={"0":"fireball","1":"unknown"}
	assert(gameplay.auto_skills().is_empty())
	state.skill_keys={"0":"talisman"};state.level=1
	assert(gameplay.auto_skills().is_empty())
	state.level=40;state.skill_keys={}
	assert(gameplay.auto_skills()==gameplay.usable_skills())
	state.skill_keys={"10":"talisman","2":"heal"}
	assert(gameplay.auto_skills()==["heal","talisman"])
	gameplay.free()
	print("PASS: numeric order, duplicates, wrong class, missing skill, level gate, legacy empty bindings")
	quit()
