class_name EditionCentipedeAttack
extends RefCounted
# mirgo monsterai.go runCentiKingAI: >3000ms trigger at Chebyshev <=6,
# actual magic area |dx|<6 && |dy|<6. Burrow state is persisted at world saves.
const INTERVAL:=3.0
const BURROW_COOLDOWN:=10.0
static func snapshot(entity: Dictionary) -> Dictionary:
	if int(entity.get("race",-1))!=107 or int(entity.get("race_image",-1))!=33 or int(entity.get("hp",0))<=0:return {}
	return {"spawn_id":str(entity.spawn_id),"generation":int(entity.get("generation",0)),"phase":str(entity.get("centipede_phase","hidden")),"hp":int(entity.hp),"last_attack":float(entity.get("centipede_last_attack",0)),"motion":str(entity.get("motion","stand")),"motion_time":float(entity.get("motion_time",0))}

static func restore(entity: Dictionary,saved: Dictionary) -> void:
	if saved.is_empty() or str(saved.get("spawn_id",""))!=str(entity.get("spawn_id","")) or int(saved.get("generation",-1))!=int(entity.get("generation",0)):return
	if saved.get("phase","") not in ["hidden","emerging","exposed","receding"]:return
	for field in ["hp","last_attack","motion_time"]:
		var value=saved.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0:return
	if int(saved.hp)<=0:return
	entity.hp=mini(int(entity.max_hp),int(saved.hp));entity.centipede_phase=saved.phase
	entity.centipede_last_attack=float(saved.last_attack);entity.motion_time=float(saved.motion_time)
	entity.motion=str(saved.get("motion","stand")) if saved.get("motion","") in ["stand","attack","hurt","emerge","recede"] else "stand"

static func status_roll() -> int:
	if randi_range(0,3)!=0:return 0
	return 2 if randi_range(0,2)==0 else 1

static func in_area(origin: Vector2i,target: Vector2i) -> bool:
	var delta: Vector2i=(target-origin).abs()
	return delta.x<6 and delta.y<6
static func update(world,entity: Dictionary,motion: ClassicPlayer,protected: bool) -> bool:
	if int(entity.get("race",-1))!=107 or int(entity.get("race_image",-1))!=33:return false
	if world.paused:return true
	motion.route.clear();motion.action="stand"
	if not entity.has("centipede_last_attack"):entity.centipede_last_attack=world.elapsed
	if entity.hp<=0:return true
	if not entity.has("centipede_phase"):entity.centipede_phase="hidden"
	var phase: String=entity.centipede_phase
	var delta: Vector2i=(world.player.cell-motion.cell).abs()
	if phase=="hidden":
		if not protected and entity.get("aggro",false) and maxi(delta.x,delta.y)<=3 and world.elapsed>float(entity.centipede_last_attack)+BURROW_COOLDOWN+0.0000001:
			entity.centipede_phase="emerging";entity.hp=entity.max_hp;entity.motion="emerge";entity.motion_time=world.elapsed;entity.centipede_last_attack=world.elapsed
			world.actors.sound(entity,"appear")
		return true
	if phase in ["emerging","receding"]:
		var action_name: String="walk" if phase=="emerging" else "corpse"
		if world.elapsed-float(entity.motion_time)<EditionCreatures.duration(entity,action_name,2.0):return true
		entity.centipede_phase="exposed" if phase=="emerging" else "hidden";entity.motion="stand"
		if entity.centipede_phase=="hidden":return true
	if (protected or not entity.get("aggro",false) or maxi(delta.x,delta.y)>6) and world.elapsed>float(entity.centipede_last_attack)+BURROW_COOLDOWN+0.0000001:
		entity.centipede_phase="receding";entity.motion="recede";entity.motion_time=world.elapsed;entity.centipede_last_attack=world.elapsed;entity.aggro=false
		return true
	if entity.get("motion","")=="hurt" and world.elapsed-float(entity.get("motion_time",0))>=EditionCreatures.duration(entity,"hurt",0.2):entity.motion="stand"
	if entity.get("motion","")=="attack" and world.elapsed-float(entity.get("motion_time",0))>=EditionCreatures.duration(entity,"attack",0.72):entity.motion="stand"
	if entity.hp<=0 or protected or not entity.get("aggro",false):return true
	if maxi(delta.x,delta.y)>6 or world.elapsed<=float(entity.centipede_last_attack)+INTERVAL+0.0000001:return true
	entity.centipede_last_attack=world.elapsed;entity.focus_time=world.elapsed
	entity.motion="attack";entity.motion_time=world.elapsed;entity.strike_done=true
	world.actors.sound(entity,"attack")
	if in_area(motion.cell,world.player.cell):
		var status:=status_roll()
		var hit: Dictionary=entity.duplicate();hit.magic_attack=true;hit.green_poison=status==1;hit.stone=status==2
		world.monster_hit.emit(hit,randi_range(int(entity.get("dc",1)),maxi(int(entity.get("dc",1)),int(entity.get("dc_max",1)))))
	for target in world.entities:
		if target.get("kind","")!="traveler" or int(target.get("hp",0))<=0:continue
		var cell:=Vector2i(target.cell[0],target.cell[1])
		if not in_area(motion.cell,cell) or EditionRegion.safe(world.metadata.id,cell):continue
		var status:=status_roll()
		world.monster_hit_traveler.emit(target,{"damage":randi_range(int(entity.get("dc",1)),maxi(int(entity.get("dc",1)),int(entity.get("dc_max",1)))),"magic_attack":true,"green_poison":status==1,"stone":status==2,"source":entity.id})
	return true
