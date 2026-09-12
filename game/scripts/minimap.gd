class_name ClassicMinimap
extends Control

var texture: ImageTexture
var player: ClassicPlayer
var map_size := Vector2.ONE

func configure(nav: ClassicNavigation, actor: ClassicPlayer) -> void:
	player = actor
	map_size = Vector2(nav.size)
	var image := Image.create(nav.size.x,nav.size.y,false,Image.FORMAT_RGBA8)
	for y in range(nav.size.y):
		for x in range(nav.size.x):
			image.set_pixel(x,y,Color("5a6b53") if nav.walkable(Vector2i(x,y)) else Color("232b26"))
	texture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if texture == null: return
	draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false,Color(1,1,1,0.85))
	draw_rect(Rect2(Vector2.ZERO,size),Color("a49168"),false,1)
	var p := (Vector2(player.cell)+Vector2(0.5,0.5))/map_size*size
	draw_circle(p,3.5,Color("f4df9a"))
	draw_arc(p,6,0,TAU,20,Color(0.95,0.87,0.61,0.6),1)
