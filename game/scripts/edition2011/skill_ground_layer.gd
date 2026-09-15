extends Node2D
var effects
func _draw() -> void:
 if is_instance_valid(effects):effects.draw_ground(self)
