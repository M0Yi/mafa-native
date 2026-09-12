class_name EditionRules
extends RefCounted
const Story=preload("res://scripts/edition2011/story.gd")
signal story_progressed(text: String)
signal item_performed(type: String,event: String)

const LEGACY_ITEMS := {
	"potion":{"name":"金创药","price":30,"weight":1,"heal":60,"icon":398},
	"mana":{"name":"魔法药","price":30,"weight":1,"mana":50,"icon":394},
	"ore":{"name":"铁矿","price":15,"weight":2,"icon":281},
	"sword":{"name":"铁剑","price":250,"weight":8,"attack":6,"slot":"weapon","durability":100,"icon":36},
	"robe":{"name":"布衣","price":200,"weight":5,"defense":3,"slot":"armor","durability":100,"icon":60},
	"wood_sword":{"name":"木剑","price":80,"weight":4,"attack":3,"slot":"weapon","durability":100,"icon":30},
	"chicken_meat":{"name":"鸡肉","price":5,"weight":1,"icon":13},
	"helmet":{"name":"青铜头盔","price":100,"weight":4,"defense":1,"slot":"helmet","durability":100,"icon":100},
	"ring":{"name":"古铜戒指","price":80,"weight":1,"attack":1,"slot":"ring","durability":100,"icon":145},
	"bracelet":{"name":"铁手镯","price":80,"weight":1,"defense":1,"slot":"bracelet","durability":100,"icon":180},
	"boots":{"name":"布鞋","price":60,"weight":1,"defense":1,"slot":"boots","durability":100,"icon":560},
	"charm":{"name":"护身符","price":8,"weight":1,"icon":270},
	"poison":{"name":"毒粉","price":10,"weight":1,"icon":251}}
const MEDICINE_BUNDLES={"ref:191":"ref:161","ref:192":"ref:162","ref:258":"ref:96","ref:259":"ref:97","ref:256":"potion","ref:257":"mana"}
const SCROLL_BUNDLES={"ref:262":"ref:134"}
static var ITEMS: Dictionary=load_item_catalog()
static func load_item_catalog() -> Dictionary:
	var result:=LEGACY_ITEMS.duplicate(true)
	var raw=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/regional-data.json"))
	if raw is Dictionary:
		for id in raw.get("items",{}):
			var item: Dictionary=raw.items[id]
			for skill_id in EditionSkills.DEFINITIONS:
				if int(item.get("std_mode",-1))==4 and item.name==EditionSkills.DEFINITIONS[skill_id].name:
					item=item.duplicate(true);item.skill_book=skill_id;item.runtime_status="supported"
			if MEDICINE_BUNDLES.has(id):item=item.duplicate(true);item.runtime_status="supported";item.material_bundle={"type":MEDICINE_BUNDLES[id],"count":6,"provenance":"reference_merchant_medicine_bundle"}
			if SCROLL_BUNDLES.has(id):item=item.duplicate(true);item.runtime_status="supported";item.material_bundle={"type":SCROLL_BUNDLES[id],"count":6,"provenance":"reference_merchant_scroll_bundle"}
			if id=="ref:135":item=item.duplicate(true);item.runtime_status="supported";item.description="作用于当前武器，可能祝福、诅咒或无变化；无变化也消耗一瓶。"
			if id=="ref:134":item=item.duplicate(true);item.runtime_status="supported";item.utility="return";item.provenance="singleplayer_return_to_border_village_no_pk_prison"
			if id in ["ref:285","ref:286","ref:287","ref:288","ref:289","ref:290"]:item=item.duplicate(true);item.runtime_status="supported";item.crafting_material_only=true;item.note="可用于桃源合成；饮用效果尚未接入"
			if id=="ref:226":item=item.duplicate(true);item.runtime_status="supported";item.currency_exchange=true
			if item.runtime_status=="supported" or result.has(id):result[id]=item
	# Single-player unpacking bridge; original colored poison effects remain separate work.
	for id in ["ref:44","ref:45","ref:50","ref:51","ref:52","ref:53"]:
		if result.has(id):result[id]["material_bundle"]={"type":"poison","count":maxi(1,int(result[id].raw.duraMax)/100),"provenance":"singleplayer_unpack_100_durability_per_unit"}
	result["dragon_story_scale"]={"name":"火龙鳞片（单机凭证）","price":0,"weight":1,"icon":822,"quest_material":true,"provenance":"singleplayer_reconstruction_reuses_dragon_scale_icon"}
	result["return_stone"]={"name":"回城石","price":500,"weight":1,"icon":270,"utility":"return","runtime_status":"supported"}
	result["reset_stone"]={"name":"洗点石","price":2000,"weight":1,"icon":251,"utility":"reset"}
	return result
var store: EditionStore
var state: Dictionary={}
var character: Dictionary={}
var message:=""

func new_world(profile: Dictionary,preset: String) -> Dictionary:
	return {"schema_version":1,"revision":0,"preset":preset,"map":"0","cell":[EditionVillage.SPAWN.x,EditionVillage.SPAWN.y],"village_entry_version":1,"traveler_identity_version":1,
		"level":1,"xp":0,"gold":500,"tokens":0,"hp":100,"mp":80,"time":0.0,
		"inventory":{"potion":5,"mana":5,"charm":20,"poison":20},"warehouse":{},
		"equipment":{},"durability":{},"visited":[],"quests":{},"kills":0,
		"hero":{},"friends":[],"party":[],"guild":{},"inner":0,"meridian":0,
		"skills":{},"provenance":"singleplayer_reconstruction_v1"}

func attach(profile: Dictionary,preset: String="easy") -> bool:
	character=profile
	state=store.load_world(profile.id)
	if not store.error.is_empty():message=store.error;return false
	if state.is_empty():
		state=new_world(profile,preset)
		if not store.commit(profile.id,state,"create_world"):message=store.error;return false
	elif not valid(state):message="角色字段损坏；原数据库及备份保留，未覆盖";return false
	if not state.has("items"):
		if not store.backup():message=store.error;return false
		var migrated:=state.duplicate(true);EditionInventory.migrate(migrated)
		if not EditionInventory.validate(migrated):message="物品迁移校验失败，原存档保留";return false
		if not store.commit(profile.id,migrated,"migrate_inventory_v1"):message=store.error;return false
		state=migrated
	if int(state.get("village_entry_version",0))<1:
		var next:=state.duplicate(true);next.village_previous_location={"map":next.map,"cell":next.cell.duplicate()};next.map="0";next.cell=[EditionVillage.SPAWN.x,EditionVillage.SPAWN.y];next.village_entry_version=1
		if not apply(next,"initialize_village_entry"):return false
	if int(state.get("regional_rules_version",0))<1:
		if not store.backup():message=store.error;return false
		var next:=state.duplicate(true);next.regional_rules_version=1
		# Old prototypes used one unisex robe ID. Keep the equipped female robe
		# by mapping it to the reference female item, preserving its instance ID.
		if profile.gender=="女" and ITEMS.has("ref:5"):
			for item in next.items:
				if item.container=="equipment" and item.type=="robe":item.type="ref:5"
		EditionInventory.mirror(next)
		if not apply(next,"migrate_regional_rules_v1"):return false
	if int(state.get("traveler_identity_version",0))<1:
		var next:=state.duplicate(true)
		if not preload("res://scripts/edition2011/traveler_identity.gd").migrate(next):message="旅人状态迁移失败；原存档保留";return false
		if not store.backup():message=store.error;return false
		if not apply(next,"migrate_traveler_identity_v1"):return false
	state.story_job=profile.job
	if not repair_novice_clothing():return false
	return true

func novice_reward_items(q: Dictionary) -> Dictionary:
	var rewards: Dictionary=q.reward.duplicate(true)
	if character.gender=="女" and rewards.has("robe"):
		rewards["ref:5"]=int(rewards.get("ref:5",0))+int(rewards.robe)
		rewards.erase("robe")
	return rewards

func repair_novice_clothing() -> bool:
	# Old rewards had no source UID: exchange at most one owned starter robe,
	# only for a female character blocked before the equipment task completes.
	if character.gender!="女" or state.get("novice_clothing_version",0)>=1:return true
	if state.quests.get("nv_arrival")!="done" or state.quests.get("nv_equip")=="done":return true
	if state.items.any(func(item):return item.type=="ref:5"):return true
	var next:=state.duplicate(true)
	for item in next.items:
		if item.type!="robe" or item.container not in ["inventory","warehouse","equipment"]:continue
		if not ITEMS.has("ref:5"):message="女款新手布衣配置缺失，原存档保留";return false
		item.type="ref:5";next.novice_clothing_version=1
		next.novice_clothing_correction={"uid":item.uid,"from":"robe","to":"ref:5"}
		EditionInventory.mirror(next)
		if not store.backup():message=store.error;return false
		message="新手布衣已更换为女款，位置与耐久保留。"
		return apply(next,"repair_novice_clothing_v1")
	return true

func receive_damage(damage: int,poison:=false,seconds:=0.0,stone:=false) -> bool:
	if damage<=0 or state.hp<=0:return false
	var next:=state.duplicate(true);next.hp=maxi(0,int(state.hp)-damage)
	if next.hp<=0:next.erase("green_poison")
	elif poison and float(next.get("green_poison",{}).get("until",0))<=seconds+60:
		next.green_poison={"until":seconds+60,"next":seconds+1,"power":3}
	if next.hp<=0:next.erase("stone_until")
	elif stone:next.stone_until=maxf(float(next.get("stone_until",0)),seconds+5)
	next.time=maxf(float(next.time),seconds)
	message="受到 %d 点伤害"%damage+("，身中绿毒" if poison and next.hp>0 else "")+("，被石化" if stone and next.hp>0 else "")
	return apply(next,"monster_hit")

