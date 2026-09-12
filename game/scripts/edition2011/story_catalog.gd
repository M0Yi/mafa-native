extends RefCounted
# Validate authored data before opening the save database. This is not a playability audit.
static func integer(value,minimum: int,maximum:=2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum and int(value)==value
static func strings(value) -> bool:
	if not value is Array:return false
	for entry in value:
		if not entry is String or entry.is_empty():return false
	return true
static func amounts(value,items: Dictionary,path: String,errors: Array[String]) -> void:
	if not value is Dictionary:errors.append(path+" 必须是物品数量表");return
	for id in value:
		if not items.has(id):errors.append(path+" 未知或不可用物品 "+str(id))
		if not integer(value[id],1,9999):errors.append(path+" 数量必须为 1–9999 的整数："+str(id))
static func validate(raw,items: Dictionary,maps: Dictionary={}) -> Array[String]:
	var errors: Array[String]=[]
	if not raw is Dictionary or not raw.get("quests") is Array or not raw.get("chapters") is Array:return ["world-story.json 缺少任务或地区列表"]
	var chapters: Dictionary={};var quests: Dictionary={};var quest_jobs: Dictionary={}
	var npcs: Dictionary={"border:elder":{"map":"0"}}
	for npc in EditionRegion.data().npcs:
		if npc.enabled:npcs[npc.id]=npc
	for chapter in raw.chapters:
		if not chapter is Dictionary or not chapter.get("id") is String:errors.append("地区记录缺少 ID");continue
		if chapters.has(chapter.id):errors.append("重复地区 ID："+chapter.id)
		chapters[chapter.id]=true
		for key in ["title","premise"]:
			if not chapter.get(key) is String:errors.append(chapter.id+" 缺少地区文本 "+key)
		if not strings(chapter.get("maps")):errors.append(chapter.id+" 地区地图列表无效")
	for q in raw.quests:
		if not q is Dictionary or not q.get("id") is String:errors.append("任务记录缺少 ID");continue
		var id: String=q.id
		if id.is_empty() or quests.has(id):errors.append("无效或重复任务 ID："+id)
		quests[id]=q.get("requires",[]) if strings(q.get("requires")) else []
		for key in ["start_npc","end_npc"]:
			if not npcs.has(q.get(key)):errors.append(id+" 未启用的任务人物 "+key)
		for key in ["title","kind","start_npc","end_npc","dialogue","completion"]:
			if not q.get(key) is String or str(q.get(key,"")).is_empty():errors.append(id+" 缺少文本 "+key)
		if not chapters.has(q.get("chapter")):errors.append(id+" 未知地区 chapter")
		if not strings(q.get("requires")):errors.append(id+" 前置必须是任务 ID 列表")
		var jobs: Array=["战士","法师","道士"]
		if q.has("jobs"):
			if not strings(q.jobs) or q.jobs.is_empty():errors.append(id+" 无效职业限制");continue
			if q.jobs.any(func(job):return job not in jobs) or q.jobs.any(func(job):return q.jobs.count(job)!=1):errors.append(id+" 无效或重复职业");continue
			jobs=q.jobs
		quest_jobs[id]=jobs.duplicate()
		if not q.get("rewards") is Dictionary:errors.append(id+" 缺少 rewards");continue
		var reward: Dictionary=q.rewards
		for key in ["gold","xp"]:
			if not integer(reward.get(key),0):errors.append(id+" rewards."+key+" 必须是非负整数")
		amounts(reward.get("items"),items,id+" rewards.items",errors)
		for key in ["books_by_job","equipment_by_job"]:
			if not reward.has(key):continue
			if not reward[key] is Dictionary:errors.append(id+" "+key+" 必须是职业映射");continue
			if reward[key].size()!=jobs.size():errors.append(id+" "+key+" 必须匹配任务职业")
			for job in jobs:
				var item: Dictionary=items.get(reward[key].get(job),{})
				if item.is_empty():errors.append(id+" "+key+" 未知物品或职业："+job);continue
				if key=="equipment_by_job" and not item.has("slot"):errors.append(id+" 奖励不是装备："+job)
				if key=="books_by_job" and EditionSkills.DEFINITIONS.get(item.get("skill_book"),{}).get("job")!=job:errors.append(id+" 奖励不是本职业技能书："+job)
		if not q.get("objectives") is Array:errors.append(id+" 缺少 objectives");continue
		var consumed: Dictionary={}
		for index in range(q.objectives.size()):
			var o=q.objectives[index];var path: String=id+" objectives[%d]"%index
			if not o is Dictionary:errors.append(path+" 必须是目标记录");continue
			if o.has("after_previous") and (not o.after_previous is bool or o.get("type")!="talk" or index==0):errors.append(path+" after_previous 仅用于后续交谈目标且必须为布尔值")
			if not integer(o.get("count"),1,9999):errors.append(path+" count 必须为正整数")
			if not o.get("label") is String or str(o.get("label","")).is_empty():errors.append(path+" 缺少 label")
			if o.has("party_member") and (o.get("type")!="visit" or o.party_member not in ["云游客","青禾","远山","轻舟"]):errors.append(path+" 无效指定同行者")
			if o.has("min_proficiency"):
				if o.get("type")!="skill" or not o.get("skills_by_job") is Dictionary or not integer(o.min_proficiency,1,10000):errors.append(path+" 无效熟练度门槛 min_proficiency")
				elif o.skills_by_job.values().any(func(skill):return EditionSkills.DEFINITIONS.get(skill,{}).get("passive",false)):errors.append(path+" min_proficiency 不能要求被动技能通过施放练习")
			match o.get("type"):
				"collect":
					amounts({o.get("item",""):o.get("count")},items,path,errors)
					if integer(o.get("count"),1,9999):consumed[o.get("item","")]=int(consumed.get(o.get("item",""),0))+int(o.count)
				"mine":
					if o.get("map","") not in preload("res://scripts/edition2011/mining.gd").MAPS:errors.append(path+" 未支持的采矿地图")
				"kill":
					if not strings(o.get("maps")) or o.get("maps",[]).is_empty() or not strings(o.get("names")) or o.get("names",[]).is_empty():errors.append(path+" 缺少击杀地图或怪物列表")
				"visit","talk","repair","warehouse","purchase","binding","craft","skill","flag","relationship":
					if o.get("count")!=1:errors.append(path+" 此类目标 count 必须为 1")
					if o.type=="visit" and (not o.get("map") is String or (not maps.is_empty() and not maps.has(o.map))):errors.append(path+" 未知地图")
					if o.type=="purchase" and (not npcs.has(o.get("npc")) or not items.has(o.get("item")) or items.get(o.get("item"),{}).get("runtime_status","supported")!="supported" or not EditionRegion.shop(o.get("npc","")).get("goods",[]).any(func(g):return g.get("type")==o.get("item") and int(g.get("count",0))>0)):errors.append(path+" 指定商店没有可购买的任务物品")
					if o.type=="craft":
						var peach: bool=o.get("npc")=="server:merchant:126" and preload("res://scripts/edition2011/peach_crafting.gd").recipes().any(func(r):return r.product==o.get("item"))
						var mystery: bool=o.get("npc")=="server:merchant:109" and jobs.all(func(job):return preload("res://scripts/edition2011/mystery_books.gd").WEAPONS[job].product==o.get("item"))
						if not peach and not mystery:errors.append(path+" 无效合成目标")
					if o.type=="binding" and (o.get("npc")!="server:merchant:105" or not EditionRules.MEDICINE_BUNDLES.merged(EditionRules.SCROLL_BUNDLES).has(o.get("item",""))):errors.append(path+" 无效捆扎目标")
					if o.type=="warehouse" and (not npcs.has(o.get("npc")) or not EditionRegion.shop(o.get("npc","")).get("warehouse",false) or npcs.get(o.get("npc"),{}).get("map")!=o.get("map") or not items.has(o.get("item")) or o.get("direction") not in ["deposit","withdraw"]):errors.append(path+" 无效仓储操作目标")
					if o.type=="repair" and (not npcs.has(o.get("npc")) or not EditionRegion.shop(o.get("npc","")).get("repair",false)):errors.append(path+" 无效修理人物")
					if o.type=="talk" and (not npcs.has(o.get("npc")) or not o.get("dialogue") is String):errors.append(path+" 缺少人物或对白")
					if o.type=="flag" and [o.get("field"),o.get("key")] not in [["fire_dragon","surveyed"],["cook_trial","claimed"],["feast_gift","completed"]]:errors.append(path+" 未支持的状态目标")
					if o.type=="relationship" and (o.get("field") not in ["friends","party","guild"] or o.get("name") not in ["云游客","青禾","远山","轻舟"]):errors.append(path+" 未支持的旅人关系")

					if o.type=="skill" and o.has("skills_by_job"):
						if not o.skills_by_job is Dictionary:errors.append(path+" 技能职业映射无效")
						else:
							if o.skills_by_job.size()!=jobs.size():errors.append(path+" 技能映射必须匹配任务职业")
							for job in jobs:
								if EditionSkills.DEFINITIONS.get(o.skills_by_job.get(job),{}).get("job")!=job:errors.append(path+" 职业技能不匹配："+job)
				_ :errors.append(path+" 未知目标类型")
		if q.has("guild_delivery"):
			if not q.guild_delivery is Dictionary:errors.append(id+" guild_delivery 必须是行会交付配置")
			else:
				if not integer(q.guild_delivery.get("contribution"),1):errors.append(id+" guild_delivery.contribution 必须为正整数")
				for key in q.guild_delivery:
					if key!="contribution":errors.append(id+" guild_delivery 未支持字段："+str(key))
			if consumed.is_empty():errors.append(id+" 行会交付必须包含实际消耗材料")
			if not q.objectives.any(func(o):return o is Dictionary and o.get("type")=="relationship" and o.get("field")=="guild"):
				errors.append(id+" 行会交付缺少成员关系目标")
		for item in consumed:
			if consumed[item]>9999:errors.append(id+" 合计交付数量超出物品上限："+str(item))
	var old: Dictionary={}
	for q in EditionVillage.quests():old[q.id]=true
	var pending: Dictionary=quests.duplicate(true);var resolved: Dictionary=old.duplicate()
	for id in quests:
		for previous in quests[id]:
			if not quests.has(previous) and not old.has(previous):errors.append(id+" 未知前置 "+previous)
			if quest_jobs.has(previous):
				for job in quest_jobs.get(id,[]):
					if job not in quest_jobs[previous]:errors.append(id+" 职业 "+job+" 无法完成前置 "+previous)
	while not pending.is_empty():
		var progressed:=false
		for id in pending.keys():
			if pending[id].all(func(previous):return resolved.has(previous)):
				resolved[id]=true;pending.erase(id);progressed=true
		if not progressed:
			errors.append("前置循环或缺失，无法解锁："+", ".join(pending.keys()));break
	return errors
