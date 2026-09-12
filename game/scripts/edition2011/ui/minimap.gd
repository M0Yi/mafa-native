extends Control
var app
var style:=0
var map_id:=""
var center:=Vector2i(-1,-1)
var terrain: ImageTexture
var region:=Rect2()
var map_rect:=Rect2(10,32,180,132)
var title:=Label.new()
var location:=Label.new()
var open_button:=Button.new()
func setup(host) -> void:
	app=host;mouse_filter=Control.MOUSE_FILTER_STOP;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var saved: String=app.store.read_metadata("minimap_style")
	style=clampi(int(saved),0,2) if saved.is_valid_int() else 0
	for label in [title,location]:
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",12);add_child(label)
	title.position=Vector2(8,5);title.size=Vector2(184,22);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	location.position=Vector2(8,168);location.size=Vector2(184,20)
	open_button.text="打开地图";open_button.position=Vector2(45,192);open_button.size=Vector2(110,26);open_button.add_theme_font_size_override("font_size",12);add_child(open_button);open_button.pressed.connect(app.show_map_info)
	tooltip_text="点击切换：附近地图 → 全图 → 收起\n白色：自己　金色：NPC　绿色：云玩家　红色：怪物"
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			cycle_style();accept_event())
func cycle_style() -> void:
	var next: int=(style+1)%3
	if not app.store.put_metadata("minimap_style",str(next)):app.info("小地图样式保存失败，请重试");return
	style=next;map_id="";queue_redraw()
func _process(_delta: float) -> void:
	if app==null or app.mode!="game" or app.world.metadata.is_empty():return
	var zoom:=EditionDisplay.ui_zoom(get_viewport_rect().size,app.windows.requested_scale,app.display_density)
	scale=Vector2.ONE*zoom;size=Vector2(200,30 if style==2 else 226)
	position=Vector2(get_viewport_rect().size.x-size.x*zoom-12*zoom,12*zoom).round()
	open_button.visible=style!=2;location.visible=style!=2
	title.text=str(app.world.metadata.name)+" · "+["附近","全图","展开"][style]
	location.text="%d, %d"%[app.world.player.cell.x,app.world.player.cell.y]
	if style!=2 and (map_id!=str(app.world.metadata.id) or (style==0 and center!=app.world.player.cell)):rebuild()
	queue_redraw()
func rebuild() -> void:
	map_id=str(app.world.metadata.id);center=app.world.player.cell
	var extent:=Vector2(app.world.navigation.size)
	region=Rect2(Vector2(center)-Vector2(30,22),Vector2(60,44)) if style==0 else Rect2(Vector2.ZERO,extent)
	var resolution:=Vector2i(60,44)
	# Bound whole-map work, including tall maps.
	if style==1:resolution=Vector2i((extent*minf(1,256/maxf(extent.x,extent.y))).ceil())
	var image:=Image.create(resolution.x,resolution.y,false,Image.FORMAT_RGB8)
	for y in range(resolution.y):
		for x in range(resolution.x):
			var cell:=Vector2i(region.position+(Vector2(x,y)+Vector2(0.5,0.5))*region.size/Vector2(resolution))
			var inside:=cell.x>=0 and cell.y>=0 and cell.x<extent.x and cell.y<extent.y
			var walkable: bool=inside and bool(app.world.navigation.cells[cell.y][cell.x])
			image.set_pixel(x,y,Color("746743") if walkable else Color("252820"))
	terrain=ImageTexture.create_from_image(image)
	var fit:=minf(180/region.size.x,132/region.size.y)
	map_rect=Rect2(Vector2(10,32)+(Vector2(180,132)-region.size*fit)/2,region.size*fit)
func marker(cell: Vector2i,color: Color,radius: float) -> void:
	if not region.has_point(Vector2(cell)+Vector2(0.5,0.5)):return
	var at:=map_rect.position+(Vector2(cell)+Vector2(0.5,0.5)-region.position)/region.size*map_rect.size
	draw_circle(at,radius+1,Color.BLACK);draw_circle(at,radius,color)
func _draw() -> void:
	draw_style_box(panel_style(),Rect2(Vector2.ZERO,size))
	if style==2 or terrain==null:return
	draw_texture_rect(terrain,map_rect,false)
	for entity in app.world.entities:
		if entity.get("hp",1)<=0:continue
		marker(Vector2i(entity.cell[0],entity.cell[1]),Color.GOLD if entity.kind=="npc" else Color.LIGHT_GREEN if entity.kind=="traveler" else Color.INDIAN_RED,1.5)
	marker(app.world.player.cell,Color.WHITE,3)
func panel_style() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color("191812eb");box.border_color=Color("a88c52");box.set_border_width_all(2);box.set_corner_radius_all(5);return box