func stoned(seconds: float) -> bool:
	return state.hp>0 and seconds<float(state.get("stone_until",0))

func tick_green_poison(seconds: float) -> bool:
	var poison: Dictionary=state.get("green_poison",{})
	if poison.is_empty():return false
	if seconds<float(poison.next) and seconds<float(poison.until):return false
	var next:=state.duplicate(true)
	var ticks:=maxi(0,int(floor((minf(seconds,float(poison.until)-0.0000001)-float(poison.next))))+1)
	var damage:=ticks*int(poison.power)
	next.hp=maxi(0,int(next.hp)-damage);next.time=maxf(float(next.time),seconds)
	if next.hp<=0 or seconds>=float(poison.until):next.erase("green_poison")
	else:next.green_poison.next=float(poison.next)+ticks
	message="绿毒造成 %d 点伤害"%damage if damage>0 else "绿毒已经消退"
	return apply(next,"green_poison_tick")

func weight(s: Dictionary) -> int:
	var total:=0
	for id in s.inventory:total+=int(s.inventory[id])*int(ITEMS.get(id,{}).get("weight",1))
	return total

func valid(s: Dictionary) -> bool:
	if s.has("mining") and not preload("res://scripts/edition2011/mining.gd").valid(s.mining):return false
	if s.has("trapped_monsters"):
		if not s.trapped_monsters is Dictionary:return false
		for id in s.trapped_monsters:
			var record=s.trapped_monsters[id]
			if not id is String or not preload("res://scripts/edition2011/trap_status.gd").valid_snapshot(record) or record.status.id!=id:return false
	if s.has("bagua_clues") and not preload("res://scripts/edition2011/bagua_clues.gd").valid(s.bagua_clues):return false
	if s.has("feast_gift") and not preload("res://scripts/edition2011/feast_gift.gd").valid(s.feast_gift):return false
	if s.has("cook_trial") and not preload("res://scripts/edition2011/cook_trial_state.gd").valid(s.cook_trial):return false
	if s.has("dark_temple"):
		var session=s.dark_temple
		if not session is Dictionary or not session.get("active") is bool:return false
		if not (session.get("deadline") is int or session.get("deadline") is float) or not is_finite(float(session.deadline)) or float(session.deadline)<0:return false
		if session.get("return_map")!="e603" or not session.get("return_cell") is Array or session.return_cell.size()!=2:return false
		for coordinate in session.return_cell:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or int(coordinate)!=coordinate or coordinate<0 or coordinate>4095:return false
	if not preload("res://scripts/edition2011/society_state.gd").valid(s,ITEMS):return false
	if not Story.valid(s):return false
	if s.has("quest_receipts"):
		if not s.quest_receipts is Dictionary or not s.get("quests") is Dictionary:return false
		for id in s.quest_receipts:
			var receipt=s.quest_receipts[id]
			if not receipt is Dictionary or receipt.get("version")!=1 or s.quests.get(id)!="done":return false
			for key in ["gold","xp","tokens"]:
				var value=receipt.get(key,0) if key=="tokens" else receipt.get(key)
				if not (value is int or value is float) or not is_finite(float(value)) or value<0 or int(value)!=value:return false
			for key in ["items","consumed"]:
				if not receipt.get(key) is Dictionary:return false
				for item in receipt[key]:
					var value=receipt[key][item]
					if not ITEMS.has(item) or not (value is int or value is float) or not is_finite(float(value)) or value<=0 or int(value)!=value:return false
	for key in ["gold","tokens","level","hp","mp","xp","time","inner","meridian","kills"]:
		if not s.has(key) or not (s[key] is float or s[key] is int) or not is_finite(float(s[key])) or float(s[key])<0:return false
	for key in ["inventory","warehouse","equipment","durability","quests","hero","skills","guild"]:
		if not s.get(key) is Dictionary:return false
	for key in ["visited","friends","party","cell"]:
		if not s.get(key) is Array:return false
	if not s.get("map") is String or s.get("preset") not in ["easy","classic"] or s.cell.size()!=2:return false
	if int(s.level)<1 or int(s.level)>100:return false
	for container in [s.inventory,s.warehouse]:
		for id in container:
			if not (container[id] is float or container[id] is int):return false
			if not ITEMS.has(id) or int(container[id])<0 or int(container[id])>9999 or float(container[id])!=int(container[id]):return false
	for value in s.cell:
		if not (value is float or value is int) or float(value)!=int(value) or int(value)<0 or int(value)>4095:return false
	for slot in s.equipment:
		if not ITEMS.has(s.equipment[slot]) or not EditionInventory.fits(s.equipment[slot],EditionInventory.SLOTS.find(slot)):return false
	for id in s.durability:
		if not ITEMS.has(id) or not (s.durability[id] is float or s.durability[id] is int) or int(s.durability[id])<0 or int(s.durability[id])>100:return false
	if s.has("novice"):
		if not s.novice is Dictionary or not s.novice.get("patrol") is bool:return false
		var count=s.novice.get("chickens")
		if not (count is int or count is float) or not is_finite(float(count)) or int(count)!=float(count) or count<0 or count>3:return false
	for id in ["nv_arrival","nv_equip","nv_hunt","nv_patrol"]:
		if s.quests.has(id) and (s.quests[id] not in ["accepted","done"] or not s.has("novice")):return false
	for key in ["assist","attributes","skill_keys","skill_ready"]:
		if s.has(key) and not s[key] is Dictionary:return false
	if s.has("stone_until") and (not (s.stone_until is int or s.stone_until is float) or not is_finite(float(s.stone_until)) or float(s.stone_until)<0):return false
	if s.has("green_poison"):
		if not s.green_poison is Dictionary:return false
		for key in ["until","next","power"]:
			var value=s.green_poison.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<=0:return false
	if s.has("special_monsters"):
		if not s.special_monsters is Dictionary:return false
		for id in s.special_monsters:
			var record=s.special_monsters[id]
			if not id is String or not record is Dictionary:return false
			if not record.get("spawn_id") is String or record.get("phase") not in ["hidden","emerging","exposed","receding"]:return false
			for field in ["hp","generation","last_attack","motion_time"]:
				var value=record.get(field)
				if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0:return false
	if s.has("ground_loot"):
		if not s.ground_loot is Array:return false
		var loot_ids: Dictionary={}
		for loot in s.ground_loot:
			if not loot is Dictionary or not loot.get("uid") is String or loot_ids.has(loot.uid):return false
			if not loot.get("map") is String or not loot.get("cell") is Array or loot.cell.size()!=2:return false
			if loot.get("type")!="gold" and not ITEMS.has(loot.get("type","")):return false
			if not (loot.get("count") is int or loot.get("count") is float) or loot.count<1 or float(loot.count)!=int(loot.count):return false
			if loot.has("purity"):
				var purity=loot.purity
				if int(ITEMS.get(loot.type,{}).get("std_mode",-1))!=43 or not (purity is int or purity is float) or not is_finite(float(purity)) or purity<0 or purity>100 or purity!=floor(float(purity)):return false
			loot_ids[loot.uid]=true
	if s.has("fire_dragon"):
		if not s.fire_dragon is Dictionary:return false
		var fd: Dictionary=s.fire_dragon
		var permits=fd.get("permits",0)
		if not (permits is int or permits is float) or permits<0 or not is_finite(float(permits)) or float(permits)!=int(permits):return false
		for key in ["active","surveyed","claimed"]:
			if fd.has(key) and not fd[key] is bool:return false
		if fd.has("deadline") and (not (fd.deadline is int or fd.deadline is float) or not is_finite(float(fd.deadline))):return false
	if s.has("death_due") and (not (s.death_due is int or s.death_due is float) or not is_finite(float(s.death_due))):return false
	if s.has("chat_log") and (not s.chat_log is Array or s.chat_log.size()>200):return false
	if s.has("chat_log"):
		for line in s.chat_log:
			if not line is String:return false
	if s.has("attack_mode") and not EditionCombat.MODES.has(s.attack_mode):return false
	if s.has("items") and not EditionInventory.validate(s):return false
	return true

func apply(next: Dictionary,action: String,token: String="") -> bool:
	if weight(next)>100+int(next.level)*5 and weight(next)>weight(state):message="背包负重不足";return false
	if not valid(next):message="物品数量、金币或负重不满足操作条件";return false
	if not EditionInventory.reconcile(next):message="背包或仓库没有空格";return false
	if not valid(next):message="物品数量、金币或负重不满足操作条件";return false
	if action in ["warehouse","inventory_move"] and int(state.hp)>0:
		var types: Dictionary=state.warehouse.duplicate()
		types.merge(next.warehouse)
		for type in types:
			var delta:=int(next.warehouse.get(type,0))-int(state.warehouse.get(type,0))
			var bag_delta:=int(next.inventory.get(type,0))-int(state.inventory.get(type,0))
			if delta!=0 and bag_delta==-delta:
				Story.observe(next,"warehouse",{"map":state.map,"item":type,"direction":"deposit" if delta>0 else "withdraw"})
	# End timed visits in the same transaction as leaving or dying. A later
	# frame must not be needed to prevent an old timer surviving a saved exit.
	if next.get("dark_temple",{}).get("active",false) and (next.map!="m001" or next.hp<=0):
		next.dark_temple=next.dark_temple.duplicate(true);next.dark_temple.active=false
	if next.get("cook_trial",{}).get("active",false) and (next.map!=next.cook_trial.map or next.hp<=0):
		next.cook_trial=next.cook_trial.duplicate(true);next.cook_trial.active=false
	if not store.commit(character.id,next,action,token):message=store.error;return false
	var previous:=state
	state=next
	for q in Story.data().quests:
		if previous.quests.get(q.id)!="accepted" or next.quests.get(q.id)!="accepted":continue
		for index in range(q.objectives.size()):
			var count:=Story.displayed_count(next,q,index)
			if count!=Story.displayed_count(previous,q,index):story_progressed.emit("任务「%s」：%s %d/%d"%[q.title,Story.displayed_label(next,q,index),count,Story.displayed_goal(q,index)])
	return true

