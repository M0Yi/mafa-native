class_name EditionWorld
extends Node2D

signal clicked_entity(entity: Dictionary)
signal moved(cell: Vector2i)
signal actor_sound(id: int,at: Vector2,event: String)
signal monster_hit(entity: Dictionary,damage: int)
signal monster_hit_traveler(target: Dictionary,attack: Dictionary)
var actors:=EditionActors.new()
var party: Array=[]
var player_alive:=true
var player_stoned:=false
var task_markers: Dictionary={}
var resources: EditionResources
var player:=ClassicPlayer.new()
var controller_allowed:=true
var navigation:=ClassicNavigation.new()
var metadata: Dictionary={}
var camera:=Vector2.ZERO
var cinematic_pan:=Vector2.ZERO
var zoom:=2.0
var display_density:=1.0
var actor_bounds_cache: Dictionary={}
var corpse_frame_cache: Dictionary={}
var monster_effects:=preload("res://scripts/edition2011/monster_effects.gd").new()
var labels:=preload("res://scripts/edition2011/actor_labels.gd").new()
var preferred_zoom:=0
var light_layer:=preload("res://scripts/edition2011/light_layer.gd").new()
var view_size:=Vector2(1280,800)
var map_file: FileAccess
var chunks: Dictionary={}
var entities: Array=[]
var elapsed:=0.0
var gender:="男"
var motion_override:=""
var motion_left:=0.0
var motion_duration:=0.6
var equipment: Dictionary={}
var weapon_order: Dictionary={}
var font:=SystemFont.new()
var paused:=false
var last_steps:=0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font.font_names=PackedStringArray(["PingFang SC","Heiti SC"])
	player.nav=navigation;actors.world=self
	player.step_filter=actors.player_can_step
	player.route_replanner=replan_player_route
	weapon_order=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/weapon-order.json")).tables
	add_child(light_layer)
	monster_effects.world=self;add_child(monster_effects)
	labels.world=self;add_child(labels)

func enter_map(id: String,position_cell: Vector2i=Vector2i(-1,-1)) -> bool:
	if not resources.map_by_id.has(id):return false
	metadata=resources.map_by_id[id]
	if not metadata.has("spawn"):return false
	var w:=int(metadata.width);var h:=int(metadata.height)
	var mask:=FileAccess.get_file_as_bytes(EditionResources.BASE+"maps/"+id+".walk")
	if mask.size()!=w*h:return false
	var rows: Array=[]
	for y in range(h):rows.append(mask.slice(y*w,(y+1)*w))
	navigation.configure({"size":[w,h],"walkable":rows})
	map_file=FileAccess.open(EditionResources.BASE+"maps/"+id+".mapbin",FileAccess.READ)
	if map_file==null:return false
	chunks.clear();resources.clear_scene_cache();monster_effects.queue_redraw()
	if position_cell==Vector2i(-1,-1):position_cell=EditionVillage.SPAWN if id=="0" else Vector2i(metadata.spawn[0],metadata.spawn[1])
	if not navigation.mobile(position_cell):
		position_cell=navigation.nearest_mobile(position_cell)
	if position_cell==Vector2i(-1,-1):position_cell=EditionVillage.SPAWN if id=="0" else Vector2i(metadata.spawn[0],metadata.spawn[1])
	player.reset(position_cell);last_steps=player.completed_steps
	motion_override="";motion_left=0
	resources.connections.enter(id,player)
	entities=[];actors.reset()
	update_camera(view_size)
	queue_redraw();return true

func cell_data(x: int,y: int) -> PackedByteArray:
	if x<0 or y<0 or x>=int(metadata.width) or y>=int(metadata.height):return PackedByteArray()
	var cx:=x/32;var cy:=y/32;var key:=Vector2i(cx,cy)
	var stride:=int(metadata.stride)
	if not chunks.has(key):
		var cw:=mini(32,int(metadata.width)-cx*32);var ch:=mini(32,int(metadata.height)-cy*32)
		var block:=PackedByteArray()
		for row in range(ch):
			map_file.seek(12+((cy*32+row)*int(metadata.width)+cx*32)*stride)
			block.append_array(map_file.get_buffer(cw*stride))
		chunks[key]={"bytes":block,"width":cw}
		if chunks.size()>48:
			for k in chunks.keys():
				if (k-key).length()>3:chunks.erase(k)
	var entry: Dictionary=chunks[key]
	var start:=((y%32)*int(entry.width)+x%32)*stride
	return entry.bytes.slice(start,start+stride)

