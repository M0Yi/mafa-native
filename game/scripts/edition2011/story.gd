extends RefCounted
static var cache: Dictionary={}
static func data() -> Dictionary:
	if cache.is_empty():cache=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/world-story.json"))
	return cache
static func quest(id: String) -> Dictionary:
	for row in data().quests:
		if row.id==id:return row
	return {}
static func chapter_progress(state: Dictionary,chapter_id: String,job: String) -> Dictionary:
	var totals: Dictionary={"total":0,"done":0,"ready":0,"active":0,"available":0,"locked":0}
	for q in data().quests:
		if not chapter_id.is_empty() and q.chapter!=chapter_id:continue
		if q.has("jobs") and job not in q.jobs:continue
		totals.total+=1
		var current: String=state.quests.get(q.id,"")
		if current=="done":totals.done+=1
		elif current=="accepted":
			if ready(state,q):totals.ready+=1
			else:totals.active+=1
		elif available(state,q):totals.available+=1
		else:totals.locked+=1
	return totals

static func recap(state: Dictionary,q: Dictionary) -> String:
	if state.quests.get(q.id)!="done":return ""
	var parts: PackedStringArray=["委托回顾",str(q.dialogue)]
	for objective in q.objectives:
		if objective.type=="talk" and not str(objective.get("dialogue","")).is_empty():
			parts.append("交谈回顾 · "+str(objective.label)+"\n"+str(objective.dialogue))
	return "\n\n".join(parts)

static func involves_npc(state: Dictionary,q: Dictionary,npc_id: String) -> bool:
	if npc_id in [q.start_npc,q.end_npc]:return true
	if state.quests.get(q.id) not in ["accepted","done"]:return false
	return q.objectives.any(func(o):return o.type in ["talk","repair","warehouse","purchase","binding","craft"] and o.npc==npc_id)
static func npc_dialogue(state: Dictionary,q: Dictionary,npc_id: String) -> String:
	if state.quests.get(q.id) not in ["accepted","done"]:return ""
	var lines: PackedStringArray=[]
	for o in q.objectives:
		if o.type=="talk" and o.npc==npc_id and not str(o.get("dialogue","")).is_empty():lines.append(o.dialogue)
	return "\n\n".join(lines)
static func binding_brief(state: Dictionary,objective: Dictionary,items: Dictionary) -> String:
	var ingredient: String=EditionRules.MEDICINE_BUNDLES.merged(EditionRules.SCROLL_BUNDLES).get(objective.get("item",""),"")
	if ingredient.is_empty():return "捆扎配方尚未接入"
	var owned:=int(state.get("inventory",{}).get(ingredient,0))
	var gold:=int(state.get("gold",0))
	return "背包 %s：%d / 6（还缺 %d）\n手续费：100 金币 · 当前 %d（还缺 %d）\n仓库物品不计入，请先取回；成品仍归你所有。"%[items[ingredient].name,owned,maxi(0,6-owned),gold,maxi(0,100-gold)]

static func skill_suggestion(state: Dictionary,job: String) -> Dictionary:
	for learned in state.get("skills",{}):
		if EditionSkills.DEFINITIONS.get(learned,{}).get("job","")==job and not job.is_empty():return {"skill":learned,"owned":false}
	var candidates: Array=[]
	for candidate in EditionSkills.DEFINITIONS:
		if EditionSkills.DEFINITIONS[candidate].job==job:candidates.append(candidate)
	candidates.sort_custom(func(a,b):return int(EditionSkills.DEFINITIONS[a].level)<int(EditionSkills.DEFINITIONS[b].level) if EditionSkills.DEFINITIONS[a].level!=EditionSkills.DEFINITIONS[b].level else str(a)<str(b))
	if candidates.is_empty():return {}
	var suggested: String=candidates[0]
	var owned_suggestion:=false
	# Prefer usable books already in the bag, then storage, before suggesting a purchase.
	for container in ["inventory","warehouse"]:
		for candidate in candidates:
			if int(EditionSkills.DEFINITIONS[candidate].level)>int(state.get("level",1)):continue
			for item in state.get(container,{}):
				if int(state[container][item])>0 and EditionRules.ITEMS.get(item,{}).get("skill_book","")==candidate:
					suggested=candidate;owned_suggestion=true;break
			if owned_suggestion:break
		if owned_suggestion:break
	return {"skill":suggested,"owned":owned_suggestion}