static func item_sound(type: String) -> int:
	return EditionItemAudio.sound(type,"select")

func count_item(s: Dictionary,id: String,n: int,container: String="inventory") -> bool:
	var value:=int(s[container].get(id,0))+n
	if value<0:return false
	if value==0:s[container].erase(id)
	else:s[container][id]=value
	return true

func bind_medicine(npc_id: String,map_id: String,cell: Vector2i,bundle: String) -> bool:
	if not MEDICINE_BUNDLES.has(bundle):message="没有这项药水配方";return false
	return bind_bundle(npc_id,map_id,cell,bundle)

func bind_bundle(npc_id: String,map_id: String,cell: Vector2i,bundle: String) -> bool:
	var recipes:=MEDICINE_BUNDLES.merged(SCROLL_BUNDLES)
	if npc_id!="server:merchant:105" or not story_near(npc_id,map_id,cell):message="请到东方宫殿二楼商人身边捆扎";return false
	if not recipes.has(bundle):message="没有这项捆扎配方";return false
	var next:=state.duplicate(true)
	if next.gold<100:message="捆扎需要 100 金币";return false
	if not count_item(next,recipes[bundle],-6):message="背包中需要对应物品 ×6";return false
	next.gold-=100;count_item(next,bundle,1)
	Story.observe(next,"binding",{"npc":npc_id,"item":bundle})
	if not apply(next,"bind_medicine"):return false
	message="已捆扎 "+ITEMS[bundle].name+" ×1，花费 100 金币";return true

func exchange_gold_bar(npc_id: String,map_id: String,cell: Vector2i,to_bar: bool) -> bool:
	if npc_id!="server:merchant:105" or not story_near(npc_id,map_id,cell):message="请到东方宫殿二楼商人身边兑换";return false
	var next:=state.duplicate(true)
	if to_bar:
		if int(next.gold)<1002000:message="兑换金条需要 1002000 金币（含手续费）";return false
		next.gold-=1002000
		if not count_item(next,"ref:226",1):return false
	else:
		if int(next.gold)>4002000:message="兑换后金币不能超过 5000000";return false
		if not count_item(next,"ref:226",-1):message="背包中需要一根金条";return false
		next.gold+=998000
	if not apply(next,"gold_bar_exchange"):return false
	message="已兑换金条 ×1" if to_bar else "已兑回 998000 金币（已扣手续费）"
	return true

func shop(id: String,quantity: int,buy: bool=true) -> bool:
	if id=="ref:226" or MEDICINE_BUNDLES.has(id) or SCROLL_BUNDLES.has(id):message="金条和物品包请通过专门兑换或捆扎办理";return false
	if not ITEMS.has(id) or quantity<=0 or quantity>99:message="无效商品数量";return false
	if ITEMS[id].get("quest_material",false):message="任务凭证不能购买或出售，请按委托获取和交付";return false
	var next:=state.duplicate(true);var price:=int(ITEMS[id].price)*quantity
	if buy:
		if int(next.gold)<price:message="金币不足";return false
		next.gold-=price;count_item(next,id,quantity)
	else:
		if not count_item(next,id,-quantity):message="背包数量不足";return false
		price=int(price/2);next.gold+=price
	message=("购买 " if buy else "出售 ")+ITEMS[id].name+" ×%d，%s %d 金币"%[quantity,"花费" if buy else "获得",price]
	return apply(next,"buy" if buy else "sell")

func warehouse(id: String,deposit: bool) -> bool:
	if not ITEMS.has(id):message="未知物品";return false
	var next:=state.duplicate(true)
	if int(ITEMS[id].get("std_mode",-1))==43 or ITEMS[id].has("slot"):
		var error:=EditionInventory.transfer_one(next,id,"inventory" if deposit else "warehouse","warehouse" if deposit else "inventory")
		if not error.is_empty():message=error;return false
	else:
		if not count_item(next,id,-1,"inventory" if deposit else "warehouse"):message="没有该物品";return false
		count_item(next,id,1,"warehouse" if deposit else "inventory")
	message=("存入仓库：" if deposit else "取出仓库：")+ITEMS[id].name+" ×1"
	return apply(next,"warehouse")


func use_item(id: String) -> bool:
	if ITEMS.get(id,{}).get("crafting_material_only",false):message="此神水目前用于合成，饮用效果尚未接入，未消耗物品";return false
	for item in state.get("items",[]):
		if item.container=="inventory" and item.type==id:return inventory_action("use",{"uid":item.uid})
	message="背包中没有该物品";return false

static func material_bundle_text(type: String) -> String:
	var bundle: Dictionary=ITEMS.get(type,{}).get("material_bundle",{})
	if bundle.is_empty():return ""
	if SCROLL_BUNDLES.has(type):return "使用拆为回城卷 ×6，不会立即传送；单张回城卷返回边界村（单机规则）。"
	if MEDICINE_BUNDLES.has(type):return "使用拆为 %s ×6；药包不能直接恢复生命或法力。"%ITEMS[bundle.type].name
	return "使用拆为 %s ×%d（单机适配）；不同颜色暂共用施毒术效果。"%[ITEMS[bundle.type].name,int(bundle.count)]

func inventory_action(action: String,args: Dictionary,trapped_monsters=null) -> bool:
	if state.hp<=0:message="死亡状态不能操作物品";return false
	var original:=EditionInventory.find_item(state,str(args.get("uid",""))).duplicate(true)
	if action=="use" and ITEMS.get(original.get("type",""),{}).get("crafting_material_only",false):message="此神水目前用于合成，饮用效果尚未接入，未消耗物品";return false
	if action=="use" and original.get("type","")=="ref:135":return preload("res://scripts/edition2011/blessing_oil.gd").use(self,str(args.get("uid","")))
	if action=="use" and original.get("type","")=="ref:226":message="金条请到东方宫殿二楼商人处兑换";return false
	if not original.is_empty() and (action=="use" or args.get("container")=="equipment"):
		var spec: Dictionary=ITEMS[original.type]
		if spec.has("slot"):
			if spec.get("gender",character.gender)!=character.gender:message="这件装备的性别不符";return false
			var requirement:=int(spec.get("need",0));var required:=int(spec.get("need_level",0))
			var actual:=int(state.level) if requirement==0 else attack() if requirement==1 else equipment_bonus("magic") if requirement==2 else equipment_bonus("tao")
			if requirement not in [0,1,2,3] or actual<required:message="未达到装备需求："+str(required);return false
	if action=="use" and not original.is_empty() and ITEMS[original.type].has("skill_book"):
		return learn_book(original)
	if action=="use" and not original.is_empty() and ITEMS[original.type].has("material_bundle"):
		if original.container!="inventory":message="请先把物品放入背包";return false
		var bundle: Dictionary=ITEMS[original.type].material_bundle
		var unpacked:=state.duplicate(true)
		if not count_item(unpacked,original.type,-1) or not count_item(unpacked,bundle.type,int(bundle.count)):message="材料拆分失败";return false
		message="拆分 "+ITEMS[original.type].name+"，获得 "+ITEMS[bundle.type].name+" ×"+str(int(bundle.count))
		if not apply(unpacked,"unpack_spell_material"):return false
		item_performed.emit(original.type,"use");return true
	var next:=state.duplicate(true);EditionInventory.migrate(next)
	var error:=EditionInventory.operate(next,action,args)
	if not error.is_empty():message=error;return false
	EditionInventory.mirror(next)
	if trapped_monsters is Dictionary:next.trapped_monsters=trapped_monsters.duplicate(true)
	message="整理完成" if original.is_empty() else ({"use":"使用","move":"移动","split":"拆分","bind":"绑定快捷栏","drop":"丢弃"}.get(action,"操作")+"："+ITEMS[original.type].name)
	var changed: bool=next.items!=state.items
	if not apply(next,"inventory_"+action):return false
	if changed and not original.is_empty():
		var event:=action
		var result:=EditionInventory.find_item(state,original.uid)
		if result.get("container")=="equipment" and original.container!="equipment":event="equip"
		elif original.container=="equipment" and result.get("container")!="equipment":event="unequip"
		item_performed.emit(original.type,event)
	return true


func max_hp() -> int:return 100+int(state.get("level",1))*15+int(state.get("attributes",{}).get("vitality",0))*5
func max_mp() -> int:return 80+int(state.get("level",1))*8
func attack() -> int:
	return 5+int(state.level)*2+equipment_bonus("attack")+int(state.get("attributes",{}).get("strength",0))+passive_bonus("basic")+passive_bonus("slaying")

func attack_range() -> Vector2i:
	return preload("res://scripts/edition2011/weapon_damage.gd").bounds(state,attack()-equipment_bonus("attack"))

func roll_melee_damage() -> int:
	var Damage=preload("res://scripts/edition2011/weapon_damage.gd")
	return Damage.roll(attack_range(),Damage.luck(state))

func melee_accuracy() -> int:
	# Base 5 follows the reference actor; +2/rank is the local spirit skill baseline.
	var total:=5+passive_bonus("spirit")
	for item in state.get("items",[]):
		if item.container=="equipment" and int(item.durability)>0:total+=item_accuracy(item.type)
	return total

static func item_accuracy(type: String) -> int:
	var spec: Dictionary=ITEMS.get(type,{})
	if int(spec.get("std_mode",-1)) not in [5,6,20,24]:return 0
	return maxi(0,int(spec.get("raw",{}).get("acMax",0)))

func melee_hits(evasion: int) -> bool:
	return evasion<=0 or melee_accuracy()>=randi_range(0,evasion-1)