func point_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(((point/float(zoom)+camera)/ClassicPlayer.CELL).floor())

func register_npc_collision() -> void:
	var occupied: Array[Vector2i]=[]
	var reserved: Array=resources.connections.landing_cells.get(str(metadata.id),[]).duplicate()
	for route in resources.connections.routes:reserved.append(Vector2i(route.cell[0],route.cell[1]))
	for entity in entities:
		if entity.kind!="npc":continue
		var at:=Vector2i(entity.cell[0],entity.cell[1])
		if entity.get("fixed_reference_position",false):
			occupied.append(at);navigation.set_occupied(occupied);continue
		# Keep doorway approaches clear; do not punch holes in the map's walls.
		if not navigation.walkable(at) or at in reserved or navigation.would_disconnect(at):
			var found:=false
			for radius in range(1,16):
				for y in range(at.y-radius,at.y+radius+1):
					for x in range(at.x-radius,at.x+radius+1):
						var candidate:=Vector2i(x,y)
						if navigation.walkable(candidate) and candidate not in reserved and not navigation.path(at if navigation.walkable(at) else player.cell,candidate).is_empty() and not navigation.would_disconnect(candidate):
							at=candidate;found=true;break
					if found:break
				if found:break
			entity.cell=[at.x,at.y]
		occupied.append(at)
		navigation.set_occupied(occupied)
	navigation.set_occupied(occupied)
	if not navigation.mobile(player.cell):
		var recovered:=navigation.nearest_mobile(player.cell)
		if recovered!=Vector2i(-1,-1):player.reset(recovered)
	# Old prototype saves could sit on an isolated decorative tile. Keep a valid
	# saved position; relocate only when no physical exit can be reached from it.
	var exits: Array=resources.connections.routes.duplicate()
	exits.sort_custom(func(a,b):return Vector2(a.cell[0]-player.cell.x,a.cell[1]-player.cell.y).length_squared()<Vector2(b.cell[0]-player.cell.x,b.cell[1]-player.cell.y).length_squared())
	var reachable:=false
	for route in exits:
		if navigation.mobile(player.cell) and not navigation.path(player.cell,Vector2i(route.cell[0],route.cell[1])).is_empty():reachable=true;break
	if not reachable and not exits.is_empty():
		var fallback:=Vector2i(metadata.spawn[0],metadata.spawn[1])
		for route in exits:
			var at:=Vector2i(route.cell[0],route.cell[1])
			if not navigation.path(fallback,at).is_empty():player.reset(fallback);reachable=true;break
		if not reachable:player.reset(Vector2i(exits[0].cell[0],exits[0].cell[1]))
	resources.connections.enter(str(metadata.id),player)

func replan_player_route(target: Vector2i) -> Array[Vector2i]:
	var reserved:=actors.player_reserved_cells()
	if target in reserved:return []
	var avoid: Array[Vector2i]=player.path_avoid.duplicate();avoid.append_array(reserved)
	var path:=navigation.path_avoiding(player.cell,target,avoid)
	if not path.is_empty():path.pop_front()
	return path

