extends Node2D
var world
func _draw() -> void:
 if is_instance_valid(world):world.paint_foreground(self)
