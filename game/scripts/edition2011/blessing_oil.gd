extends RefCounted
# Local deterministic draws keep failed-write retries stable. Outcome rules
# follow mirgo weaponMakeLuck/weaponMakeUnlock, not certified official rates.
static func outcome(weapon: Dictionary,curse_roll: int,upgrade_roll: int) -> Dictionary:
	var blessing:=int(weapon.get("blessing",0));var curse:=int(weapon.get("curse",0))
	var message:="祝福油未使武器发生变化"
	if curse_roll%20==0:
		if blessing>0:blessing-=1;message="武器祝福降低了"
		elif curse<10:curse+=1;message="武器受到诅咒"
	elif curse>0:curse-=1;message="武器的一层诅咒消除了"
	elif blessing<1:blessing+=1;message="武器获得祝福"
	else:
		var raw: Dictionary=EditionRules.ITEMS[weapon.type].get("raw",{})
		var spread:=maxi(1,int(absi(int(raw.get("dcMax",0))-int(raw.get("dc",0)))/5))
		var denominator:=spread+6 if blessing<3 else spread*40
		if blessing<7 and upgrade_roll%denominator==0:blessing+=1;message="武器获得祝福"
	return {"blessing":blessing,"curse":curse,"message":message}
static func use(rules,uid: String) -> bool:
	var oil:=EditionInventory.find_item(rules.state,uid)
	if oil.get("type")!="ref:135" or oil.get("container")!="inventory" or rules.state.hp<=0:rules.message="请在存活时使用背包中的祝福油";return false
	var weapons: Array=rules.state.items.filter(func(i):return i.container=="equipment" and EditionRules.ITEMS[i.type].get("slot","")=="weapon")
	if weapons.is_empty():rules.message="请先装备武器，祝福油未消耗";return false
	var weapon: Dictionary=weapons[0]
	var draw: String=("blessing-v1:"+uid+":"+str(int(oil.count))+":"+str(weapon.uid)).sha256_text()
	var result:=outcome(weapon,draw.substr(0,7).hex_to_int(),draw.substr(7,7).hex_to_int())
	var next: Dictionary=rules.state.duplicate(true)
	var changed:=EditionInventory.find_item(next,weapon.uid)
	changed.blessing=result.blessing;changed.curse=result.curse
	var consumed:=EditionInventory.find_item(next,uid);consumed.count-=1
	if consumed.count==0:next.items.erase(consumed)
	EditionInventory.mirror(next)
	if not rules.apply(next,"blessing_oil"):return false
	rules.message=str(result.message)+" · "+str(EditionRules.ITEMS[weapon.type].name)+" · 祝福%d / 诅咒%d"%[result.blessing,result.curse]
	rules.item_performed.emit("ref:135","use")
	return true