func approach(target: Vector2i) -> bool:
	var reserved: Array[Vector2i]=actors.player_reserved_cells()
	# Adjacent triggers into the same room are alternate entrances, not walls.
	if resources.connections.current.has(target):
		var start:=player.destination if player.progress<1 else player.cell
		var avoid: Array[Vector2i]=player.path_avoid.duplicate();avoid.append_array(reserved)
		var best:=Vector2i(-1,-1);var length:=2147483647
		for entrance in resources.connections.approach_cells(target):
			if entrance in reserved:continue
			var path:=navigation.path_avoiding(start,entrance,avoid)
			if not path.is_empty() and path.size()<length:best=entrance;length=path.size()
		if best!=Vector2i(-1,-1):return player.go_to(best,reserved)
		player.route.clear();return false
	if navigation.walkable(target) and target not in reserved:return player.go_to(target,reserved)
	var start:=player.destination if player.progress<1 else player.cell
	var avoid: Array[Vector2i]=player.path_avoid.duplicate();avoid.append_array(reserved)
	var best:=Vector2i(-1,-1);var steps:=2147483647
	var candidates: Array[Vector2i]=[]
	for direction in ClassicNavigation.DIRECTIONS:candidates.append(target+direction)
	var npc_target:=entities.any(func(e):return e.get("kind","")=="npc" and Vector2i(e.cell[0],e.cell[1])==target)
	if npc_target:candidates=ClassicNavigation.npc_approach_cells(target)
	var adjacent_found:=false
	for candidate in candidates:
		var adjacent: bool=(candidate-target).length_squared()<=2
		if not adjacent and adjacent_found:break
		if candidate in avoid:continue
		var path:=navigation.path_avoiding(start,candidate,avoid)
		if not path.is_empty() and path.size()<steps:
			best=candidate;steps=path.size();adjacent_found=adjacent
	if best.x>=0:return player.go_to(best,reserved)
	player.route.clear()
	return false

func zone_name() -> String:
	return "新手村 · 边界村" if EditionVillage.nearby(str(metadata.get("id","")),player.cell) else str(metadata.get("name",""))

func pick_entity(point: Vector2) -> Dictionary:
	var picked: Dictionary={};var depth:=-1
	for entity in entities:
		if entity.get("hp",1)<=0 or EditionCreatures.underground(entity):continue
		var at:=actors.anchor(entity)
		var bounds:=resources.frame_bounds(entity.get("bank","npc"),actor_frame(entity))
		var body:=Rect2((at+bounds.position-camera)*zoom,bounds.size*zoom)
		var caption:=labels.layout(entity)
		if body.has_point(point) or caption.name_rect.has_point(point) or caption.health_rect.has_point(point):
			if int(at.y)>=depth:picked=entity;depth=int(at.y)
	return picked

func handle_click(point: Vector2) -> void:
	if not player_alive:return
	var passage: Dictionary=labels.passage_at(point)
	if not passage.is_empty():approach(Vector2i(passage.cell[0],passage.cell[1]));return
	var cell:=point_to_cell(point)
	if resources.connections.current.has(cell):approach(cell);return
	var entity:=pick_entity(point)
	if not entity.is_empty():clicked_entity.emit(entity);return
	approach(point_to_cell(point))

func animate(action: String) -> void:
	motion_override=action
	var definition: Dictionary=EditionAnimation.HUMAN.get(action,EditionAnimation.HUMAN.attack)
	motion_duration=float(definition.count)*float(definition.ms)/1000
	motion_left=motion_duration

func update_world(delta: float,screen: Vector2,can_move: bool,pointer_allowed: bool=true) -> void:
	view_size=screen
	zoom=EditionDisplay.map_zoom(screen,preferred_zoom,display_density)
	if not metadata.has("width"):return
	if not paused:
		elapsed+=delta;motion_left=maxf(0,motion_left-delta)
		var manual:=Vector2i.ZERO
		var running:=Input.is_physical_key_pressed(KEY_SHIFT)
		if can_move:
			manual=Vector2i(int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
			if manual==Vector2i.ZERO and controller_allowed:
				for device in Input.get_connected_joypads():
					var stick:=Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))
					if stick.length()<0.3:continue
					manual=Vector2i(signf(stick.x) if absf(stick.x)>0.3 else 0,signf(stick.y) if absf(stick.y)>0.3 else 0)
					running=stick.length()>0.8;break
			if pointer_allowed and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				var target:=point_to_cell(get_global_mouse_position());manual=Vector2i(signi(target.x-player.cell.x),signi(target.y-player.cell.y));running=true
		if player_alive and not player_stoned:player.update(delta,manual,running)
		if last_steps!=player.completed_steps:last_steps=player.completed_steps;moved.emit(player.cell)
	actors.update(delta,party)
	update_camera(screen)
	monster_effects.queue_redraw()
	queue_redraw()