static func skill_brief(state: Dictionary,objective: Dictionary,character_job: String="") -> String:
	var job: String=character_job if not character_job.is_empty() else state.get("story_job","")
	if not objective.has("skills_by_job"):
		for learned in state.get("skills",{}):
			var known: Dictionary=EditionSkills.DEFINITIONS.get(learned,{})
			if known.get("job","")==job and not job.is_empty():
				return "已学会："+str(known.name)+" · "+job+"。本任务要求学会任意一种本职业技能，已满足学习目标。"
		var chosen:=skill_suggestion(state,job)
		if chosen.is_empty():return "使用本职业技能书学会一项技能；仅持有书本不算学会。"
		var suggested: String=chosen.skill
		var owned_suggestion: bool=chosen.owned
		var suggestion: Dictionary={"type":"skill","skills_by_job":{job:suggested},"count":1}
		var text: String="学会任意一种本职业技能即可。"+("下面优先列出已有且达到学习等级的技能书，其他本职业技能同样计入：\n" if owned_suggestion else "下面是入门建议，其他本职业技能同样计入：\n")+skill_brief(state,suggestion,job)
		if int(state.get("level",1))<int(EditionSkills.DEFINITIONS[suggested].level):
			var errands: PackedStringArray=[]
			for id in ["story_bichon_inn","story_bichon_apothecary","story_palace_accounts"]:
				var task:=quest(id)
				if not task.is_empty() and state.quests.get(id)!="done" and available(state,task):
					errands.append(str(task.title)+("（进行中）" if state.quests.get(id)=="accepted" else "（可接取）"))
			if not errands.is_empty():text+="\n等级未到时，可在故事列表查找这些已开放的城内见闻："+"、".join(errands)+"。它们不要求先学技能；经验按世界档位结算，不保证做完即可升到学习等级。"
		return text
	if not objective.skills_by_job.has(job):return "此技能目标限定职业："+"、".join(objective.skills_by_job.keys())+"；当前职业："+(job if not job.is_empty() else "尚未指定")+"。"
	var id: String=objective.skills_by_job.get(job,"")
	var definition: Dictionary=EditionSkills.DEFINITIONS.get(id,{})
	if definition.is_empty():return "本职业技能目标配置缺失。"
	if state.get("skills",{}).has(id):
		var text: String="已学会："+str(definition.name)+" · "+job
		if objective.has("min_proficiency"):text+="\n熟练度 %d / %d；成功施放会增长，先前练习也计入。"%[int(state.skills[id].get("proficiency",0)),int(objective.min_proficiency)]
		return text
	var bag:=0
	var stored:=0
	for item_id in EditionRules.ITEMS:
		if EditionRules.ITEMS[item_id].get("skill_book","")!=id:continue
		bag+=int(state.get("inventory",{}).get(item_id,0))
		stored+=int(state.get("warehouse",{}).get(item_id,0))
	var guidance: String="尚无对应技能书，请查看下方领书委托、书商或掉落来源。"
	if bag>0:guidance="技能书已在背包，使用后才会学会；任务不会替你自动学习。"
	elif stored>0:guidance="技能书在仓库，请先取回背包再使用。"
	var remaining:=maxi(0,int(definition.level)-int(state.get("level",1)))
	if remaining>0:guidance+="还需提升 %d 级才能学习，未达等级使用不会消耗书本。"%remaining
	return "需要学会：%s · %s %d 级学习。仅持有书本不算学会。\n对应技能书：背包 %d · 仓库 %d\n%s"%[definition.name,job,int(definition.level),bag,stored,guidance]
static func skill_book_sources(state: Dictionary,objective: Dictionary,items: Dictionary,character_job: String="") -> Array:
	var job: String=character_job if not character_job.is_empty() else state.get("story_job","")
	var desired: String=objective.get("skills_by_job",{}).get(job,"")
	var result: Array=[]
	for q in data().quests:
		var book: String=q.rewards.get("books_by_job",{}).get(job,"")
		var skill: String=items.get(book,{}).get("skill_book","")
		if skill.is_empty() or EditionSkills.DEFINITIONS.get(skill,{}).get("job","")!=job:continue
		if not desired.is_empty() and skill!=desired:continue
		if objective.has("skills_by_job") and desired.is_empty():continue
		var status: String="已领取，不会重复发书" if state.quests.get(q.id)=="done" else "进行中" if state.quests.get(q.id)=="accepted" else "可接取" if available(state,q) else "前置未完成"
		result.append({"quest":q.id,"title":q.title,"book":book,"name":str(items[book].name),"status":status})
	return result