func equipment_bonus(key: String) -> int:
	var total:=0
	for item in state.get("items",[]):
		if item.container=="equipment" and int(item.durability)>0:total+=int(ITEMS[item.type].get(key,0))
	return total

func defense(seconds: float=-1) -> int:
	if seconds<0:seconds=float(state.get("time",0))
	return equipment_bonus("defense")+(8 if seconds<float(state.get("armor_until",0)) else 0)
func magic_defense_range(seconds: float) -> Vector2i:
	var bounds:=Vector2i.ZERO
	for item in state.get("items",[]):
		if item.container!="equipment" or int(item.durability)<=0:continue
		var raw: Dictionary=ITEMS[item.type].get("raw",{})
		bounds.x+=maxi(0,int(raw.get("mac",0)))
		bounds.y+=maxi(0,int(raw.get("macMax",0)))
	bounds.y=maxi(bounds.x,bounds.y)
	if seconds<float(state.get("ghostshield_until",0)):bounds+=Vector2i(8,8)
	return bounds

func incoming_monster_damage(amount: int,magic: bool,seconds: float) -> int:
	var mitigation:=defense(seconds)
	if magic:
		var bounds:=magic_defense_range(seconds)
		mitigation=randi_range(bounds.x,bounds.y)
	var scale:=0.5 if seconds<float(state.get("shield_until",0)) else 1.0
	return maxi(1,int((amount-mitigation)*scale))

func passive_bonus(id: String) -> int:
	if not state.skills.has(id) or not EditionSkills.DEFINITIONS.has(id) or character.job!=EditionSkills.DEFINITIONS[id].job:return 0
	var skill: Dictionary=EditionSkills.DEFINITIONS[id]
	if int(state.level)<int(skill.level):return 0
	return int(state.skills[id].get("rank",1))*(4 if id=="slaying" else 2)

func story_npc(id: String) -> Dictionary:
	if id=="border:elder":return {"id":id,"map":"0","cell":[287,618],"name":"边界村长"}
	for npc in EditionRegion.data().npcs:
		if npc.id==id and npc.enabled:return npc
	return {}

func story_near(npc_id: String,map_id: String,cell: Vector2i) -> bool:
	var npc:=story_npc(npc_id)
	return state.hp>0 and not npc.is_empty() and npc.map==map_id and (cell-Vector2i(npc.cell[0],npc.cell[1])).length()<=4

func story_talk(npc_id: String,map_id: String,cell: Vector2i) -> bool:
	if not story_near(npc_id,map_id,cell):return false
	var next:=state.duplicate(true)
	var changed: bool=Story.observe(next,"talk",{"npc":npc_id})
	changed=Story.observe(next,"visit",{"map":map_id}) or changed
	if not changed:return true
	message="任务见闻已记录";return apply(next,"story_talk")

func story_reward_items(q: Dictionary) -> Dictionary:
	var items: Dictionary=q.rewards.items.duplicate(true)
	if q.rewards.has("books_by_job"):
		var id: String=q.rewards.books_by_job.get(character.job,"")
		if id.is_empty() or not ITEMS.has(id) or not ITEMS[id].has("skill_book"):return {}
		if EditionSkills.DEFINITIONS.get(ITEMS[id].skill_book,{}).get("job","")!=character.job:return {}
		items[id]=int(items.get(id,0))+1
	if q.rewards.has("equipment_by_job"):
		var id: String=q.rewards.equipment_by_job.get(character.job,"")
		if id.is_empty() or not ITEMS.has(id) or not ITEMS[id].has("slot"):return {}
		items[id]=int(items.get(id,0))+1
	return items

static func story_reward_label(id: String,count: int) -> String:
	var item: Dictionary=ITEMS.get(id,{})
	var label: String=str(item.get("name",id))+" ×"+str(count)
	if item.has("skill_book"):
		var skill: Dictionary=EditionSkills.DEFINITIONS.get(item.skill_book,{})
		label+=" · %s %d 级学习"%[skill.get("job",""),int(skill.get("level",0))]
	return label

func track_story(id: String) -> bool:
	if not id.is_empty() and (Story.quest(id).is_empty() or state.quests.get(id)!="accepted"):message="只能追踪已接受且未交付的故事任务";return false
	var next:=state.duplicate(true);next.tracked_story=id
	message="已取消故事任务追踪" if id.is_empty() else "追踪任务："+str(Story.quest(id).title)
	return apply(next,"track_story")

func abandon_story(id: String) -> bool:
	if state.hp<=0:message="死亡状态不能放弃任务";return false
	if Story.quest(id).is_empty() or state.quests.get(id)!="accepted":message="只能放弃尚未交付的故事任务";return false
	var next:=state.duplicate(true);next.quests.erase(id)
	if next.has("story_progress"):next.story_progress.erase(id)
	if next.get("tracked_story","")==id:next.tracked_story=""
	message="已放弃："+str(Story.quest(id).title)+"；物品保留，可回原人物处重新接取。"
	return apply(next,"abandon_story")

func quest_reward_text(gold: int,xp: int) -> String:
	var easy: bool=state.preset=="easy"
	return "金币 %d · 经验 %d"%[gold*(2 if easy else 1),xp*(3 if easy else 1)]

func record_quest_receipt(next: Dictionary,id: String,gold: int,xp: int,items: Dictionary,consumed: Dictionary,tokens: int=0) -> void:
	if not next.has("quest_receipts"):next.quest_receipts={}
	next.quest_receipts[id]={"version":1,"gold":gold*(2 if next.preset=="easy" else 1),"xp":xp*(3 if next.preset=="easy" else 1),"items":items.duplicate(true),"consumed":consumed.duplicate(true)}
	if tokens>0:next.quest_receipts[id]["tokens"]=tokens
func quest_receipt_text(id: String,data: Dictionary={}) -> String:
	var receipt: Dictionary=(state if data.is_empty() else data).get("quest_receipts",{}).get(id,{})
	if receipt.is_empty():return "旧任务未保存交付明细；不补记或重新发放奖励。"
	var awarded: PackedStringArray=["金币 %d"%receipt.gold,"经验 %d"%receipt.xp]
	for item in receipt.items:awarded.append(str(ITEMS[item].name)+" ×"+str(int(receipt.items[item])))
	if int(receipt.get("tokens",0))>0:awarded.append("探索徽记 ×"+str(int(receipt.tokens)))
	if int(receipt.get("guild_contribution",0))>0:awarded.append("行会贡献 %d"%int(receipt.guild_contribution))
	var used: PackedStringArray=[]
	for item in receipt.consumed:used.append(str(ITEMS[item].name)+" ×"+str(int(receipt.consumed[item])))
	return "实际获得："+"、".join(awarded)+("；交付消耗："+"、".join(used) if not used.is_empty() else "")

func story_guild_reward_text(q: Dictionary) -> String:
	if not q.has("guild_delivery"):return ""
	return "行会贡献：%d（不随档位翻倍）\n交付材料进入行会储备；红药可主动救助附近同行成员，蓝药可为本角色恢复法力。"%int(q.guild_delivery.contribution)