func update_camera(screen: Vector2) -> void:
	var visible:=screen/float(zoom)
	camera=(player.anchor+Vector2(24,16)+cinematic_pan-visible/2).clamp(Vector2.ZERO,(Vector2(metadata.width,metadata.height)*ClassicPlayer.CELL-visible).max(Vector2.ZERO)).round()
	scale=Vector2.ONE*zoom;position=-camera*zoom

func sprite(bank: String,index: int,at: Vector2,offsets: bool=true,color:=Color.WHITE) -> void:
	var image:=resources.frame(bank,index)
	if image.is_empty():return
	draw_texture(image.texture,(at+(image.offset if offsets else Vector2.ZERO)).round(),color)

func human_frame(entity: Dictionary) -> int:
	var motion:=actors.mover(entity)
	if int(entity.get("hp",1))<=0:
		var death: Dictionary=EditionAnimation.HUMAN.die
		return int(death.start)+motion.direction*8+mini(int(death.count)-1,int(maxf(0,elapsed-float(entity.get("motion_time",0)))*1000/float(death.ms)))
	var action: Dictionary=EditionAnimation.HUMAN.get(motion.action,EditionAnimation.HUMAN.stand)
	return int(action.start)+motion.direction*8+motion.frame()

func visible_corpse_frame(bank: String,profile: Dictionary,direction: int,time: float) -> int:
	var corpse: Dictionary=profile.actions.get("corpse",{})
	if int(corpse.get("count",0))<=0:return -1
	var declared:=int(profile.base)+EditionAnimation.index(corpse,direction,time)
	var death: Dictionary=profile.actions.get("die",{})
	var key:=bank+":"+str(declared)+":"+str(profile.base)+":"+str(direction)+":"+str(death)
	if corpse_frame_cache.has(key):return int(corpse_frame_cache[key])
	var image: Dictionary=resources.frame(bank,declared)
	if image.get("body_visible",false):corpse_frame_cache[key]=declared;return declared
	# Empty corpse slots occur in the supplied client. Keep the last visible
	# frame of this direction's death sequence until the normal corpse timeout.
	for i in range(int(death.get("count",0))-1,-1,-1):
		var candidate:=int(profile.base)+int(death.get("start",0))+direction*(int(death.get("count",0))+int(death.get("skip",0)))+i
		image=resources.frame(bank,candidate)
		if image.get("body_visible",false):corpse_frame_cache[key]=candidate;return candidate
	corpse_frame_cache[key]=-1
	return -1

func actor_frame(entity: Dictionary) -> int:
	if entity.get("centipede_phase","")=="hidden" and int(entity.get("hp",1))>0:return -1
	if int(entity.get("hp",1))>0 and entity.get("centipede_phase","") in ["emerging","receding"]:
		var phase_action: String="walk" if entity.centipede_phase=="emerging" else "corpse"
		return int(entity.profile.base)+EditionAnimation.index(entity.profile.actions[phase_action],0,maxf(0,elapsed-float(entity.motion_time)))
	if entity.kind=="traveler":
		var sex:=1 if entity.get("gender","男")=="女" else 0
		var armor: Dictionary=EditionRules.ITEMS.get(entity.get("equipment",{}).get("armor",""),{})
		var dress:=(int(armor.get("shape",0))*2+sex)*600
		return dress+human_frame(entity)
	var profile:=EditionCreatures.profile(entity)
	if not profile.is_empty():
		var action: String=entity.get("motion","stand")
		var time:=maxf(0,elapsed-float(entity.get("motion_time",0)))
		if entity.hp<=0:
			if entity.has("spawn_id") and time>float(EditionRegion.data().monster_settings.corpseDelay)/1000:return -1
			var death: Dictionary=profile.actions.die
			action="die" if time<float(death.count)*float(death.ms)/1000 else "corpse"
		elif action not in ["hurt","attack"] or time>= EditionCreatures.duration(entity,action,0.2 if action=="hurt" else 0.6):
			var motion:=actors.mover(entity);action=motion.action;time=motion.elapsed
		var definition: Dictionary=EditionCreatures.action(entity,action)
		if definition.is_empty():definition=profile.actions.stand
		if int(definition.count)<=0:return -1
		if action=="corpse":return visible_corpse_frame(str(entity.bank),profile,EditionCreatures.body_direction(entity),time)
		return int(profile.base)+EditionAnimation.index(definition,EditionCreatures.body_direction(entity),time)
	return int(entity.get("frame",0))+int(elapsed*1000.0/maxf(1.0,float(entity.get("frame_ms",250))))%maxi(1,int(entity.get("frames",1)))