static func skill_book_merchants(state: Dictionary,objective: Dictionary,items: Dictionary,character_job: String="") -> Array:
	var job: String=character_job if not character_job.is_empty() else state.get("story_job","")
	var desired: String=objective.get("skills_by_job",{}).get(job,"")
	var result: Array=[]
	if objective.has("skills_by_job") and desired.is_empty():return result
	for npc in EditionRegion.data().get("npcs",[]):
		if not npc.get("enabled",false):continue
		var books: Array=[]
		for row in EditionRegion.shop(npc.id).get("goods",[]):
			var spec: Dictionary=items.get(row.type,{})
			var skill: String=spec.get("skill_book","")
			if skill.is_empty() or spec.get("runtime_status","")!="supported" or int(row.get("count",0))<=0:continue
			if EditionSkills.DEFINITIONS.get(skill,{}).get("job","")!=job or (not desired.is_empty() and desired!=skill):continue
			books.append({"id":row.type,"name":str(spec.name)})
		if not books.is_empty():result.append({"npc":npc.id,"name":npc.name,"map":npc.map,"books":books})
	return result
static func skill_book_drops(objective: Dictionary,items: Dictionary,job: String) -> Array:
	var desired: String=objective.get("skills_by_job",{}).get(job,"")
	if desired.is_empty():return []
	var books: Dictionary={}
	for id in items:
		if items[id].get("skill_book","")==desired and items[id].get("runtime_status","")=="supported":books[items[id].name]=id
	var regional: Dictionary=EditionRegion.data()
	var locations: Dictionary={}
	for mid in regional.populations:
		for row in regional.populations[mid]:
			var name: String=regional.spawns[int(row[0])].name
			if not locations.has(name):locations[name]=[]
			if mid not in locations[name]:locations[name].append(mid)
	var result: Array=[]
	for name in locations:
		var monster: Dictionary=regional.monsters.get(name,{})
		if not monster.get("enabled",false):continue
		for drop in monster.get("drops",[]):
			if not books.has(drop.get("name","")):continue
			result.append({"monster":name,"level":int(monster.raw.lvl),"book":books[drop.name],"name":drop.name,"prob":str(drop.get("prob","")),"maps":locations[name].duplicate()})
	result.sort_custom(func(a,b):return a.level<b.level if a.level!=b.level else str(a.monster)<str(b.monster))
	return result
static func skill_drop_text(objective: Dictionary,items: Dictionary,job: String,map_catalog: Dictionary) -> String:
	var drops:=skill_book_drops(objective,items,job)
	if drops.is_empty():return ""
	var lines: PackedStringArray=["备用掉书线索（按怪物等级列出，最多六条；并非全部来源或必得奖励）："]
	for drop in drops.slice(0,6):
		var places: PackedStringArray=[]
		for mid in drop.maps.slice(0,3):places.append(str(map_catalog.get(mid,{}).get("name",mid)))
		lines.append("%s · %d级 · %s · 配置判定 %s · %s%s"%[drop.monster,drop.level,drop.name,drop.prob,"、".join(places)," 等%d处"%drop.maps.size() if drop.maps.size()>3 else ""])
	lines.append("普通掉落受世界档位影响，击败后仍需在地面拾取技能书并从背包使用。")
	return "\n".join(lines)
static func skill_sources_text(state: Dictionary,objective: Dictionary,items: Dictionary,character_job: String="") -> String:
	var lines: PackedStringArray=[]
	for source in skill_book_sources(state,objective,items,character_job):lines.append("技能书委托：%s → %s · %s"%[source.title,source.name,source.status])
	return "\n".join(lines)
static func available(state: Dictionary,q: Dictionary) -> bool:
	if q.has("jobs") and state.get("story_job","") not in q.jobs:return false
	for id in q.requires:
		if state.quests.get(id)!="done":return false
	return true
