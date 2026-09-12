class_name ClassicWorld
extends Node2D

var trial: ClassicTrial
var actor_font := SystemFont.new()
var resources: ClassicResources
var player: ClassicPlayer
var tiles_by_row: Dictionary = {}
var objects_by_row: Dictionary = {}
var viewport_size := Vector2(1280,800)
var time := 0.0
var zoom_level := 2
var camera := Vector2.ZERO
var show_collision := false
var target := Vector2i(-1,-1)
var map_size := Vector2i.ZERO

func configure(data: ClassicResources, actor: ClassicPlayer) -> void:
	resources = data
	player = actor
	map_size = Vector2i(int(data.map["size"][0]),int(data.map["size"][1]))
	actor_font.font_names = PackedStringArray(["PingFang SC","Heiti SC"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for tile in data.map.tiles:
		var row := int(tile[1])
		if not tiles_by_row.has(row): tiles_by_row[row] = []
		tiles_by_row[row].append(tile)
	for object in data.map.objects:
		var row := int(object[1])
		if not objects_by_row.has(row): objects_by_row[row] = []
		objects_by_row[row].append(object)

func update_view(delta: float, window: Vector2, level: int) -> void:
	time += delta
	viewport_size = window
	zoom_level = level
	var visible := window / float(level)
	var center := player.anchor + Vector2(24,16)
	var extent := Vector2(map_size)*ClassicPlayer.CELL
	camera = (center-visible/2.0).clamp(Vector2.ZERO,(extent-visible).max(Vector2.ZERO)).round()
	scale = Vector2.ONE*level
	position = -camera*level
	queue_redraw()

func cell_at_screen(point: Vector2) -> Vector2i:
	return Vector2i(((point-position)/float(zoom_level)/ClassicPlayer.CELL).floor())

func screen_for_cell(cell: Vector2i) -> Vector2:
	return (Vector2(cell)*ClassicPlayer.CELL+Vector2(24,16))*zoom_level+position

func paint_texture(entry: Array, at: Vector2, color := Color.WHITE) -> void:
	var region := Rect2(float(entry[1]),float(entry[2]),float(entry[3]),float(entry[4]))
	draw_texture_rect_region(resources.atlases[int(entry[0])],Rect2(at.round(),region.size),region,color)

func paint_object(object: Array) -> void:
	var key := int(object[2])
	if int(object[5]) > 1:
		key += int(time* (10.0 / (float(object[6])+1.0))) % int(object[5])
	var entry: Array = resources.map.textures[str(key)]
	var at := Vector2(float(object[0])*48,(float(object[1])+1)*32-float(entry[4]))
	paint_texture(entry,at,Color(1,1,1,96.0/255.0 if bool(object[4]) else 1.0))

func paint_player() -> void:
	var action := player.action
	var frame := player.frame()
	if trial != null and trial.enabled and trial.cast_time > 0:
		action = trial.action
		var count: int = resources.hero.actions[action][player.direction].size()
		frame = clampi(int((1.0-trial.cast_time/0.45)*count),0,count-1)
	var layers: Array = resources.hero.actions[action][player.direction][frame]
	for layer in layers:
		var offset := Vector2(float(layer.offset[0]),float(layer.offset[1]))
		paint_texture(layer.texture,player.anchor+offset,Color(1,1,1,0.5 if layer.shadow else (0.35 if trial != null and trial.buffs.has("隐身") else 1.0)))

func _draw() -> void:
	if resources == null:
		return
	var start_x := maxi(0,int(camera.x/48)-12)
	var end_x := mini(map_size.x,int((camera.x+viewport_size.x/zoom_level)/48)+12)
	var start_y := maxi(0,int(camera.y/32)-4)
	# Tall tree/building sprites are bottom anchored; include rows below the view.
	var end_y := mini(map_size.y,int((camera.y+viewport_size.y/zoom_level)/32)+24)
	for y in range(start_y-start_y%2,end_y,2):
		for tile in tiles_by_row.get(y,[]):
			if int(tile[0]) >= start_x-2 and int(tile[0]) <= end_x:
				paint_texture(resources.map.textures[str(int(tile[2]))],Vector2(float(tile[0])*48,float(tile[1])*32))
	for y in range(start_y,end_y):
		for object in objects_by_row.get(y,[]):
			if int(object[3]) == 0 and int(object[0]) >= start_x and int(object[0]) <= end_x:
				paint_object(object)
	if trial != null and trial.enabled: paint_effects(true,-1)
	if show_collision:
		for y in range(start_y,mini(end_y,map_size.y)):
			for x in range(start_x,end_x):
				if not player.nav.walkable(Vector2i(x,y)):
					draw_rect(Rect2(x*48,y*32,48,32),Color(0.8,0.1,0.05,0.25))
	if target.x >= 0 and player.route.size() > 0:
		var p := Vector2(target)*ClassicPlayer.CELL+Vector2(24,16)
		draw_arc(p,9,0,TAU,24,Color(0.95,0.8,0.42,0.9),1.0)
		draw_line(p-Vector2(13,0),p+Vector2(13,0),Color(0.95,0.8,0.42,0.7))
	var actor_row := int((player.anchor.y+16)/32)
	for y in range(start_y,end_y):
		var objects: Array = objects_by_row.get(y,[])
		for object in objects:
			if int(object[3]) == 1 and int(object[0]) >= start_x and int(object[0]) <= end_x:
				paint_object(object)
		if trial != null and trial.enabled:
			for actor in trial.actors:
				if int((actor.anchor.y+16)/32)==y: paint_actor(actor)
		if y == actor_row:
			paint_player()
			if trial != null and trial.buffs.has("魔法盾"): paint_shield()
		if trial != null and trial.enabled: paint_effects(false,y)
		for object in objects:
			if int(object[3]) == 2 and int(object[0]) >= start_x and int(object[0]) <= end_x:
				paint_object(object)
	for y in range(start_y,end_y):
		for object in objects_by_row.get(y,[]):
			if int(object[3]) == 3 and int(object[0]) >= start_x and int(object[0]) <= end_x:
				paint_object(object)

func paint_actor(actor: Dictionary) -> void:
	var directions: Array=resources.skills.actors[actor.kind][actor.action]
	var frames: Array=directions[actor.direction]
	var index:=int(actor.anim*8.0)%frames.size()
	if actor.action in ["die","hit"]:index=mini(frames.size()-1,int(actor.anim*8.0))
	if actor.action=="attack":index=mini(frames.size()-1,int(actor.anim/0.6*frames.size()))
	for layer in frames[index]:
		var color:=Color.WHITE
		if actor.statuses.has("绿毒"):color=Color(0.5,1,0.5)
		if actor.statuses.has("红毒"):color=Color(1,0.5,0.5)
		if layer.get("shadow",false):color.a=0.45
		if actor.statuses.has("隐身"):color.a*=0.35
		paint_texture(layer.texture,actor.anchor+Vector2(layer.offset[0],layer.offset[1]),color)
	if actor.hp<=0:return
	var at: Vector2=actor.anchor+Vector2(2,-54)
	draw_rect(Rect2(at,Vector2(44,4)),Color(0.12,0.08,0.06,0.9))
	draw_rect(Rect2(at,Vector2(44*actor.hp/actor.max_hp,4)),Color("91bb70") if actor.ally else Color("bd5347"))
	var name: String={"chicken":"鸡","skeleton":"骷髅","pet_skeleton":"召唤骷髅","beast":"神兽"}[actor.kind]
	if actor.statuses.has("洞察"):name+=" %d" % actor.hp
	if actor.statuses.has("禁锢"):name+=" · 禁锢"
	draw_string(actor_font,at+Vector2(-3,-4),name,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("eee0bb"))

func paint_effects(ground: bool,row: int) -> void:
	for e in trial.effects:
		if bool(e.gfx.ground)!=ground:continue
		var at: Vector2=Vector2(e.at).lerp(e.end,minf(1,e.time/e.duration))
		if not ground and int((at.y+16)/32)!=row:continue
		var directions: Array=e.gfx.frames
		var d:=int(e.direction)*2 if directions.size()==16 else int(e.direction)
		var frames: Array=directions[d%directions.size()]
		var f:=int(e.time/0.075)%frames.size()
		if not e.gfx.loop:f=mini(frames.size()-1,int(e.time/e.duration*frames.size()))
		var frame: Dictionary=frames[f]
		paint_texture(frame.texture,at+Vector2(frame.offset[0],frame.offset[1]))

func paint_shield() -> void:
	var s:=trial.find_skill("魔法盾")
	var g: Dictionary=s.gfx.get("持续",s.gfx["运行"])
	var frames: Array=g.frames[0]
	var frame: Dictionary=frames[int(time*8)%frames.size()]
	paint_texture(frame.texture,player.anchor+Vector2(frame.offset[0],frame.offset[1]))

func hit_layers(layers: Array, anchor: Vector2, point: Vector2) -> bool:
	for layer in layers:
		if layer.get("shadow",false):continue
		var rect:=Rect2(anchor+Vector2(layer.offset[0],layer.offset[1]),Vector2(layer.texture[3],layer.texture[4]))
		if rect.has_point(point):return true
	return false

func aim_at_screen(point: Vector2) -> Vector2i:
	var local: Vector2=(point-position)/float(zoom_level)
	var picked: Dictionary={}
	if trial != null and trial.enabled:
		for actor in trial.actors:
			if actor.hp<=0:continue
			var frames: Array=resources.skills.actors[actor.kind][actor.action][actor.direction]
			var layers: Array=frames[mini(frames.size()-1,int(actor.anim*8)%frames.size())]
			var label:=Rect2(actor.anchor+Vector2(0,-69),Vector2(48,19))
			if hit_layers(layers,actor.anchor,local) or label.has_point(local):
				if picked.is_empty() or actor.anchor.y>=picked.anchor.y:picked=actor
		if not picked.is_empty():return picked.cell
	if hit_layers(resources.hero.actions[player.action][player.direction][player.frame()],player.anchor,local):
		return player.cell
	return cell_at_screen(point)