func actor_idle_bounds(entity: Dictionary,head_only:=false) -> Rect2:
	var bank: String=entity.get("bank","npc")
	var first:=int(entity.get("frame",0));var count:=maxi(1,int(entity.get("frames",1)))
	if entity.kind=="traveler":
		var sex:=1 if entity.get("gender","男")=="女" else 0
		var armor: Dictionary=EditionRules.ITEMS.get(entity.get("equipment",{}).get("armor",""),{})
		first=(int(armor.get("shape",0))*2+sex)*600+int(entity.get("direction",4))*8;count=4
	elif not EditionCreatures.profile(entity).is_empty():
		var profile:=EditionCreatures.profile(entity);var action: Dictionary=profile.actions.stand
		first=int(profile.base)+int(action.start)+EditionCreatures.body_direction(entity)*(int(action.count)+int(action.skip));count=int(action.count)
	var key:=bank+":"+str(first)+":"+str(count)+(":head" if head_only else "")
	if not actor_bounds_cache.has(key):
		var bounds:=Rect2()
		for index in range(first,first+count):
			var part:=resources.frame_bounds(bank,index)
			if head_only:
				var frame: Dictionary=resources.frame(bank,index)
				if frame.is_empty():continue
				var image: Image=frame.texture.get_image()
				var top:=-1;var left:=image.get_width();var right:=-1
				# The archive rectangle includes cast shadows and transparent padding.
				# Only the upper opaque silhouette defines the head center.
				for y in range(image.get_height()):
					if top>=0 and y>top+maxi(4,int(image.get_height()*0.22)):break
					for x in range(image.get_width()):
						if image.get_pixel(x,y).a<0.5:continue
						if top<0:top=y
						left=mini(left,x);right=maxi(right,x)
				if top<0:continue
				part=Rect2(frame.offset+Vector2(left,top),Vector2(right-left+1,1))
			bounds=part if not bounds.has_area() else bounds.merge(part)
		if not bounds.has_area():bounds=resources.frame_bounds(bank,first)
		actor_bounds_cache[key]=bounds
	return actor_bounds_cache[key]

func paint_actor(entity: Dictionary) -> void:
	var at:=actors.anchor(entity)
	if entity.kind=="traveler":
		paint_human(at,1 if entity.get("gender","男")=="女" else 0,entity.get("equipment",{}),human_frame(entity))
	else:sprite(entity.get("bank","npc"),actor_frame(entity),at)

func paint_player() -> void:
	var sex:=1 if gender=="女" else 0
	var motion: String="die" if not player_alive else motion_override if motion_left>0 else player.action
	var action: Dictionary=EditionAnimation.HUMAN.get(motion,EditionAnimation.HUMAN.stand)
	var time:=0.479 if not player_alive else motion_duration-motion_left if motion_left>0 else player.elapsed
	var frame_index:=EditionAnimation.index(action,player.direction,time)
	if motion_left<=0 and motion in ["walk","run"]:
		frame_index=int(action.start)+player.direction*8+player.frame()%6
	paint_human(player.anchor,sex,equipment,frame_index)

