class_name EditionInventory
extends RefCounted
const SLOTS=["weapon","armor","helmet","necklace","bracelet_left","bracelet_right","ring_left","ring_right","belt","boots","amulet","torch","charm"]
const SLOT_NAMES=["武器","衣服","头盔","项链","左手镯","右手镯","左戒指","右戒指","腰带","鞋子","护符","照明","宝物"]

static func fits(type: String,slot: int) -> bool:
	if slot<0 or slot>=SLOTS.size():return false
	var kind: String=EditionRules.ITEMS.get(type,{}).get("slot","")
	return not kind.is_empty() and (SLOTS[slot]==kind or (kind in ["ring","bracelet"] and SLOTS[slot].begins_with(kind+"_")))

static func equip_slot(state: Dictionary,type: String) -> int:
	var first:=-1
	for i in range(SLOTS.size()):
		if fits(type,i):
			if first<0:first=i
			if state.items.filter(func(item):return item.container=="equipment" and int(item.slot)==i).is_empty():return i
	return first

static func make_item(type: String,count: int,container: String,slot: int,durability:=100) -> Dictionary:
	return {"uid":Crypto.new().generate_random_bytes(16).hex_encode(),"type":type,"count":count,"container":container,"slot":slot,"durability":durability}

# All inventory views describe the same persisted instance, including unknown ore grades.
static func condition_text(item: Dictionary) -> String:
	var spec: Dictionary=EditionRules.ITEMS.get(item.get("type",""),{})
	if int(spec.get("std_mode",-1))==43:
		return "纯度：%d"%int(item.purity) if item.has("purity") else "纯度：未知"
	if spec.has("slot"):
		var text: String="耐久：%d/100"%int(item.get("durability",100))
		if item.has("blessing") or item.has("curse"):text+=" · 祝福%d / 诅咒%d"%[int(item.get("blessing",0)),int(item.get("curse",0))]
		return text
	return "数量：%d"%int(item.get("count",0))

# Crafting consumes explicitly eligible inventory instances, never aggregate counts.
# Prefer lower qualifying grades so better ore remains available for other recipes.
static func consume_graded_ore(state: Dictionary,type: String,count: int,minimum: int) -> bool:
	if count<=0 or minimum<0 or minimum>100 or int(EditionRules.ITEMS.get(type,{}).get("std_mode",-1))!=43:return false
	var candidates: Array=state.get("items",[]).filter(func(i):return i.get("container")=="inventory" and i.get("type")==type and i.has("purity") and int(i.purity)>=minimum)
	candidates.sort_custom(func(a,b):return int(a.slot)<int(b.slot) if int(a.purity)==int(b.purity) else int(a.purity)<int(b.purity))
	var available:=0
	for item in candidates:available+=int(item.count)
	if available<count:return false
	var remaining:=count
	for item in candidates:
		var taken:=mini(remaining,int(item.count))
		item.count-=taken;remaining-=taken
		if int(item.count)==0:state.items.erase(item)
		if remaining==0:break
	mirror(state)
	return true

static func free_slot(items: Array,container: String) -> int:
	var occupied: Dictionary={}
	for item in items:
		if item.container==container:occupied[int(item.slot)]=true
	var slot:=0
	while occupied.has(slot):slot+=1
	return slot

static func migrate(state: Dictionary) -> void:
	if state.has("items"):return
	var items: Array=[]
	for container in ["inventory","warehouse"]:
		for type in state[container]:
			var count:=int(state[container][type])
			if EditionRules.ITEMS[type].has("slot"):
				for _i in range(count):items.append(make_item(type,1,container,free_slot(items,container),int(state.durability.get(type,100))))
			elif count>0:items.append(make_item(type,count,container,free_slot(items,container)))
	for slot in state.equipment:
		var type: String=state.equipment[slot]
		items.append(make_item(type,1,"equipment",SLOTS.find(slot),int(state.durability.get(type,100))))
	state.items=items;state.inventory_version=1;state.quickbar=["potion","mana","","","",""]

static func mirror(state: Dictionary) -> void:
	state.inventory={};state.warehouse={};state.equipment={};state.durability={}
	for item in state.items:
		if item.container in ["inventory","warehouse"]:
			state[item.container][item.type]=int(state[item.container].get(item.type,0))+int(item.count)
		elif item.container=="equipment":
			var slot: String=SLOTS[int(item.slot)]
			state.equipment[slot]=item.type;state.durability[item.type]=item.durability

