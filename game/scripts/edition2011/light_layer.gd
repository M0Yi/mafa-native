extends Node2D

var commands: Array=[]

func _ready() -> void:
	var blend:=CanvasItemMaterial.new()
	blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	material=blend

func _draw() -> void:
	for item in commands:draw_texture(item[0],item[1])
