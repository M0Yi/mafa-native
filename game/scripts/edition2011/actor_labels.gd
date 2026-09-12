extends Node2D
var world
func _ready() -> void:
	# Text uses framebuffer coordinates for crisp, density-aware type. It shares
	# the exact world-to-screen projection used by artwork and hit testing.
	top_level=true
func title(entity: Dictionary) -> String:
	return str(entity.name)
func layout(entity: Dictionary) -> Dictionary:
	var density: float=maxf(1,world.display_density)
	var font_size:=int(roundf(EditionDisplay.NAME_POINTS*density))
	var bounds: Rect2=world.actor_idle_bounds(entity,true)
	var at: Vector2=world.actors.anchor(entity)
	var center_x:=bounds.get_center().x
	var head: Vector2=(at+Vector2(center_x,bounds.position.y)-world.camera)*world.zoom
	var tile_width: float=ClassicPlayer.CELL.x*world.zoom
	var display_text:=title(entity)
	if entity.get("kind")=="monster":
		font_size=mini(font_size,int(14*density))
		while font_size>int(9*density) and world.font.get_string_size(display_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>tile_width:font_size-=1
		while display_text.length()>1 and world.font.get_string_size(display_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>tile_width:display_text=display_text.left(display_text.length()-2)+"…"
	var health:=Rect2()
	# Names follow the feet, never the shadow or upper frame rectangle.
	var feet: Vector2=(at+Vector2(bounds.get_center().x,22)-world.camera)*world.zoom
	var width: float=world.font.get_string_size(display_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var height: float=world.font.get_height(font_size)
	var rect:=Rect2(Vector2(roundf(feet.x-width/2),roundf(feet.y+4*density)),Vector2(width,height))
	if entity.has("hp") and int(entity.hp)>0 and int(entity.hp)<int(entity.get("max_hp",entity.hp)):
		var bar_size:=Vector2(minf(44*density,tile_width-4),3*density)
		health=Rect2(Vector2(roundf(head.x-bar_size.x/2),roundf(head.y-5*density-bar_size.y)),bar_size)
	return {"text":display_text,"name_rect":rect,"health_rect":health,"baseline":rect.position+Vector2(0,world.font.get_ascent(font_size)),"font_size":font_size,"head":head}
func passage_layout(route: Dictionary) -> Dictionary:
	var at: Vector2=(Vector2(route.cell[0],route.cell[1])*ClassicPlayer.CELL+Vector2(24,16)-world.camera)*world.zoom
	var text: String=world.resources.connections.title(route,world.resources)
	var font_size:=int(14*world.display_density)
	var width: float=world.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline: Vector2=at+Vector2(-width/2,22*world.display_density)
	return {"at":at,"text":text,"size":font_size,"baseline":baseline,"rect":Rect2(baseline-Vector2(0,world.font.get_ascent(font_size)),Vector2(width,world.font.get_height(font_size)))}
func passage_at(point: Vector2) -> Dictionary:
	for route in world.resources.connections.nearby(world.player.cell):
		if passage_layout(route).rect.has_point(point):return route
	return {}
func _draw() -> void:
	if world==null or world.metadata.is_empty():return
	var viewport:=Rect2(Vector2.ZERO,world.view_size).grow(80)
	for route in world.resources.connections.nearby(world.player.cell):
		var info:=passage_layout(route)
		var at: Vector2=info.at
		var color:=Color("bce2e3") if route.kind=="reference" else Color("e2bc70")
		var diamond:=PackedVector2Array([at+Vector2(0,-5),at+Vector2(9,0),at+Vector2(0,5),at+Vector2(-9,0),at+Vector2(0,-5)])
		draw_polyline(diamond,color,2*world.display_density)
		draw_string_outline(world.font,info.baseline,info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,info.size,2*int(world.display_density),Color.BLACK)
		draw_string(world.font,info.baseline,info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,info.size,color)
	for entity in world.entities:
		if entity.get("hp",1)<=0 or EditionCreatures.underground(entity):continue
		var info:=layout(entity)
		if not viewport.intersects(info.name_rect):continue
		var color:=Color.GOLD if entity.get("kind")=="npc" else Color.LIGHT_GREEN
		draw_string_outline(world.font,info.baseline,info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,info.font_size,maxi(2,int(world.display_density*2)),Color(0,0,0,0.95))
		draw_string(world.font,info.baseline,info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,info.font_size,color)
		if world.player_alive and entity.get("kind")=="npc" and world.task_markers.has(entity.id):
			var marker: String=world.task_markers[entity.id]
			var symbol: String="?" if marker=="可交付" else "!" if marker=="可接取" else "◆"
			var size:=int(24*world.display_density)
			var width: float=world.font.get_string_size(symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			var top: float=info.health_rect.position.y if info.health_rect.has_area() else info.head.y
			var center:=Vector2(info.head.x,top-17*world.display_density)
			var point:=center+Vector2(-width/2,world.font.get_ascent(size)-world.font.get_height(size)/2)
			var marker_color:=Color("8ce8d0") if marker=="可交付" else Color("ffd45e") if marker=="可接取" else Color("afc8dd")
			draw_circle(center,14*world.display_density,Color("231d16"))
			draw_circle(center,12*world.display_density,marker_color)
			draw_string_outline(world.font,point,symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(1,int(world.display_density)),Color("231d16"))
			draw_string(world.font,point,symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("231d16"))
		if info.health_rect.has_area():
			var bar: Rect2=info.health_rect
			draw_rect(bar.grow(world.display_density),Color(0,0,0,0.8))
			draw_rect(bar,Color(0.2,0,0))
			bar.size.x*=clampf(float(entity.hp)/maxf(1,float(entity.get("max_hp",entity.hp))),0,1)
			draw_rect(bar,Color(0.75,0.12,0.08))