# Legacy rule operations still produce aggregate deltas. Reconcile those deltas
# without recreating existing instances or resetting their individual durability.
static func reconcile(state: Dictionary) -> bool:
	migrate(state)
	for container in ["inventory","warehouse"]:
		# Free every consumed slot before admitting rewards. Type order must not
		# decide whether an exchange fits in a full bag.
		for type in EditionRules.ITEMS:
			var existing: Array=state.items.filter(func(i):return i.container==container and i.type==type)
			var current:=0
			for item in existing:current+=int(item.count)
			var remove_count:=current-int(state[container].get(type,0))
			if remove_count<=0:continue
			existing.reverse()
			for item in existing:
				var remove:=mini(remove_count,int(item.count));item.count-=remove;remove_count-=remove
				if item.count==0:state.items.erase(item)
				if remove_count==0:break
		for type in EditionRules.ITEMS:
			var existing: Array=state.items.filter(func(i):return i.container==container and i.type==type)
			var current:=0
			for item in existing:current+=int(item.count)
			var delta:=int(state[container].get(type,0))-current
			if delta<=0:continue
			var ungraded: Array=existing.filter(func(i):return not i.has("purity"))
			if not EditionRules.ITEMS[type].has("slot") and not ungraded.is_empty():ungraded[0].count+=delta
			else:
				var number:=delta if EditionRules.ITEMS[type].has("slot") else 1
				for _i in range(number):
					var slot:=free_slot(state.items,container)
					if slot>=(48 if container=="inventory" else 50):return false
					state.items.append(make_item(type,1 if number==delta else delta,container,slot))
	mirror(state);return true

static func validate(state: Dictionary) -> bool:
	if not state.get("items") is Array:return false
	var ids: Dictionary={};var slots: Dictionary={}
	for item in state.items:
		if not item is Dictionary:return false
		if not item.get("uid") is String or not LocalAccounts.matches(item.uid,"^[0-9a-f]{32}$") or ids.has(item.uid):return false
		if not EditionRules.ITEMS.has(item.get("type")) or item.get("container") not in ["inventory","warehouse","equipment"]:return false
		for field in ["count","slot","durability"]:
			if not (item.get(field) is int or item.get(field) is float) or not is_finite(float(item[field])) or int(item[field])!=float(item[field]):return false
		if item.count<1 or item.count>9999 or item.slot<0 or item.durability<0 or item.durability>100:return false
		var spec: Dictionary=EditionRules.ITEMS[item.type]
		if item.has("purity"):
			var purity=item.purity
			if int(spec.get("std_mode",-1))!=43 or not (purity is int or purity is float) or not is_finite(float(purity)) or purity<0 or purity>100 or purity!=floor(float(purity)):return false
		for field in ["blessing","curse"]:
			if not item.has(field):continue
			var value=item[field]
			if spec.get("slot","")!="weapon" or not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>(7 if field=="blessing" else 10) or value!=floor(float(value)):return false
		if spec.has("slot") and item.count!=1:return false
		if item.container=="equipment" and not fits(item.type,int(item.slot)):return false
		if item.container in ["inventory","warehouse"] and int(item.slot)>=(48 if item.container=="inventory" else 50):return false
		var key:=str(item.container)+":"+str(item.slot)
		if slots.has(key):return false
		ids[item.uid]=true;slots[key]=true
	return true

static func find_item(state: Dictionary,uid: String) -> Dictionary:
	for item in state.get("items",[]):
		if item.uid==uid:return item
	return {}

