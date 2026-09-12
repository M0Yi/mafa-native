extends RefCounted
# Reference: mirgo/cmd/server/playobject.go calcDamage. Base character
# growth remains the existing single-player reconstruction.
static func bounds(state: Dictionary,base: int) -> Vector2i:
	var value:=Vector2i(base,base)
	for item in state.get("items",[]):
		if item.container!="equipment" or int(item.durability)<=0:continue
		var spec: Dictionary=EditionRules.ITEMS[item.type]
		var raw: Dictionary=spec.get("raw",{})
		var lower:=maxi(0,int(raw.get("dc",spec.get("attack",0))))
		var upper:=maxi(lower,int(raw.get("dcMax",spec.get("attack",0))))
		value+=Vector2i(lower,upper)
	return value
static func luck(state: Dictionary) -> int:
	var total:=0
	for item in state.get("items",[]):
		if item.container=="equipment" and int(item.durability)>0:
			total+=int(item.get("blessing",0))-int(item.get("curse",0))
	return clampi(total,-9,9)
static func roll(bounds: Vector2i,luck_value: int,rng: RandomNumberGenerator=null) -> int:
	var low:=mini(bounds.x,bounds.y)
	var high:=maxi(bounds.x,bounds.y)
	var amount:=randi_range(low,high) if rng==null else rng.randi_range(low,high)
	var effective:=clampi(luck_value,-9,9)
	if effective!=0:
		var maximum:=9-absi(effective)
		var force:=randi_range(0,maximum) if rng==null else rng.randi_range(0,maximum)
		if force==0:amount=high if effective>0 else low
	return amount
