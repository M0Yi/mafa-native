extends SceneTree
const Guard=preload("res://scripts/edition2011/story_catalog.gd")
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():
	var raw=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/world-story.json"))
	expect(Guard.validate(raw,EditionRules.ITEMS).is_empty(),"actual runtime item catalog accepts all authored tasks")
	for pair in [["npc","border:elder"],["map","0"],["item","missing"],["direction","swap"],["count",2]]:
		var changed: Dictionary=raw.duplicate(true)
		var example: Dictionary=changed.quests.filter(func(q):return q.id=="story_seal_warehouse_practice")[0]
		example.objectives[0][pair[0]]=pair[1]
		expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"invalid warehouse "+str(pair[0]))
	for jobs in [null,{},[],["战士","战士"],["未知"],[1]]:
		var changed: Dictionary=raw.duplicate(true);changed.quests[0].jobs=jobs
		expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"invalid job restriction rejected")
	for bad in [null,{},[],{"quests":{},"chapters":[]}]:expect(not Guard.validate(bad,EditionRules.ITEMS).is_empty(),"invalid root rejected")
	for field in ["gold","xp"]:
		for value in [-1,0.5,"3",INF]:
			var changed: Dictionary=raw.duplicate(true);changed.quests[0].rewards[field]=value
			expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"invalid numeric reward "+field)
	for reward in [{"missing-item":1},{"potion":0},{"potion":1.5},{"potion":10000},[]]:
		var changed: Dictionary=raw.duplicate(true);changed.quests[0].rewards.items=reward
		expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"bad item reward rejected")
	for objective in [null,{"type":"collect","item":"missing","count":1,"label":"测试"},{"type":"visit","count":2,"label":"测试"},{"type":"flag","count":1,"field":"arbitrary","key":"done","label":"测试"}]:
		var changed: Dictionary=raw.duplicate(true);changed.quests[0].objectives=[objective]
		expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"invalid or impossible objective rejected")
	for npc_id in ["missing-npc","border:elder","server:merchant:0"]:
		var invalid_service: Dictionary=raw.duplicate(true);invalid_service.quests[0].objectives=[{"type":"repair","npc":npc_id,"count":1,"label":"修理"}]
		expect(not Guard.validate(invalid_service,EditionRules.ITEMS).is_empty(),"repair requires an enabled repair service: "+npc_id)
	var changed: Dictionary=raw.duplicate(true);changed.quests[0].requires=[changed.quests[0].id]
	expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"self cycle rejected")
	changed=raw.duplicate(true);changed.quests[0].requires=["not-a-quest"]
	expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"missing prerequisite rejected")
	changed=raw.duplicate(true);changed.quests[0].start_npc="missing-npc"
	expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"missing NPC rejected")
	changed=raw.duplicate(true);changed.quests.append(changed.quests[0].duplicate(true))
	expect(not Guard.validate(changed,EditionRules.ITEMS).is_empty(),"duplicate ID rejected")
	var moth: Dictionary=EditionRules.Story.quest("story_demon_west_depths").objectives[-1]
	var lord: Dictionary=EditionRules.Story.quest("story_demon_lord").objectives[-1]
	var text: String=EditionRules.Story.population_brief(moth)
	expect("登记 2 只" in text and "120 分钟" in text,"moth population and interval match reference configuration")
	expect("跨刷新轮次" in text and "不是当前存活数" in text,"population is not advertised as live count or immediate completion")
	text=EditionRules.Story.population_brief(lord)
	expect("登记 1 只" in text and "360 分钟" in text and "跨刷新轮次" not in text,"single boss target uses actual reference interval")
	expect(EditionRules.Story.population_brief({"type":"visit","map":"622"}).is_empty(),"noncombat objective has no invented population")
	expect(EditionRules.Story.population_brief({"type":"kill","maps":["622"],"names":["不存在"],"count":1})=="尚无目标刷新位置记录","unknown target does not reuse another species counts")
	var guild_task: Dictionary=EditionRules.Story.quest("story_traveler_guild")
	for fixture in [{"guild":{"name":"玛法旅人会"}},{"guild":{"members":["别的旅人"]}},{"guild":{"members":"云游客"}}]:
		expect(EditionRules.Story.progress(fixture,guild_task,0)==0,"guild label unrelated member or malformed data cannot satisfy objective")
	expect(EditionRules.Story.progress({"guild":{"members":["云游客"]}},guild_task,0)==1,"actual guild membership satisfies objective")
	var index: int=raw.quests.find(raw.quests.filter(func(q):return q.id=="story_guild_supplies")[0])
	for value in [null,[],{},false,{"contribution":0},{"contribution":-1},{"contribution":0.5},{"contribution":"6"},{"contribution":INF},{"contribution":6,"invented_reward":100}]:
		var invalid: Dictionary=raw.duplicate(true);invalid.quests[index].guild_delivery=value
		var errors: Array=Guard.validate(invalid,EditionRules.ITEMS)
		expect(errors.any(func(e):return "story_guild_supplies" in e and "guild_delivery" in e),"bad guild definition rejected with task and field context")
	for removed in ["collect","relationship"]:
		var invalid: Dictionary=raw.duplicate(true)
		invalid.quests[index].objectives=invalid.quests[index].objectives.filter(func(o):return o.type!=removed)
		expect(not Guard.validate(invalid,EditionRules.ITEMS).is_empty(),"guild delivery cannot omit "+removed)
	var practice_index: int=raw.quests.find(raw.quests.filter(func(q):return q.id=="story_formation_practice")[0])
	for value in [null,[],{},true,"5",0,-1,0.5,INF,NAN,10001]:
		var invalid: Dictionary=raw.duplicate(true);invalid.quests[practice_index].objectives[0].min_proficiency=value
		expect(Guard.validate(invalid,EditionRules.ITEMS).any(func(e):return "story_formation_practice" in e and "min_proficiency" in e),"invalid practice threshold has locating error")
	for kind in ["collect","kill","visit"]:
		var invalid: Dictionary=raw.duplicate(true)
		invalid.quests[practice_index].objectives=[{"type":kind,"min_proficiency":5,"label":"错误目标","count":1,"item":"ore","map":"0","maps":["0"],"names":["鸡"]}]
		expect(Guard.validate(invalid,EditionRules.ITEMS).any(func(e):return "min_proficiency" in e),"threshold cannot attach to "+kind)
	var passive: Dictionary=raw.duplicate(true);passive.quests[practice_index].objectives[0].skills_by_job["战士"]="basic"
	expect(Guard.validate(passive,EditionRules.ITEMS).any(func(e):return "被动技能" in e),"uncastable passive practice rejected")
	var learning: Dictionary=passive.duplicate(true);learning.quests[practice_index].objectives[0].erase("min_proficiency")
	expect(Guard.validate(learning,EditionRules.ITEMS).is_empty(),"ordinary passive learning remains allowed")
	var branch: Dictionary=raw.quests[0].duplicate(true)
	branch.id="test_job_parent";branch.jobs=["法师"];branch.requires=[];branch.objectives=[{"type":"visit","map":"0","count":1,"label":"测试到访"}];branch.rewards={"gold":0,"xp":0,"items":{}}
	for allowed in [["法师"],["道士"],["战士","法师","道士"]]:
		var sample: Dictionary=raw.duplicate(true);sample.quests.append(branch.duplicate(true))
		var child: Dictionary=branch.duplicate(true);child.id="test_job_child";child.requires=[branch.id];child.jobs=allowed;sample.quests.append(child)
		var issues:=Guard.validate(sample,EditionRules.ITEMS)
		if allowed==["法师"]:expect(issues.is_empty(),"same-job dependency remains reachable")
		else:expect(issues.any(func(e):return "test_job_child" in e and "test_job_parent" in e and "无法完成前置" in e),"cross-job prerequisite dead end rejected")
	for pair in [["npc","border:elder"],["item","charm"],["count",2]]:
		var sample: Dictionary=raw.duplicate(true)
		var objective: Dictionary={"type":"purchase","npc":"server:merchant:116","item":"potion","count":1,"label":"购药"}
		objective[pair[0]]=pair[1];sample.quests[0].objectives=[objective]
		expect(not Guard.validate(sample,EditionRules.ITEMS).is_empty(),"impossible purchase objective rejected: "+str(pair[0]))
	var report:={"checks":checks,"failures":failures,"scope":"runtime catalog structure, rewards, materials and dependency checks; not map traversal or full content completion"}
	FileAccess.open("res://../artifacts/world-story/catalog-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