func paint_human(at: Vector2,sex: int,gear: Dictionary,frame_index: int) -> void:
	var armor: Dictionary=EditionRules.ITEMS.get(gear.get("armor",""),{})
	var dress:=(int(armor.get("shape",1 if gear.get("armor")=="robe" else 0))*2+sex)*600
	var weapon:=-1
	var blade: Dictionary=EditionRules.ITEMS.get(gear.get("weapon",""),{})
	if not blade.is_empty():weapon=(int(blade.get("shape",1 if gear.get("weapon")=="wood_sword" else 2))*2+sex)*600+frame_index
	var order: Array=weapon_order.get("worderFemale" if sex==1 else "worderMale",[])
	var front: bool=frame_index<order.size() and order[frame_index]==1
	if weapon>=0 and not front:sprite("weapon",weapon,at)
	sprite("hum",dress+frame_index,at)
	sprite("hair",(2+sex)*600+frame_index,at)
	if weapon>=0 and front:sprite("weapon",weapon,at)


func front_position(cell: Vector2i,frame: Dictionary,additive: bool) -> Vector2:
	# Blend objects use WIL hotspots (mirgo sceneplay.go / PlayScn.pas),
	# while normal buildings are bottom-aligned to their map cell.
	if additive:return Vector2(cell)*ClassicPlayer.CELL+frame.offset-Vector2(2,68)
	return Vector2(cell.x*48,(cell.y+1)*32)-Vector2(0,frame.size.y)

func _draw() -> void:
	if resources==null or metadata.is_empty():return
	var x0:=maxi(0,int(camera.x/48)-5);var x1:=mini(int(metadata.width),int((camera.x+view_size.x/zoom)/48)+6)
	var y0:=maxi(0,int(camera.y/32)-3);var y1:=mini(int(metadata.height),int((camera.y+view_size.y/zoom)/32)+18)
	if metadata.id==EditionFireDragon.MAP:
		var bounds:=EditionFireDragon.RENDER_BOUNDS
		x0=maxi(x0,bounds.position.x);x1=mini(x1,bounds.end.x);y0=maxi(y0,bounds.position.y);y1=mini(y1,bounds.end.y)
	var objects: Dictionary={}
	light_layer.commands.clear()
	for y in range(y0,y1):
		objects[y]=[]
		for x in range(x0,x1):
			var cell:=cell_data(x,y)
			if cell.size()<12:continue
			var back:=int(cell.decode_u16(0))&0x7fff;var middle:=int(cell.decode_u16(2))&0x7fff;var front:=int(cell.decode_u16(4))&0x7fff
			if x%2==0 and y%2==0 and back>0:
				var bank:="tiles2" if cell.size()==14 and cell[12]>0 else "tiles"
				sprite(bank,back-1,Vector2(x*48,y*32),false)
			if middle>0:
				var middle_bank:="smtiles"+(str(int(cell[13])+1) if cell.size()==14 and cell[13]>0 else "")
				sprite(middle_bank,middle-1,Vector2(x*48,y*32),false)
			if front>0:
				var bank:="objects"+str(int(cell[10])+1) if cell[10]>0 else "objects"
				var animated:=int(cell[8])&0x7f
				var frame_index:=front-1+(int(elapsed*10.0/(int(cell[9])+1))%animated if animated>0 else 0)
				var im:=resources.frame(bank,frame_index)
				if not im.is_empty():
					var at:=front_position(Vector2i(x,y),im,(cell[8]&0x80)!=0)
					if cell[8]&0x80:light_layer.commands.append([im.texture,at])
					elif im.size.y<=32:draw_texture(im.texture,at)
					else:objects[y].append([im.texture,at])
	for y in range(y0,y1):
		for obj in objects[y]:draw_texture(obj[0],obj[1])
		for entity in entities:
			if int(actors.anchor(entity).y/32)==y:paint_actor(entity)
		if int(player.anchor.y/32)==y:paint_player()
	EditionDragonAttack.draw_warning(self)
	light_layer.queue_redraw()
	labels.queue_redraw()