func story_materials_text(q: Dictionary,seconds: float=-1) -> String:
	if state.quests.get(q.id)=="done":return ""
	var lines: PackedStringArray=[]
	var totals:=Story.collection_requirements(q)
	for item in totals:
		var owned:=int(state.inventory.get(item,0));var needed:=int(totals[item])
		lines.append("%s ×%d（背包 %d，还差 %d）"%[ITEMS[item].name,needed,owned,maxi(0,needed-owned)])
		var stored:=int(state.warehouse.get(item,0))
		if stored>0 and owned<needed:
			var retrieve:=mini(stored,needed-owned)
			lines.append("仓库有 %d，可先取回 %d；取回后仍需获得 %d。"%[stored,retrieve,maxi(0,needed-owned-stored)])
	if totals.has("ore") and q.id=="story_dragon_forge":
		lines.append("铁矿可向比奇铁匠铺老板购买（单机补建供货）；每块 %d 金币，每批20块、游戏运行10分钟补货。先备足金币和背包空位，再提交换装。"%int(ITEMS.ore.price))
	if totals.has("dragon_story_scale") and q.id in ["story_dragon_trial","story_dragon_forge"]:
		lines.append("鳞片只统计背包中的数量；存入仓库后请先取回。未拾取的鳞片会留在神殿，返城或重进游戏后仍可再次凭证入殿，使用“寻找地面物品”找回，无需重新击杀。委托未交付时，也可再次击败火龙教主并拾取新的鳞片，已记录的击杀不会清零。")
	var text: String="" if lines.is_empty() else "交付将消耗：\n"+"\n".join(lines)+"\n只统计背包；交付前卖出、使用或存入仓库会减少可用数量。"
	for index in range(q.objectives.size()):
		var objective: Dictionary=q.objectives[index]
		if objective.type!="warehouse" or Story.progress(state,q,index)>=int(objective.count):continue
		var item: String=objective.item
		var bag:=int(state.inventory.get(item,0));var stored:=int(state.warehouse.get(item,0))
		var preparation: String="存取准备：%s · 背包 %d · 仓库 %d\n"%[ITEMS[item].name,bag,stored]
		if objective.direction=="deposit":
			if bag>0:preparation+="下一步：到指定仓库存入此物品。"
			elif stored>0:preparation+="背包没有此物品，可先从仓库取回，再到指定仓库存入；提前取出旧物不代替后续取回步骤。"
			else:preparation+="背包和仓库都没有此物品，请先获得后再办理存入。"
		else:
			preparation+="下一步：在指定仓库取回此物品。" if stored>0 else "仓库没有此物品，请先补入再取回；已完成的存入记录保留。"
		preparation+="\n办理人物："+str(story_npc(objective.npc).get("name","指定保管员"))+"。查看提示不会自动存取。"
		text+=("\n\n" if not text.is_empty() else "")+preparation
		break
	for index in range(q.objectives.size()):
		var objective: Dictionary=q.objectives[index]
		if objective.type!="craft" or objective.get("npc","")!="server:merchant:109" or Story.progress(state,q,index)>=int(objective.count):continue
		text+=("\n\n" if not text.is_empty() else "")+"制作准备（成男制作时消耗，任务交付不再扣取）：\n"+preload("res://scripts/edition2011/mystery_books.gd").material_summary(state,character.job)
		text+="\n高纯度金矿需采矿后拾取；金条可向东方宫殿二楼商人兑换，1002000金币一根。仓库材料请先取回。"
	for index in range(q.objectives.size()):
		var objective: Dictionary=q.objectives[index]
		if objective.type!="mine" or Story.progress(state,q,index)>=int(objective.count):continue
		var preparation: String="采矿准备："
		if int(state.level)<22:preparation+="需要达到22级才能装备鹤嘴锄（当前%d级）。"%int(state.level)
		elif state.equipment.get("weapon","")=="ref:87":
			var tools: Array=state.items.filter(func(item):return item.container=="equipment" and item.type=="ref:87")
			if tools.is_empty() or int(tools[0].durability)<=0:preparation+="鹤嘴锄已损坏，请回比奇铁匠处修理。"
			else:preparation+="已装备鹤嘴锄，剩余耐久%d。"%int(tools[0].durability)
		elif int(state.inventory.get("ref:87",0))>0:preparation+="鹤嘴锄在背包中，请先装备。"
		elif int(state.warehouse.get("ref:87",0))>0:preparation+="鹤嘴锄在仓库中，请取回并装备。"
		else:preparation+="请向比奇铁匠购买鹤嘴锄并装备。"
		preparation+="\n抵达矿壁后面向提示方向挥镐；成功挖出矿石才增加任务进度，购买或拾取不重复计数。交付不会收走挖出的矿石。"
		text+=("\n\n" if not text.is_empty() else "")+preparation
		break
	var purchases: Dictionary={}
	for index in range(q.objectives.size()):
		var objective: Dictionary=q.objectives[index]
		if objective.type!="purchase":continue
		var remaining:=maxi(0,int(objective.count)-Story.progress(state,q,index))
		if remaining==0:continue
		var key: String=objective.npc+":"+objective.item
		if not purchases.has(key):purchases[key]={"npc":objective.npc,"item":objective.item,"count":remaining}
		else:purchases[key].count=maxi(int(purchases[key].count),remaining)
	if not purchases.is_empty():
		var budget:=0;var complete:=true;var shopping: PackedStringArray=["尚需购买："]
		for row in purchases.values():
			var shop:=EditionRegion.shop(row.npc);var spec: Dictionary=ITEMS.get(row.item,{})
			if shop.is_empty() or spec.is_empty() or not shop.goods.any(func(g):return g.type==row.item):
				shopping.append("商品或指定商店未接入，无法计算费用");complete=false;continue
			var price:=maxi(1,int(spec.price)*int(shop.price_rate)/100)
			budget+=price*int(row.count)
			var goods: Dictionary=shop.goods.filter(func(g):return g.type==row.item)[0]
			var now: float=float(state.get("time",0)) if seconds<0 else seconds
			var stock: Dictionary=state.get("merchant_stock",{}).get(str(row.npc)+":"+str(row.item),{"count":int(goods.count),"at":now})
			var due: float=float(stock.at)+float(goods.restock_seconds)
			var available: int=int(goods.count) if now>=due else int(stock.count)
			var wait_seconds:=maxi(0,int(ceil(due-now)))

			shopping.append("%s ×%d · 单价 %d 金币 · %s"%[spec.name,row.count,price,story_npc(row.npc).get("name","指定商人")])
			shopping.append("当前库存 %d"%available+(" · 约 %d 秒游戏时间后补货"%wait_seconds if available<int(row.count) else ""))
		if complete:shopping.append("预计合计 %d 金币 · 当前 %d · 还缺 %d。"%[budget,state.gold,maxi(0,budget-int(state.gold))])
		shopping.append("须在指定商店购买，已有物品不算购买记录；库存与实际扣费以办理时为准。")
		text+=("\n\n" if not text.is_empty() else "")+"\n".join(shopping)
	return text

func story_action(id: String,operation: String,npc_id: String,map_id: String,cell: Vector2i) -> bool:
	var q: Dictionary=Story.quest(id)
	if q.is_empty() or operation not in ["accept","submit"]:message="任务或操作不存在";return false
	if not story_near(npc_id,map_id,cell):message="请回到任务人物身边";return false
	if npc_id!=(q.start_npc if operation=="accept" else q.end_npc):message="这位人物不办理此任务";return false
	if q.has("jobs") and character.job not in q.jobs:message="此委托限定职业："+"、".join(q.jobs);return false
	if not Story.available(state,q):message="请先完成前置委托";return false
	var next:=state.duplicate(true)
	if operation=="accept":
		if next.quests.has(id):message="此任务已接受或已完成";return false
		next.quests[id]="accepted";next.story_job=character.job
		if Story.tracked(next).is_empty():next.tracked_story=id
		message="接受任务："+q.title
		return apply(next,"story_accept")
	if not Story.ready(next,q):message="任务尚未完成，或奖励已经领取";return false
	for objective in q.objectives:
		if objective.type=="collect" and not count_item(next,objective.item,-int(objective.count)):message="交付物品不足";return false
	var consumed: Dictionary={}
	for objective in q.objectives:
		if objective.type=="collect":consumed[objective.item]=int(consumed.get(objective.item,0))+int(objective.count)
	if q.has("guild_delivery"):
		if next.guild.is_empty():message="请先加入行会，再交付行会补给";return false
		if not next.guild.has("supplies"):next.guild.supplies={}
		for item in consumed:next.guild.supplies[item]=int(next.guild.supplies.get(item,0))+int(consumed[item])
		next.guild.contribution=int(next.guild.get("contribution",0))+int(q.guild_delivery.contribution)
	var rewards:=story_reward_items(q)
	if (q.rewards.has("books_by_job") or q.rewards.has("equipment_by_job")) and rewards.is_empty():message="本职业奖励配置缺失，未交付任务";return false
	for type in rewards:count_item(next,type,int(rewards[type]))
	next.gold+=int(q.rewards.gold)*(2 if next.preset=="easy" else 1);add_xp(next,int(q.rewards.xp));next.quests[id]="done"
	if next.get("tracked_story","")==id:next.tracked_story=""
	record_quest_receipt(next,id,int(q.rewards.gold),int(q.rewards.xp),rewards,consumed)
	if q.has("guild_delivery"):
		next.quest_receipts[id]["guild_contribution"]=int(q.guild_delivery.contribution)
		next.quest_receipts[id]["guild_supplies"]=consumed.duplicate(true)
	message="完成任务："+q.title+" · "+quest_receipt_text(id,next)+" · "+q.completion
	if not apply(next,"story_submit",character.id+":"+id):return false
	append_unlocked_quests(id)
	return true

func append_unlocked_quests(id: String) -> void:
	var unlocked: PackedStringArray=[]
	for candidate in Story.data().quests:
		if id not in candidate.requires or state.quests.has(candidate.id):continue
		if candidate.has("jobs") and character.job not in candidate.jobs:continue
		if not Story.available(state,candidate):continue
		var giver: Dictionary=story_npc(candidate.start_npc)
		unlocked.append(str(candidate.title)+"（找"+str(giver.get("name","任务人物"))+"）")
	for candidate in EditionVillage.quests():
		if candidate.previous==id and not state.quests.has(candidate.id) and EditionVillage.available(state,candidate):
			unlocked.append(str(candidate.title)+"（找边界村长）")
	if not unlocked.is_empty():message+="\n新委托："+"；".join(unlocked)

func novice_quest(id: String) -> bool:
	if state.hp<=0:message="死亡期间不能办理委托或领取探索奖励";return false
	var q:=EditionVillage.quest(id)
	if q.is_empty() or not EditionVillage.available(state,q):message="请先完成前一个新手任务";return false
	if state.quests.get(id)=="done":message="这份奖励已经领取";return false
	var next:=state.duplicate(true)
	if not next.quests.has(id):
		next.quests[id]="accepted"
		if not next.has("novice"):next.novice={"chickens":0,"patrol":false}
		message="已接受："+q.title;return apply(next,"novice_accept")
	if not EditionVillage.ready(next,id):message=EditionVillage.progress(next,q);return false
	if id=="nv_hunt":count_item(next,"chicken_meat",-3)
	var rewards:=novice_reward_items(q)
	for item in rewards:
		if not ITEMS.has(item) or ITEMS[item].get("gender",character.gender)!=character.gender:message="新手奖励装备配置不符，未交付任务";return false
		count_item(next,item,int(rewards[item]))
	if id=="nv_arrival":next.novice_clothing_version=1
	next.gold+=int(q.gold)*(2 if next.preset=="easy" else 1);add_xp(next,int(q.xp));next.quests[id]="done"
	record_quest_receipt(next,id,int(q.gold),int(q.xp),rewards,{"chicken_meat":3} if id=="nv_hunt" else {})
	message="完成："+q.title+" · "+quest_receipt_text(id,next)
	if not apply(next,"novice_complete",character.id+":"+id):return false
	append_unlocked_quests(id)
	return true

func novice_patrol(map_id: String,cell: Vector2i) -> bool:
	if map_id!="0" or (cell-EditionVillage.PATROL).length()>2 or state.quests.get("nv_patrol")!="accepted" or state.get("novice",{}).get("patrol",false):return false
	var next:=state.duplicate(true);next.novice.patrol=true
	message="已到达村外小路，返回村长领取奖励";return apply(next,"novice_patrol")

