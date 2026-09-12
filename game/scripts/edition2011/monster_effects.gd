extends Node2D
var world
func _ready() -> void:
	var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
static func attack_frame(entity: Dictionary,seconds: float) -> int:
	if int(entity.get("race_image",-1))!=33 or int(entity.get("hp",0))<=0 or entity.get("motion","")!="attack":return -1
	var age:=maxf(0,seconds-float(entity.get("motion_time",0)))
	var action:=EditionCreatures.action(entity,"attack")
	if age>=EditionCreatures.duration(entity,"attack",0.72):return -1
	# Reference SyncBody=true, StartRel=5; do not run the ten-frame pack
	# on an independent clock or extend the six-frame body attack.
	var relative:=int(age*1000/float(action.ms))-5
	return 100+relative if relative>=0 and relative<10 else -1
func _draw() -> void:
	if world==null or world.resources==null:return
	for entity in world.entities:
		var index:=attack_frame(entity,world.elapsed)
		if index<0:continue
		var image: Dictionary=world.resources.frame("mon15",index)
		if image.is_empty():continue
		draw_texture(image.texture,(world.actors.anchor(entity)+image.offset).round())