static func displayed_count(state: Dictionary,q: Dictionary,index: int) -> int:
	var objective: Dictionary=q.objectives[index]
	if objective.type=="skill" and objective.has("min_proficiency"):
		var id: String=objective.skills_by_job.get(state.get("story_job",""),"")
		return clampi(int(state.get("skills",{}).get(id,{}).get("proficiency",0)),0,int(objective.min_proficiency))
	return progress(state,q,index)
static func displayed_goal(q: Dictionary,index: int) -> int:
	return int(q.objectives[index].get("min_proficiency",q.objectives[index].count))
static func displayed_label(state: Dictionary,q: Dictionary,index: int) -> String:
	var objective: Dictionary=q.objectives[index]
	if objective.type=="skill" and objective.has("min_proficiency"):
		var id: String=objective.skills_by_job.get(state.get("story_job",""),"")
		return str(EditionSkills.DEFINITIONS.get(id,{}).get("name","职业技能"))+" 熟练度"
	return str(objective.label)
static func objective_unlocked(state: Dictionary,q: Dictionary,index: int) -> bool:
	return not q.objectives[index].get("after_previous",false) or range(index).all(func(prior):return progress(state,q,prior)>=int(q.objectives[prior].count))
static func objective_text(state: Dictionary,q: Dictionary,index: int) -> String:
	var objective: Dictionary=q.objectives[index]
	if state.quests.get(q.id)=="done":return "已完成 · "+str(objective.label)
	var hint: String=" · 先完成前面的目标，再交谈" if not objective_unlocked(state,q,index) else ""
	return "%s  %d/%d%s"%[displayed_label(state,q,index),displayed_count(state,q,index),displayed_goal(q,index),hint]
static func progress(state: Dictionary,q: Dictionary,index: int) -> int:
	var objective: Dictionary=q.objectives[index]
	match objective.type:
		"relationship":
			if objective.field=="guild":
				var members=state.get("guild",{}).get("members",[])
				return 1 if members is Array and objective.name in members else 0
			return 1 if objective.field in ["friends","party"] and objective.name in state.get(objective.field,[]) else 0
		"collect":
			var available_count:=int(state.inventory.get(objective.item,0))
			for previous in range(index):
				var earlier: Dictionary=q.objectives[previous]
				if earlier.type=="collect" and earlier.item==objective.item:available_count-=int(earlier.count)
			return clampi(available_count,0,int(objective.count))
		"skill":
			if objective.has("skills_by_job"):
				var skill: String=objective.skills_by_job.get(state.get("story_job",""),"")
				if skill.is_empty() or not state.skills.has(skill):return 0
				return 1 if int(state.skills[skill].get("proficiency",0))>=int(objective.get("min_proficiency",0)) else 0
			for id in state.skills:
				if EditionSkills.DEFINITIONS.get(id,{}).get("job","")==state.get("story_job","unassigned"):return 1
			return 0
		"flag":
			if objective.field=="feast_gift" and objective.key=="completed":return 1 if state.get("feast_gift",{}).get("stage","")=="done" else 0
			return 1 if state.get(objective.field,{}).get(objective.key,false)==true else 0
	return int(state.get("story_progress",{}).get(q.id,{}).get(str(index),0))
static func collection_requirements(q: Dictionary) -> Dictionary:
	var totals: Dictionary={}
	for objective in q.objectives:
		if objective.type=="collect":totals[objective.item]=int(totals.get(objective.item,0))+int(objective.count)
	return totals
static func ready(state: Dictionary,q: Dictionary) -> bool:
	if state.quests.get(q.id)!="accepted":return false
	var totals:=collection_requirements(q)
	for item in totals:
		if int(state.inventory.get(item,0))<int(totals[item]):return false
	for index in range(q.objectives.size()):
		if progress(state,q,index)<int(q.objectives[index].count):return false
	return true
