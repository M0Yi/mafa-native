extends Control
var app
var terrain: ImageTexture
const ORIGIN:=Vector2i(250,590)
const FACTOR:=4.0
func setup(host) -> void:
	app=host;custom_minimum_size=Vector2(320,360);size=custom_minimum_size
	var mask:=FileAccess.get_file_as_bytes(EditionResources.BASE+"maps/0.walk")
	var image:=Image.create(80,90,false,Image.FORMAT_RGB8)
	for y in range(90):
		for x in range(80):image.set_pixel(x,y,Color("5b5939") if mask[(y+ORIGIN.y)*700+x+ORIGIN.x]>0 else Color("242c22"))
	terrain=ImageTexture.create_from_image(image)
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			if app.world.metadata.id!="0":app.pending_message="先返回新手村，再点击地图寻路";return
			var cell:=ORIGIN+Vector2i((event.position/FACTOR).floor())
			if app.world.navigation.walkable(cell):app.world.player.go_to(cell);app.windows.close_top()
			else:app.pending_message="这个位置不可通行"
			accept_event())
func _process(_delta: float) -> void:queue_redraw()
func marker(cell: Vector2i,color: Color,radius:=3.0) -> void:
	draw_circle((Vector2(cell-ORIGIN)+Vector2(0.5,0.5))*FACTOR,radius,color)
func _draw() -> void:
	if terrain==null:return
	draw_texture_rect(terrain,Rect2(0,0,320,360),false)
	for npc in EditionVillage.data().npcs:marker(Vector2i(npc.cell[0],npc.cell[1]),Color.GOLD)
	for cell in EditionVillage.data().chickens:marker(Vector2i(cell[0],cell[1]),Color.LIGHT_GREEN)
	marker(EditionVillage.PATROL,Color.DEEP_SKY_BLUE,4)
	if EditionVillage.nearby(app.world.metadata.id,app.world.player.cell):marker(app.world.player.cell,Color.WHITE,4)