func revive_after_wait(cell: Vector2i,seconds: float,trapped_monsters: Dictionary) -> bool:
	if state.hp>0 or not state.has("death_due") or not is_finite(seconds) or seconds<float(state.death_due):message="死亡等待尚未结束";return false
	var next:=state.duplicate(true);next.map="0";next.cell=[cell.x,cell.y];next.time=seconds
	next.hp=max_hp();next.mp=max_mp();next.erase("death_due");next.erase("green_poison");next.erase("stone_until")
	next.trapped_monsters=trapped_monsters.duplicate(true)
	message="已在边界村苏醒，装备与物品保留。"
	return apply(next,"death_return")

func recover_at_village() -> bool:
	var next:=state.duplicate(true);next.hp=max_hp();next.mp=max_mp();next.erase("death_due");next.erase("green_poison");next.erase("stone_until")
	message="村长为你恢复了生命与魔法";return apply(next,"village_recover")

func repair() -> bool:
	var next:=state.duplicate(true);var cost:=0
	for item in next.items:
		if item.container=="equipment":cost+=100-int(item.durability)
	if int(next.gold)<cost:message="修理需要 %d 金币"%cost;return false
	next.gold-=cost
	for id in next.durability:next.durability[id]=100
	for item in next.get("items",[]):
		if item.container=="equipment":item.durability=100
	message="装备已修理，花费 %d 金币"%cost;return apply(next,"repair")

func add_xp(next: Dictionary,base: int) -> void:
	next.xp+=base*(3 if next.preset=="easy" else 1)
	while next.level<100 and next.xp>=int(next.level)*100:
		next.xp-=int(next.level)*100;next.level+=1

func finish_cook_trial(map_id: String,cell: Vector2i) -> bool:
	if not story_near("server:merchant:50",map_id,cell) or state.hp<=0:message="请回到沃玛森林老人身边交付";return false
	var session: Dictionary=state.get("cook_trial",{})
	if not preload("res://scripts/edition2011/cook_trial_state.gd").valid(session) or session.active or not session.won or not session.get("picked",false) or session.claimed:message="需要本次考验的胜利与拾取记录，且不能重复交付";return false
	if int(state.inventory.get("ref:218",0))<1:message="请把考验头盔放在背包中，装备和仓库里的物品不能直接交付";return false
	var next:=state.duplicate(true);count_item(next,"ref:218",-1);next.cook_trial.claimed=true
	message="头盔已交付，老人答应协助料理；下一步回朴铁匠处询问特殊油"
	return apply(next,"cook_trial_claim","cook-claim:"+str(session.id))

func reset_cook_trial(map_id: String,cell: Vector2i) -> bool:
	if not story_near("server:merchant:50",map_id,cell) or state.hp<=0:message="请回到沃玛森林老人身边重试";return false
	var session: Dictionary=state.get("cook_trial",{})
	if session.is_empty() or session.get("active",false) or session.get("claimed",false):message="当前考验仍在进行或已经交付";return false
	var next:=state.duplicate(true)
	next.ground_loot=next.get("ground_loot",[]).filter(func(loot):return loot.uid!=session.get("proof_uid",""))
	next.erase("cook_trial")
	message="已放弃本次未交付战果，可以重新挑战；背包物品保留"
	return apply(next,"cook_trial_reset")

func reward_kill(token: String,species: String="",monster: Dictionary={},seconds:=0.0) -> bool:
	if monster.has("cook_attempt"):
		var victory: Dictionary=preload("res://scripts/edition2011/cook_trial_state.gd").victory(state.get("cook_trial",{}),str(monster.cook_attempt),str(monster.get("map",state.map)),str(monster.get("reference_name","")),seconds,state.hp>0)
		if victory.is_empty() or state.map!=victory.map:message="本次考验战果无效、已结算或已经超时";return false
		var trial_next:=state.duplicate(true);trial_next.cook_trial=victory;trial_next.kills+=1
		add_xp(trial_next,int(monster.get("exp",0)))
		add_ground(trial_next,monster,"ref:218",1)
		trial_next.cook_trial.proof_uid=trial_next.ground_loot.back().uid;trial_next.cook_trial.picked=false
		if not trial_next.has("regional_deaths"):trial_next.regional_deaths={}
		trial_next.regional_deaths[monster.id]=seconds+3600.0;trial_next.time=seconds
		message="考验战果已记录，头盔落在地面，请在离开前拾取"
		return apply(trial_next,"cook_trial_kill",token)
	var next:=state.duplicate(true);next.kills+=1
	Story.observe(next,"kill",{"name":monster.get("reference_name",monster.get("name","")),"map":monster.get("map",state.map)})
	if monster.has("spawn_id"):
		if not next.has("regional_deaths"):next.regional_deaths={}
		if float(next.regional_deaths.get(monster.id,0))>seconds:message="此怪物已经结算";return false
		next.regional_deaths[monster.id]=EditionRegion.next_refresh(seconds,float(monster.respawn_seconds))
		next.time=seconds
		add_xp(next,int(monster.exp))
		for trial in range(2 if next.preset=="easy" else 1):
			for drop in monster.get("drops",[]):
				var denominator:=int(str(drop.get("prob","1/0")).get_slice("/",1))
				if denominator<=0:continue
				# Gold uses its amount multiplier; guaranteed drops are never rerolled.
				if trial>0 and (denominator==1 or drop.name=="金币"):continue
				if randi_range(1,denominator)!=1:continue
				var count:=int(drop.get("count",1))
				if drop.name=="金币":add_ground(next,monster,"gold",count*(2 if next.preset=="easy" else 1));continue
				for id in ITEMS:
					if ITEMS[id].name==drop.name:add_ground(next,monster,id,count);break
		if species=="village_chicken" and next.quests.get("nv_hunt")=="accepted":
			add_ground(next,monster,"chicken_meat",1);next.novice.chickens=mini(3,int(next.novice.chickens)+1)
		if monster.get("map",state.map)==EditionFireDragon.MAP and monster.get("reference_name",monster.name)=="火龙教主" and (next.quests.get("story_dragon_trial")=="accepted" or next.quests.get("story_dragon_forge")=="accepted"):
			add_ground(next,monster,"dragon_story_scale",1)
		message="击败"+str(monster.name)+"，获得经验，物品掉落在地面";return apply(next,"regional_kill",token)
	if species=="village_chicken":
		add_xp(next,9);add_ground(next,monster,"gold",3*(2 if next.preset=="easy" else 1));add_ground(next,monster,"chicken_meat",1)
		if next.quests.get("nv_hunt")=="accepted":next.novice.chickens=mini(3,int(next.novice.chickens)+1)
		message="获得经验，鸡肉和金币掉落在地面";return apply(next,"village_chicken",token)
	add_xp(next,20);add_ground(next,monster,"gold",20*(2 if next.preset=="easy" else 1))
	# Two independent ordinary-drop trials. Quest and guaranteed rewards are separate.
	for _i in range(2 if next.preset=="easy" else 1):
		if randf()<0.35:add_ground(next,monster,"ore",1)
	message="击败怪物，获得经验，战利品掉落在地面";return apply(next,"kill",token)

func exploration(map_id: String) -> bool:
	if state.hp<=0:message="死亡期间不能办理委托或领取探索奖励";return false
	var next:=state.duplicate(true)
	if map_id in next.visited:message="这个区域已完成勘察";return false
	next.visited.append(map_id);next.tokens+=1;add_xp(next,30)
	message="勘察完成：经验与 1 枚探索徽记";return apply(next,"explore","explore:"+character.id+":"+map_id)

func quest(map_id: String) -> bool:
	if state.hp<=0:message="死亡期间不能办理委托或领取探索奖励";return false
	var next:=state.duplicate(true);var key:="ore:"+map_id
	if next.quests.get(key)=="done":message="本区委托已经完成 · "+quest_receipt_text(key);return false
	if not next.quests.has(key):next.quests[key]="accepted";message="已接受：向本区向导交付 3 块铁矿";return apply(next,"accept_quest")
	if not count_item(next,"ore",-3):message="需要 3 块铁矿";return false
	next.quests[key]="done";next.tokens+=3;next.gold+=100*(2 if next.preset=="easy" else 1);add_xp(next,60)
	record_quest_receipt(next,key,100,60,{}, {"ore":3},3)
	message="区域委托完成 · "+quest_receipt_text(key,next);return apply(next,"complete_quest",character.id+":"+key)

func set_guild_announcement(text: String) -> bool:
	if state.hp<=0:message="死亡状态不能修改行会公告";return false
	if state.guild.is_empty():message="请先成立本地行会";return false
	var announcement:=text.strip_edges()
	if announcement.is_empty() or announcement.length()>200:message="公告需要1至200个字符";return false
	for i in range(announcement.length()):
		var code:=announcement.unicode_at(i)
		if (code<32 and code!=10) or code==127:message="公告含有不支持的控制字符";return false
	if state.guild.get("announcement","")==announcement:message="公告内容没有变化";return false
	var next:=state.duplicate(true);next.guild.announcement=announcement
	message="本地行会公告已保存"
	return apply(next,"guild_announcement")

func create_guild(guild_name: String,companion: String) -> bool:
	if state.hp<=0:message="死亡状态不能成立行会";return false
	if not state.guild.is_empty():message="已经加入行会，不能重复登记";return false
	var title:=guild_name.strip_edges()
	if title.length()<2 or title.length()>12:message="行会名称需要2至12个字符";return false
	for i in range(title.length()):
		if title.unicode_at(i)<32 or title.unicode_at(i)==127:message="行会名称不能包含控制字符";return false
	if companion not in ["云游客","青禾","远山","轻舟"]:message="请选择可登记的本地旅人";return false
	var next:=state.duplicate(true)
	var members: Array=[character.name]
	if companion not in members:members.append(companion)
	next.guild={"name":title,"members":members,"contribution":0}
	message="已成立本地行会："+title
	return apply(next,"social_guild")