static func observe(state: Dictionary,event: String,payload: Dictionary) -> bool:
	var changed:=false
	for q in data().quests:
		if state.quests.get(q.id)!="accepted":continue
		for index in range(q.objectives.size()):
			var o: Dictionary=q.objectives[index]
			if o.type!=event:continue
			if not objective_unlocked(state,q,index):continue
			if payload.get("party_arrival_only",false) and not o.has("party_member"):continue
			if event=="talk" and o.npc!=payload.get("npc",""):continue
			if event=="repair" and (o.npc!=payload.get("npc","") or int(payload.get("repaired",0))<=0):continue
			if event=="purchase" and (o.npc!=payload.get("npc","") or o.item!=payload.get("item","")):continue
			if event in ["binding","craft"] and (o.npc!=payload.get("npc","") or o.item!=payload.get("item","")):continue
			if event=="warehouse":
				if o.map!=payload.get("map","") or o.item!=payload.get("item","") or o.direction!=payload.get("direction",""):continue
				if o.direction=="withdraw" and q.objectives.slice(0,index).any(func(prior):return prior.type=="warehouse" and prior.direction=="deposit" and progress(state,q,q.objectives.find(prior))<int(prior.count)):continue
			if event=="mine" and (o.map!=payload.get("map","") or payload.get("item","") not in preload("res://scripts/edition2011/mining.gd").ORES):continue
			if event=="visit" and o.map!=payload.get("map",""):continue
			if event=="visit" and o.has("party_member") and (o.party_member not in state.get("party",[]) or not payload.get("arrival",false)):continue
			if event=="visit" and o.has("party_member") and not preload("res://scripts/edition2011/traveler_identity.gd").alive(state,o.party_member):continue
			if event=="kill" and (payload.get("name","") not in o.names or payload.get("map","") not in o.maps):continue
			var before:=progress(state,q,index)
			if before>=int(o.count):continue
			if not state.has("story_progress"):state.story_progress={}
			if not state.story_progress.has(q.id):state.story_progress[q.id]={}
			state.story_progress[q.id][str(index)]=mini(int(o.count),before+1);changed=true
	return changed
static func npc_task_priority(state: Dictionary,q: Dictionary,npc_id: String) -> int:
	var current: String=state.quests.get(q.id,"")
	if current=="done":return 4
	if current=="accepted":
		if q.end_npc==npc_id and ready(state,q):return 0
		for index in range(q.objectives.size()):
			var o: Dictionary=q.objectives[index]
			if o.type in ["talk","repair","warehouse","purchase","binding","craft"] and o.npc==npc_id and objective_unlocked(state,q,index) and progress(state,q,index)<int(o.count):return 1
		return 3
	return 2 if q.start_npc==npc_id and available(state,q) else 5
static func npc_markers(state: Dictionary) -> Dictionary:
	var priorities: Dictionary={}
	var services: Dictionary={}
	for q in data().quests:
		if q.get("status","") in ["planned","not_implemented","missing","disabled"]:continue
		var current: String=state.quests.get(q.id,"")
		if current=="done":continue
		if current=="accepted":
			if ready(state,q):priorities[q.end_npc]=3
			for index in range(q.objectives.size()):
				var o: Dictionary=q.objectives[index]
				if o.type in ["talk","repair","warehouse","purchase","binding","craft"] and objective_unlocked(state,q,index) and progress(state,q,index)<int(o.count):
					priorities[o.npc]=maxi(2,int(priorities.get(o.npc,0)))
					if o.type=="repair":services[o.npc]=true
		elif available(state,q):priorities[q.start_npc]=maxi(1,int(priorities.get(q.start_npc,0)))
	for q in EditionVillage.quests():
		var current: String=state.quests.get(q.id,"")
		if current=="accepted" and EditionVillage.ready(state,q.id):priorities["border:elder"]=3
		elif current.is_empty() and EditionVillage.available(state,q):priorities["border:elder"]=maxi(1,int(priorities.get("border:elder",0)))
	var result: Dictionary={}
	for id in priorities:result[id]="任务服务" if int(priorities[id])==2 and services.has(id) else ["","可接取","任务见闻","可交付"][int(priorities[id])]
	return result
static func tracked(state: Dictionary) -> Dictionary:
	var id: String=state.get("tracked_story","")
	return quest(id) if state.quests.get(id)=="accepted" else {}
static func navigable(objective: Dictionary) -> bool:
	return objective.get("type","") in ["mine","talk","visit","kill","repair","warehouse","purchase","binding","craft","collect","relationship"] or (objective.get("type","")=="flag" and [objective.get("field",""),objective.get("key","")] in [["fire_dragon","surveyed"],["cook_trial","claimed"],["feast_gift","completed"]])
