class_name EditionVillage
extends RefCounted
const SPAWN:=Vector2i(289,618)
const PATROL:=Vector2i(265,665)
static var cache: Dictionary={}
static func data() -> Dictionary:
	if cache.is_empty():cache=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/novice-village.json"))
	return cache
static func nearby(map_id: String,cell: Vector2i) -> bool:
	return map_id=="0" and Rect2i(250,590,80,90).has_point(cell)
static func quests() -> Array:return data().quests
static func quest(id: String) -> Dictionary:
	for q in quests():
		if q.id==id:return q
	return {}
static func entities() -> Array:
	var list: Array=data().npcs.duplicate(true)
	for i in range(data().chickens.size()):
		list.append({"id":"border:chicken:"+str(i),"kind":"monster","species":"village_chicken","name":"鸡","bank":"mon17","frame":0,"frames":4,"direction":i%8,"cell":data().chickens[i].duplicate(),"origin":data().chickens[i].duplicate(),"hp":12,"max_hp":12,"respawn":0.0,"generation":0,"motion":"stand","motion_time":0.0})
	return list
static func travelers() -> Array:
	var list: Array=[]
	var cells:=[[283,618],[290,622],[295,616],[285,624]]
	for i in range(4):
		list.append({"id":"traveler:yunyouke" if i==0 else "border:traveler:"+str(i),"kind":"traveler","hp":250,"max_hp":250,"generation":0,"pk_points":0,"name":["云游客","青禾","远山","轻舟"][i],"bank":"hum","gender":"男" if i%2==0 else "女","job":["战士","道士","法师","战士"][i],"equipment":{"armor":"robe","weapon":"wood_sword"},"cell":cells[i].duplicate(),"origin":cells[i].duplicate(),"direction":4})
	return list
static func available(state: Dictionary,q: Dictionary) -> bool:
	return q.previous.is_empty() or state.quests.get(q.previous)=="done"
static func ready(state: Dictionary,id: String) -> bool:
	match id:
		"nv_arrival":return true
		"nv_equip":return state.equipment.has("weapon") and state.equipment.has("armor")
		"nv_hunt":return int(state.get("novice",{}).get("chickens",0))>=3 and int(state.inventory.get("chicken_meat",0))>=3
		"nv_patrol":return state.get("novice",{}).get("patrol",false)
	return false
static func current(state: Dictionary) -> Dictionary:
	for q in quests():
		if state.quests.get(q.id)!="done":return q
	return {}
static func progress(state: Dictionary,q: Dictionary) -> String:
	if state.quests.get(q.id)=="done":return "已完成"
	if not available(state,q):return "完成前一个任务后开启"
	if state.quests.get(q.id)!="accepted":return "尚未接受 · 找边界村长"
	if ready(state,q.id):return "可以交付 · 返回边界村长"
	if q.id=="nv_hunt":return "击败鸡 %d/3 · 鸡肉 %d/3"%[mini(3,int(state.get("novice",{}).get("chickens",0))),mini(3,int(state.inventory.get("chicken_meat",0)))]
	return q.objective