func social(kind: String,name: String) -> bool:
	if state.hp<=0:message="死亡状态不能修改旅人关系或成立行会";return false
	var next:=state.duplicate(true)
	if kind in ["friends","party"]:
		if name in next[kind]:next[kind].erase(name);message="已移除 "+name
		else:
			if kind=="party" and next.party.size()>=4:message="队伍已满";return false
			next[kind].append(name);message="已加入 "+name
	elif kind=="guild_member":
		if next.guild.is_empty():message="请先成立本地行会";return false
		if name in next.guild.get("members",[]):message="这位旅人已经在行会中";return false
		if name not in ["云游客","青禾","远山","轻舟"]:message="未找到可邀请的本地旅人";return false
		if not next.guild.has("members"):next.guild.members=[character.name]
		next.guild.members.append(name);message="已邀请 "+name+" 加入本地行会"
	elif kind=="guild":
		return create_guild("玛法旅人会",name)
	else:return false
	return apply(next,"social_"+kind)

func tick_traveler_poison(seconds: float) -> bool:
	var due:=false
	for health in state.get("traveler_health",{}).values():
		var poison: Dictionary=health.get("green_poison",{})
		if int(health.get("hp",0))>0 and not poison.is_empty() and (seconds>=float(poison.next) or seconds>=float(poison.until)):due=true;break
	if not due:return false
	var next:=state.duplicate(true);var notices: Array[String]=[]
	for id in next.get("traveler_health",{}):
		var health: Dictionary=next.traveler_health[id]
		var poison: Dictionary=health.get("green_poison",{})
		if poison.is_empty() or int(health.get("hp",0))<=0:continue
		if seconds<float(poison.next) and seconds<float(poison.until):continue
		var ticks:=maxi(0,int(floor(minf(seconds,float(poison.until)-0.0000001)-float(poison.next)))+1)
		var damage:=ticks*int(poison.power)
		health.hp=maxi(0,int(health.hp)-damage)
		if health.hp<=0:
			health.generation=int(health.get("generation",0))+1;health.respawn=seconds+30
		if health.hp<=0 or seconds>=float(poison.until):health.erase("green_poison")
		else:health.green_poison.next=float(poison.next)+ticks
		notices.append("%s：绿毒伤害%d%s"%[str(health.get("name",id)),damage,"，倒下后30秒恢复" if health.hp<=0 else ""])
	if notices.is_empty():return false
	next.time=maxf(float(next.time),seconds);message="；".join(notices)
	return apply(next,"traveler_poison_tick")

func recover_travelers(ids: Array,now: float) -> bool:
	if not is_finite(now) or now<0:return false
	var due: Array=ids.filter(func(id):
		var health: Dictionary=state.get("traveler_health",{}).get(id,{})
		return not health.is_empty() and int(health.get("hp",250))<=0 and now>=float(health.get("respawn",0)))
	if due.is_empty():return true
	var next:=state.duplicate(true);var changed:=false
	for id in due:
		var health: Dictionary=next.get("traveler_health",{}).get(id,{})
		if health.is_empty() or int(health.get("hp",250))>0 or now<float(health.get("respawn",0)):continue
		health.hp=250;health.respawn=0;health.erase("green_poison");changed=true
	if not changed:return true
	next.time=maxf(float(next.time),now)
	message="倒下的旅人已经恢复行动"
	return apply(next,"traveler_recovery")

func guild_mana() -> bool:
	if state.hp<=0:message="死亡状态不能领取行会补给";return false
	if state.guild.is_empty() or character.name not in state.guild.get("members",[]):message="只有本行会成员可以使用储备";return false
	var restored:=mini(int(ITEMS.mana.mana),max_mp()-int(state.mp))
	if restored<=0:message="法力已满，无需使用行会蓝药";return false
	if int(state.guild.get("supplies",{}).get("mana",0))<1:message="行会储备没有魔法药";return false
	var next:=state.duplicate(true);next.guild.supplies.mana-=1
	if next.guild.supplies.mana==0:next.guild.supplies.erase("mana")
	next.mp+=restored
	if not next.guild.has("aid_log"):next.guild.aid_log=[]
	next.guild.aid_log.append({"member":character.name,"entity":character.id,"map":state.map,"item":"mana","count":1,"healed":restored,"resource":"mp"})
	if next.guild.aid_log.size()>100:next.guild.aid_log.pop_front()
	message="行会补给：恢复 %d 点法力，消耗储备魔法药 ×1"%restored
	return apply(next,"guild_mana")

func guild_aid(target: Dictionary,map_id: String,cell: Vector2i) -> bool:
	if state.hp<=0 or target.get("kind","")!="traveler":message="当前无法为旅人补给";return false
	if state.map!=map_id or Vector2i(target.cell[0],target.cell[1]).distance_to(cell)>4:message="请走到同行成员身边";return false
	if target.name not in state.party or target.name not in state.guild.get("members",[]):message="只能补给同队的行会成员";return false
	var health: Dictionary=state.get("traveler_health",{}).get(target.id,{"hp":250,"generation":0,"respawn":0})
	var hp:=int(health.get("hp",250))
	if hp<=0 or hp>=250:message="成员已倒下或不需要恢复生命";return false
	if int(state.guild.get("supplies",{}).get("potion",0))<1:message="行会储备没有金创药";return false
	var next:=state.duplicate(true)
	next.guild.supplies.potion-=1
	if next.guild.supplies.potion==0:next.guild.supplies.erase("potion")
	next.traveler_health[target.id]=health.duplicate(true)
	var healed:=mini(int(ITEMS.potion.heal),250-hp)
	next.traveler_health[target.id].hp=hp+healed
	if not next.guild.has("aid_log"):next.guild.aid_log=[]
	next.guild.aid_log.append({"member":target.name,"entity":target.id,"map":map_id,"item":"potion","count":1,"healed":healed})
	if next.guild.aid_log.size()>100:next.guild.aid_log.pop_front()
	message="行会补给：%s 恢复 %d 点生命，消耗储备金创药 ×1"%[target.name,healed]
	return apply(next,"guild_aid")

func train(system: String) -> bool:
	if system not in ["inner","meridian"]:return false
	var next:=state.duplicate(true);var cost:=(int(next[system])+1)*2
	if int(next.tokens)<cost:message="需要 %d 枚探索徽记"%cost;return false
	next.tokens-=cost;next[system]+=1;message="修炼完成";return apply(next,"train_"+system)

func story_arrival(map_id: String) -> bool:
	if state.hp<=0:return true
	var next:=state.duplicate(true)
	if not Story.observe(next,"visit",{"map":map_id,"arrival":true}):return true
	message="已记录任务目的地到达"
	return apply(next,"story_arrival")

func save_location(map_id: String,cell: Vector2i,seconds: float,chat_log=null,arrived:=false,special_monsters: Dictionary={},cook_monster: Dictionary={},trapped_monsters=null) -> bool:
	var next:=state.duplicate(true);next.map=map_id;next.cell=[cell.x,cell.y];next.time=seconds
	if trapped_monsters is Dictionary:next.trapped_monsters=trapped_monsters.duplicate(true)
	if not cook_monster.is_empty() and next.get("cook_trial",{}).get("active",false) and next.cook_trial.map==map_id:
		next.cook_trial=next.cook_trial.duplicate(true);next.cook_trial.monster=cook_monster.duplicate(true)
	if next.hp>0:Story.observe(next,"visit",{"map":map_id,"arrival":arrived})
	if chat_log is Array:next.chat_log=chat_log.slice(-200)
	if not special_monsters.is_empty():
		if not next.has("special_monsters"):next.special_monsters={}
		next.special_monsters.merge(special_monsters,true)
	return apply(next,"save_location")

func reference_trade(npc_id: String,id: String,buy: bool,seconds: float,uid: String="") -> bool:
	if npc_id=="server:merchant:126" and buy:message="桃源合成产物需要材料制作，不能直接购买";return false
	if id=="ref:226" or MEDICINE_BUNDLES.has(id) or SCROLL_BUNDLES.has(id):message="金条和物品包请通过专门兑换或捆扎办理";return false
	var shop:=EditionRegion.shop(npc_id)
	if shop.is_empty() or not ITEMS.has(id):message="商店或物品不存在";return false
	var spec: Dictionary=ITEMS[id];var next:=state.duplicate(true)
	var price:=maxi(1,int(spec.price)*int(shop.price_rate)/100)
	if buy:
		var rows: Array=shop.goods.filter(func(g):return g.type==id)
		if rows.is_empty():message="此商店不出售该物品";return false
		var row: Dictionary=rows[0]
		if spec.get("runtime_status","supported")!="supported":message="此商品的效果或素材尚未接入";return false
		if not next.has("merchant_stock"):next.merchant_stock={}
		var key:=npc_id+":"+id
		var stock: Dictionary=next.merchant_stock.get(key,{"count":int(row.count),"at":seconds})
		if seconds>=float(stock.at)+float(row.restock_seconds):stock={"count":int(row.count),"at":seconds}
		if int(stock.count)<=0:message="该商品暂时售罄";return false
		if next.gold<price:message="金币不足，需要 %d 金币"%price;return false
		stock.count-=1;next.merchant_stock[key]=stock;next.gold-=price;count_item(next,id,1)
		Story.observe(next,"purchase",{"npc":npc_id,"item":id})
	else:
		if not shop.accepted_modes.any(func(mode):return int(mode)==int(spec.get("std_mode",-1))):message="此商店不收购这类物品";return false
		var instances: Array=next.items.filter(func(i):return i.type==id and i.container=="inventory")
		if instances.is_empty():message="背包中没有该物品";return false
		if uid.is_empty() and int(spec.get("std_mode",-1))==43:message="请在商店选择具体纯度的矿石出售";return false
		var sold: Dictionary=instances.back() if uid.is_empty() else EditionInventory.find_item(next,uid)
		if sold.is_empty() or sold.type!=id or sold.container!="inventory":message="所选物品已变化，请重新选择";return false
		price=maxi(1,int(spec.price)/2*int(sold.durability)/100)
		sold.count-=1
		if int(sold.count)==0:next.items.erase(sold)
		EditionInventory.mirror(next)
		next.gold+=price
	message=("购买 " if buy else "出售 ")+spec.name+" ×1，%s %d 金币"%["花费" if buy else "获得",price];return apply(next,"reference_trade")

