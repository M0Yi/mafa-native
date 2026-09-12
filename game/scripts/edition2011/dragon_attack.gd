class_name EditionDragonAttack
extends RefCounted
# Single-player reconstruction, not a verified historical boss skill.
const WINDUP=1.2
const COOLDOWN=6.0
static func update(world,entity: Dictionary,motion: ClassicPlayer,protected: bool) -> bool:
	if entity.get("reference_name","")!="火龙教主":return false
	if world.paused:return false
	if entity.get("hp",0)<=0 or protected or not entity.get("aggro",false):entity.erase("dragon_warning");return false
	if entity.has("dragon_warning"):
		motion.route.clear()
		if world.elapsed<float(entity.dragon_warning.at):return true
		var target: Vector2i=entity.dragon_warning.cell
		entity.erase("dragon_warning");entity.dragon_ready=world.elapsed+COOLDOWN
		entity.motion="attack";entity.motion_time=world.elapsed;entity.strike_done=true
		world.actors.sound(entity,"weapon")
		if world.player.cell in area(world,target):world.monster_hit.emit(entity,int(entity.get("dc_max",120)))
		return true
	if world.elapsed<float(entity.get("dragon_ready",0)) or motion.progress<1 or entity.get("motion","") in ["attack","hurt"]:return false
	if (world.player.cell-motion.cell).length()>6:return false
	var ray: Vector2i=world.player.cell-motion.cell
	var previous:=motion.cell
	for i in range(1,maxi(absi(ray.x),absi(ray.y))+1):
		var point:=Vector2i(Vector2(motion.cell).lerp(Vector2(world.player.cell),float(i)/maxi(absi(ray.x),absi(ray.y))).round())
		if point!=previous and not world.navigation.can_step(previous,point):return false
		previous=point
	entity.dragon_warning={"cell":world.player.cell,"at":world.elapsed+WINDUP}
	motion.route.clear();motion.action="stand";entity.motion="stand"
	world.actors.sound(entity,"attack")
	return true
static func area(world,center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if world.navigation.walkable(center):result.append(center)
	for offset in ClassicNavigation.DIRECTIONS:
		if world.navigation.can_step(center,center+offset):result.append(center+offset)
	return result
static func draw_warning(world) -> void:
	for entity in world.entities:
		if entity.get("hp",0)<=0 or not entity.has("dragon_warning"):continue
		for cell in area(world,entity.dragon_warning.cell):
			var rect:=Rect2(Vector2(cell)*Vector2(48,32),Vector2(48,32)).grow(-2)
			world.draw_rect(rect,Color(0.85,0.15,0.04,0.12))
			world.draw_rect(rect,Color(1,0.4,0.1,0.9),false,2)