static func operate(state: Dictionary,action: String,args: Dictionary) -> String:
	var item:=find_item(state,str(args.get("uid","")))
	if action=="sort":
		var list: Array=state.items.filter(func(i):return i.container=="inventory")
		list.sort_custom(func(a,b):return a.type<b.type if a.type!=b.type else a.uid<b.uid)
		for i in range(list.size()):list[i].slot=i
		return ""
	if item.is_empty():return "物品已不存在，请重新选择"
	var spec: Dictionary=EditionRules.ITEMS[item.type]
	match action:
		"move":
			var destination: String=args.get("container","");var slot:=int(args.get("slot",-1))
			if destination not in ["inventory","warehouse","equipment"] or slot<0:return "无效目标格"
			if destination=="equipment":
				if not fits(item.type,slot):return "装备不适合这个位置"
			elif slot>=(48 if destination=="inventory" else 50):return "目标位置超出容量"
			var target: Dictionary={}
			for candidate in state.items:
				if candidate.container==destination and int(candidate.slot)==slot:target=candidate;break
			if target.get("uid")==item.uid:return ""
			if not target.is_empty():
				if target.type==item.type and not spec.has("slot") and target.get("purity",-1)==item.get("purity",-1):
					if target.count+item.count>9999:return "叠放数量超过上限"
					target.count+=item.count;state.items.erase(item);return ""
				if item.container=="equipment":
					var other: Dictionary=EditionRules.ITEMS[target.type]
					if not fits(target.type,int(item.slot)):return "换下装备需要空格"
				target.container=item.container;target.slot=item.slot
			item.container=destination;item.slot=slot
		"split":
			var count:=int(args.get("count",0));var slot:=free_slot(state.items,item.container)
			if item.container=="equipment" or count<=0 or count>=item.count:return "拆分数量必须小于当前数量"
			if slot>=(48 if item.container=="inventory" else 50):return "没有空格"
			item.count-=count
			var split:=make_item(item.type,count,item.container,slot,item.durability)
			if item.has("purity"):split.purity=item.purity
			state.items.append(split)
		"use":
			if item.container!="inventory":return "请先把物品放入背包"
			if spec.has("slot"):return operate(state,"move",{"uid":item.uid,"container":"equipment","slot":equip_slot(state,item.type)})
			if spec.has("heal"):state.hp=mini(100+int(state.level)*15+int(state.get("attributes",{}).get("vitality",0))*5,int(state.hp)+int(spec.heal))
			if spec.has("mana"):state.mp=mini(80+int(state.level)*8,int(state.mp)+int(spec.mana))
			if spec.get("utility")=="reset":state.attributes={}
			if spec.get("utility")=="return":state.map="0";state.cell=[EditionVillage.SPAWN.x,EditionVillage.SPAWN.y]
			if not spec.has("heal") and not spec.has("mana") and not spec.has("utility"):return "需要交给 NPC 或施法使用"
			item.count-=1
			if item.count==0:state.items.erase(item)
		"drop":
			if item.container!="inventory" or int(spec.get("std_mode",-1))!=43:return "目前此丢弃流程仅支持背包矿石"
			if not state.has("ground_loot"):state.ground_loot=[]
			var loot:={"uid":Crypto.new().generate_random_bytes(16).hex_encode(),"map":state.map,"cell":state.cell.duplicate(),"type":item.type,"count":item.count}
			if item.has("purity"):loot.purity=item.purity
			state.ground_loot.append(loot);state.items.erase(item)
		"bind":
			var slot:=int(args.get("slot",-1))
			if slot<0 or slot>=6:return "无效快捷栏"
			if item.container!="inventory":return "只能绑定背包中的物品"
			state.quickbar[slot]=item.type
		_ :return "未知物品操作"
	return ""

static func transfer_one(state: Dictionary,type: String,source: String,destination: String) -> String:
	var candidates: Array=state.items.filter(func(i):return i.type==type and i.container==source)
	candidates.sort_custom(func(a,b):return int(a.slot)<int(b.slot))
	if candidates.is_empty():return "没有该物品"
	var item: Dictionary=candidates[0]
	var targets: Array=state.items.filter(func(i):return i.type==type and i.container==destination and i.get("purity",-1)==item.get("purity",-1) and int(i.count)<9999)
	if not EditionRules.ITEMS[type].has("slot") and not targets.is_empty():
		targets[0].count+=1;item.count-=1
		if item.count==0:state.items.erase(item)
	else:
		var slot:=free_slot(state.items,destination)
		if slot>=(48 if destination=="inventory" else 50):return "目标容器没有空格"
		if int(item.count)==1:item.container=destination;item.slot=slot
		else:
			item.count-=1
			var moved:=make_item(type,1,destination,slot,item.durability)
			if item.has("purity"):moved.purity=item.purity
			state.items.append(moved)
	mirror(state)
	return ""