func reference_teleport(route: Dictionary,landing: Vector2i,seconds: float,arrived:=true,trapped_monsters=null) -> bool:
	if not route.get("enabled",false):message="传送路线未接入";return false
	if state.hp<=0 or int(state.level)<int(route.min_level):message="未达到传送等级要求";return false
	if state.gold<int(route.cost):message="金币不足，需要 %d 金币"%int(route.cost);return false
	var next:=state.duplicate(true)
	for item in route.get("item_costs",{}):
		if not ITEMS.has(item) or int(next.inventory.get(item,0))<int(route.item_costs[item]):message="传送需要："+str(ITEMS.get(item,{}).get("name",item))+" ×"+str(route.item_costs[item]);return false
		if not count_item(next,item,-int(route.item_costs[item])):return false
	next.gold-=int(route.cost);next.map=route.target_map;next.cell=[landing.x,landing.y];next.time=seconds
	if trapped_monsters is Dictionary:next.trapped_monsters=trapped_monsters.duplicate(true)
	if next.hp>0:Story.observe(next,"visit",{"map":route.target_map,"arrival":arrived})
	message="传送完成";return apply(next,"reference_teleport")

func reference_repair_quote(npc_id: String) -> Dictionary:
	var shop:=EditionRegion.shop(npc_id)
	var quote:={"supported":shop.get("repair",false),"cost":0,"items":[]}
	if not quote.supported:return quote
	for item in state.items:
		var spec: Dictionary=ITEMS[item.type]
		if item.container!="equipment" or not shop.accepted_modes.any(func(mode):return int(mode)==int(spec.get("std_mode",-1))) or int(item.durability)>=100:continue
		var cost:=maxi(1,int(spec.price)/3*(100-int(item.durability))/100)
		quote.cost+=cost;quote.items.append({"uid":item.uid,"name":spec.name,"durability":item.durability,"cost":cost})
	return quote

func story_repair_brief(npc_id: String) -> String:
	var quote:=reference_repair_quote(npc_id)
	if not quote.supported:return "此人物尚未提供修理服务。"
	if quote.items.is_empty():return "目前没有这位商人能修理的已装备物品。完好装备无需修理，可先做其他委托，不必故意损坏装备。"
	var lines: PackedStringArray=[]
	for item in quote.items:lines.append("%s · 耐久 %d%% → 100%% · %d 金币"%[item.name,item.durability,item.cost])
	lines.append("预计合计 %d 金币 · 当前 %d · 还缺 %d。以办理时装备状态为准。"%[quote.cost,state.gold,maxi(0,quote.cost-int(state.gold))])
	return "\n".join(lines)

func reference_repair(npc_id: String) -> bool:
	if state.hp<=0:message="死亡期间不能修理";return false
	var quote:=reference_repair_quote(npc_id)
	if not quote.supported:message="此商人不提供修理";return false
	if quote.items.is_empty():message="没有此商店可以修理的受损装备";return false
	if state.gold<int(quote.cost):message="修理需要 %d 金币"%int(quote.cost);return false
	var next:=state.duplicate(true)
	for row in quote.items:EditionInventory.find_item(next,row.uid).durability=100
	next.gold-=int(quote.cost);EditionInventory.mirror(next)
	Story.observe(next,"repair",{"npc":npc_id,"repaired":quote.items.size()})
	message="修理完成，花费 %d 金币"%int(quote.cost);return apply(next,"reference_repair")

func add_ground(next: Dictionary,monster: Dictionary,type: String,count: int) -> void:
	if count<=0:return
	if not next.has("ground_loot"):next.ground_loot=[]
	next.ground_loot.append({"uid":Crypto.new().generate_random_bytes(16).hex_encode(),"map":monster.get("map",next.map),"cell":monster.get("cell",next.cell).duplicate(),"type":type,"count":count})

func pickup(uid: String,map_id: String,cell: Vector2i) -> bool:
	if state.hp<=0:message="死亡状态不能拾取";return false
	var next:=state.duplicate(true)
	for loot in next.get("ground_loot",[]):
		if loot.uid!=uid:continue
		if loot.map!=map_id or Vector2(loot.cell[0]-cell.x,loot.cell[1]-cell.y).length()>1.5:message="请走近掉落物";return false
		if loot.type=="gold":next.gold+=int(loot.count)
		elif loot.has("purity"):
			var matches: Array=next.items.filter(func(i):return i.container=="inventory" and i.type==loot.type and i.get("purity",-1)==loot.purity and int(i.count)+int(loot.count)<=9999)
			if not matches.is_empty():matches[0].count+=int(loot.count)
			else:
				var slot:=EditionInventory.free_slot(next.items,"inventory")
				if slot>=48:message="背包没有空格容纳这个纯度的矿石";return false
				var item:=EditionInventory.make_item(loot.type,int(loot.count),"inventory",slot);item.purity=loot.purity;next.items.append(item)
			EditionInventory.mirror(next)
		elif not count_item(next,loot.type,int(loot.count)):message="不能拾取该物品";return false
		if next.get("cook_trial",{}).get("won",false) and next.cook_trial.get("proof_uid","")==uid:
			next.cook_trial=next.cook_trial.duplicate(true);next.cook_trial.picked=true
		next.ground_loot.erase(loot)
		message="拾取 "+("金币" if loot.type=="gold" else ITEMS[loot.type].name)+" ×"+str(int(loot.count))
		if not apply(next,"pickup",uid):return false
		item_performed.emit("ore" if loot.type=="gold" else loot.type,"pickup");return true
	message="物品已被拾取";return false

func set_assist(key: String,value) -> bool:
	var allowed:={"hp":false,"mp":false,"return":false,"pickup":false,"attack":false,"skill":false,"gold":true,"equipment":true,"materials":true,"auto_shield":false,"auto_thrust":false,"auto_heal":false,"auto_armor":false,"hp_threshold":50,"mp_threshold":30,"return_threshold":15,"radius":6}
	if not allowed.has(key):return false
	if allowed[key] is bool and not value is bool:return false
	if not allowed[key] is bool:
		if not (value is float or value is int):return false
		value=clampi(int(value),1,12 if key=="radius" else 95)
	var next:=state.duplicate(true)
	if not next.has("assist"):next.assist={}
	next.assist[key]=value;message="内挂设置已保存";return apply(next,"assist_setting")

func attribute_points() -> int:
	var used:=0
	for value in state.get("attributes",{}).values():used+=int(value)
	return maxi(0,(int(state.level)-1)*2-used)

func allocate(attribute: String) -> bool:
	if state.hp<=0 or attribute not in ["strength","vitality","spirit"] or attribute_points()<=0:message="没有可分配属性点";return false
	var next:=state.duplicate(true)
	if not next.has("attributes"):next.attributes={}
	next.attributes[attribute]=int(next.attributes.get(attribute,0))+1;message="已分配 1 点";return apply(next,"allocate_attribute")

func skill_book_brief(type: String) -> String:
	var id: String=ITEMS.get(type,{}).get("skill_book","")
	var skill: Dictionary=EditionSkills.DEFINITIONS.get(id,{})
	if skill.is_empty():return ""
	var text: String="%s · %d 级学习"%[skill.job,int(skill.level)]
	if character.job!=skill.job:return text+"\n职业不符，无法学习；书本不会消耗。"
	if int(state.level)<int(skill.level):return text+"\n当前 %d 级，还差 %d 级；使用不会消耗书本。"%[int(state.level),int(skill.level)-int(state.level)]
	if state.skills.has(id):return text+"\n已学会；再次使用不会消耗书本。"
	return text+"\n可学习；确认使用后消耗一本，学会对应技能。"

func learn_book(item: Dictionary) -> bool:
	item=EditionInventory.find_item(state,str(item.get("uid","")))
	if state.hp<=0 or item.is_empty() or not ITEMS[item.type].has("skill_book"):message="无法使用这本技能书";return false
	if item.get("container")!="inventory":message="请先把技能书放入背包";return false
	var id: String=ITEMS[item.type].skill_book
	var skill: Dictionary=EditionSkills.DEFINITIONS[id]
	if character.job!=skill.job:message="《%s》仅限%s学习"%[skill.name,skill.job];return false
	if int(state.level)<int(skill.level):message="《%s》需要 %d 级"%[skill.name,skill.level];return false
	if state.skills.has(id):message="已学会《%s》，技能书未消耗"%skill.name;return false
	var next:=state.duplicate(true)
	var book:=EditionInventory.find_item(next,item.uid)
	book.count-=1
	if book.count==0:next.items.erase(book)
	next.skills[id]={"rank":1,"proficiency":0}
	if not next.has("skill_keys"):next.skill_keys={}
	if not skill.get("passive",false):
		for key in range(8):
			if not next.skill_keys.has(str(key)):next.skill_keys[str(key)]=id;break
	EditionInventory.mirror(next)
	message="消耗《%s》×1，学会 %s"%[skill.name,skill.name]
	if not apply(next,"learn_skill_book"):return false
	item_performed.emit(item.type,"use");return true

func set_attack_mode(value: String) -> bool:
	if not EditionCombat.MODES.has(value):message="未知攻击模式";return false
	var next:=state.duplicate(true);next.attack_mode=value
	message="攻击模式："+EditionCombat.MODES[value]
	return apply(next,"attack_mode")