static func next_objective(state: Dictionary,q: Dictionary) -> Dictionary:
	for index in range(q.objectives.size()):
		if progress(state,q,index)<int(q.objectives[index].count):return q.objectives[index]
	return {}
static func tracker_text(state: Dictionary) -> String:
	var q:=tracked(state)
	if q.is_empty():return ""
	if ready(state,q):return q.title+" · 返回交付"
	for index in range(q.objectives.size()):
		if progress(state,q,index)<int(q.objectives[index].count):return "%s · %s %d/%d"%[q.title,displayed_label(state,q,index),displayed_count(state,q,index),displayed_goal(q,index)]
	return q.title
static func valid(state: Dictionary) -> bool:
	if state.has("tracked_story") and not state.tracked_story is String:return false
	if state.has("story_job") and state.story_job not in ["战士","法师","道士"]:return false
	for q in data().quests:
		if state.get("quests",{}).has(q.id) and state.quests[q.id] not in ["accepted","done"]:return false
	if not state.has("story_progress"):return true
	if not state.story_progress is Dictionary:return false
	for id in state.story_progress:
		if not state.story_progress[id] is Dictionary:return false
		for value in state.story_progress[id].values():
			if not (value is int or value is float) or not is_finite(float(value)) or int(value)!=value or value<0:return false
	return true

static func population_brief(objective: Dictionary) -> String:
	if objective.get("type","")!="kill":return ""
	var regional: Dictionary=EditionRegion.data()
	var count:=0;var intervals: Array[int]=[]
	for mid in objective.get("maps",[]):
		for row in regional.populations.get(mid,[]):
			var source: Dictionary=regional.spawns[int(row[0])]
			if source.name not in objective.get("names",[]):continue
			count+=1
			var minutes:=int(source.interval) if int(source.interval)>0 else 10
			if minutes not in intervals:intervals.append(minutes)
	if count==0:return "尚无目标刷新位置记录"
	intervals.sort()
	var timing: String=str(intervals[0]) if intervals.size()==1 else "%d–%d"%[intervals[0],intervals[-1]]
	var text: String="目标区域合计登记 %d 只 · 刷新间隔 %s 分钟；不是当前存活数，也不是剩余等待时间。"%[count,timing]
	if int(objective.get("count",0))>count:text+=" 本次击杀数量超过登记数量，可能需要跨刷新轮次完成。"
	return text

static func combat_brief(objective: Dictionary) -> String:
	if objective.get("type")!="kill":return ""
	var levels: Array[int]=[];var health: Array[int]=[]
	var attacks: Array[int]=[];var armor: Array[int]=[];var resistance: Array[int]=[]
	for name in objective.names:
		var raw: Dictionary=EditionRegion.data().monsters.get(name,{}).get("raw",{})
		if not raw.has("lvl") or not raw.has("hp"):return "目标配置尚待核对"
		levels.append(int(raw.lvl));health.append(int(raw.hp))
		attacks.append(int(raw.get("dcMax",0)));armor.append(int(raw.get("ac",0)));resistance.append(int(raw.get("mac",0)))
	if levels.is_empty():return "目标配置尚待核对"
	levels.sort();health.sort()
	var level_text: String=str(levels[0]) if levels[0]==levels[-1] else "%d–%d"%[levels[0],levels[-1]]
	var hp_text: String=str(health[0]) if health[0]==health[-1] else "%d–%d"%[health[0],health[-1]]
	var rebuilt: bool=objective.names.any(func(name):return EditionRegion.data().monsters.get(name,{}).get("provenance","")=="singleplayer_reconstruction")
	return ("本目标含单机重建数值与掉落；不是历史服务器原表。\n" if rebuilt else "")+"目标配置：%s 级 · 生命 %s（非建议角色等级）"%[level_text,hp_text]+"\n攻击上限 %s · 物防 %s · 魔防 %s（当前目标配置）"%[combat_range(attacks),combat_range(armor),combat_range(resistance)]+"\n"+population_brief(objective)

static func combat_range(values: Array[int]) -> String:
	values.sort()
	return str(values[0]) if values[0]==values[-1] else "%d–%d"%[values[0],values[-1]]
