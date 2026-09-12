class_name EditionCreatures
extends RefCounted
# Sound event convention: mirgo actorsound.go / Delphi Actor.pas.
const SOUND_OFFSETS={"appear":0,"idle":1,"attack":2,"weapon":3,"hurt":4,"die":5,"die2":6}
const PROFILES={
	"village_chicken":{"appearance":160,"bank":"mon17","base":0,"damage":1,"actions":{
		"stand":{"start":0,"count":4,"skip":6,"ms":200},"walk":{"start":80,"count":6,"skip":4,"ms":120},"attack":{"start":160,"count":6,"skip":4,"ms":100,"loop":false},"hurt":{"start":240,"count":2,"skip":0,"ms":100,"loop":false},"die":{"start":260,"count":10,"skip":0,"ms":140,"loop":false},"corpse":{"start":340,"count":1,"skip":0,"ms":100}}},
	"forest_yeti":{"appearance":1,"bank":"mon1","base":280,"damage":4,"actions":{
		"stand":{"start":0,"count":4,"skip":4,"ms":200},"walk":{"start":64,"count":6,"skip":2,"ms":120},"attack":{"start":128,"count":4,"skip":4,"ms":150,"loop":false},"hurt":{"start":192,"count":2,"skip":0,"ms":100,"loop":false},"die":{"start":208,"count":4,"skip":4,"ms":140,"loop":false},"corpse":{"start":211,"count":1,"skip":7,"ms":100}}}
}
# mirgo moneffect.go LockDir0: stationary special bodies have one facing.
static func underground(entity: Dictionary) -> bool:
	return entity.get("centipede_phase","") in ["hidden","receding"]

static func body_direction(entity: Dictionary) -> int:
	return 0 if int(entity.get("race_image",-1)) in [33,34,35] else posmod(int(entity.get("direction",0)),8)

static func profile(entity: Dictionary) -> Dictionary:return entity.get("profile",PROFILES.get(entity.get("species",""),{}))
static func sound_id(entity: Dictionary,event: String) -> int:
	if entity.get("kind","")=="traveler":
		if event=="die":return 145 if entity.get("gender","男")=="女" else 144
		if event=="hurt":return 139 if entity.get("gender","男")=="女" else 138
		return -1
	var spec:=profile(entity)
	if spec.has("sounds"):return int(spec.sounds.get(event,-1))
	var appearance:=int(entity.get("appearance",spec.get("appearance",-1)))
	return 200+appearance*10+int(SOUND_OFFSETS[event]) if appearance>=0 and SOUND_OFFSETS.has(event) else -1
static func action(entity: Dictionary,name: String) -> Dictionary:
	# mirgo MA25.ActCritical + HitUsesCritical for the centipede body.
	if name=="attack" and int(entity.get("race_image",-1))==33:
		return {"start":10,"count":6,"skip":4,"ms":120,"loop":false}
	return profile(entity).get("actions",{}).get(name,{})

static func duration(entity: Dictionary,name: String,fallback: float) -> float:
	var spec:=action(entity,name)
	return maxf(0.001,float(spec.get("count",0))*float(spec.get("ms",0))/1000) if int(spec.get("count",0))>0 else fallback
