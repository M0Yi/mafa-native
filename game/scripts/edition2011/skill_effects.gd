extends Node2D
# Frame ranges: mirgo/cmd/client/magiceffect.go; sprite hotspots from client metadata.
# Do not center tall spell textures: lightning is ~958px high and anchored near its bottom.
const PROFILES={
 "beam":{"bank":"magic","start":970,"count":10,"step":0.08,"directional":true},
 "manafire":{"bank":"magic2","start":140,"count":6,"step":0.08,"provenance":"mirgo_mt14_thunder2_adaptation"},
 "poison":{"bank":"magic","start":770,"count":10,"step":0.05},
 "armor":{"bank":"magic","start":1160,"count":10,"step":0.08,"ground":true},
 "ghostshield":{"bank":"magic","start":1160,"count":10,"step":0.08,"ground":true},
 "bigfireball":{"bank":"magic","start":570,"count":10,"step":0.05},
 "fireball":{"bank":"magic","start":170,"count":10,"step":0.05},
 "lightning":{"bank":"magic2","start":10,"count":6,"step":0.08},
 "heal":{"bank":"magic","start":370,"count":10,"step":0.05},
 "talisman":{"bank":"magic","start":1160,"count":10,"step":0.08},
 "explosion":{"bank":"magic","start":1660,"count":20,"step":0.08},
 "groupheal":{"bank":"magic","start":1800,"count":10,"step":0.08},
 "blizzard":{"bank":"magic","start":3850,"count":20,"step":0.08}
}
const PROJECTILES={"fireball":10,"bigfireball":410}
const MELEE={"thrust":1410,"halfmoon":1700,"flame":3480}
var melee_id:=""
var ground_layer
var app
var events: Array=[]
var flights: Array=[]
func _ready() -> void:
 var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 ground_layer=preload("res://scripts/edition2011/skill_ground_layer.gd").new()
 ground_layer.effects=self;ground_layer.material=blend
 ground_layer.z_as_relative=false;ground_layer.z_index=0;add_child(ground_layer)
static func frame_index(id: String,age: float) -> int:
 if not PROFILES.has(id) or age<0:return -1
 var p: Dictionary=PROFILES[id]
 var index:=int(floor((age+0.0000001)/float(p.step)))
 return int(p.start)+index if index<int(p.count) else -1
func add(id: String,at: Vector2) -> void:
 if not PROFILES.has(id) or PROFILES[id].get("directional",false):return
 events.append({"id":id,"at":at,"time":app.elapsed,"map":app.world.metadata.id})
 queue_redraw()
func launch_beam(target: Dictionary) -> void:
 var start: Vector2=app.world.player.anchor
 var finish: Vector2=app.world.actors.anchor(target)
 events.append({"id":"beam","at":start,"time":app.elapsed+0.12,"map":app.world.metadata.id,"direction":direction16(finish-start)})
 queue_redraw()
static func direction16(delta: Vector2) -> int:
 if delta.x==0:return 0 if delta.y<0 else 8
 if delta.y==0:return 4 if delta.x>0 else 12
 var slope:=absf(delta.y/delta.x)
 var steps:=int(slope>0.25)+int(slope>1.0/1.9)+int(slope>1.4)+int(slope>4.0)
 if delta.x>0:return 4+steps if delta.y>0 else 4-steps
 return 12-steps if delta.y>0 else (12+steps)%16
static func flight_frame(direction: int,age: float,id: String="fireball") -> int:
 if not PROJECTILES.has(id) or age<0 or age+0.0000001>=0.3:return -1
 return int(PROJECTILES[id])+posmod(direction,16)*10+mini(5,int(floor((age+0.0000001)/0.05)))
func launch_projectile(id: String,target: Dictionary) -> void:
 if not PROJECTILES.has(id):return
 var start: Vector2=app.world.player.anchor
 var finish: Vector2=app.world.actors.anchor(target)
 flights.append({"id":id,"from":start,"to":finish,"time":app.elapsed+0.12,"map":app.world.metadata.id,"direction":direction16(finish-start),"target":target.id,"generation":target.generation})
static func melee_frame(id: String,direction: int,age: float) -> int:
 if not MELEE.has(id) or age<0:return -1
 var action: Dictionary=EditionAnimation.HUMAN[EditionSkills.DEFINITIONS[id].action]
 if age+0.0000001>=float(action.count)*float(action.ms)/1000:return -1
 var relative:=EditionAnimation.index(action,0,age)-int(action.start)
 return int(MELEE[id])+posmod(direction,8)*10+relative
func clear() -> void:
 events.clear();flights.clear();melee_id="";queue_redraw()
 if is_instance_valid(ground_layer):ground_layer.queue_redraw()
func _process(_delta: float) -> void:
 if app==null or app.mode!="game":return
 if not melee_id.is_empty() and (app.world.motion_left<=0 or app.world.motion_override!=EditionSkills.DEFINITIONS[melee_id].action or app.rules.state.hp<=0):melee_id=""
 flights=flights.filter(func(e):return e.map==app.world.metadata.id and app.elapsed-float(e.time)+0.0000001<0.3)
 events=events.filter(func(e):return e.map==app.world.metadata.id and (app.elapsed<float(e.time) or frame_index(e.id,app.elapsed-float(e.time))>=0))
 queue_redraw()
 if is_instance_valid(ground_layer):ground_layer.queue_redraw()
func _draw() -> void:
 if app==null or app.mode!="game":return
 if not melee_id.is_empty() and app.world.motion_left>0 and app.rules.state.hp>0 and app.world.motion_override==EditionSkills.DEFINITIONS[melee_id].action:
  var index:=melee_frame(melee_id,app.world.player.direction,app.world.motion_duration-app.world.motion_left)
  if index>=0:paint("magic",index,app.world.player.anchor)
 for flight in flights:
  var age: float=app.elapsed-float(flight.time)
  var index:=flight_frame(flight.direction,age,flight.get("id","fireball"))
  if flight.map!=app.world.metadata.id or index<0:continue
  for entity in app.world.entities:
   if entity.id==flight.target and entity.generation==flight.generation and entity.hp>0:
    flight.to=app.world.actors.anchor(entity);break
  flight.direction=direction16(flight.to-flight.from)
  index=flight_frame(flight.direction,age,flight.get("id","fireball"))
  paint("magic",index,flight.from.lerp(flight.to,clampf(age/0.3,0,1)))
 for event in events:
  if PROFILES[event.id].get("ground",false):continue
  var index:=frame_index(event.id,app.elapsed-float(event.time))
  if event.map!=app.world.metadata.id or index<0:continue
  if PROFILES[event.id].get("directional",false):index+=int(event.direction)*10
  paint(PROFILES[event.id].bank,index,event.at)
 if app.rules.state.hp>0 and float(app.rules.state.get("shield_until",0))>app.elapsed:
  var struck: bool=app.world.motion_override=="hurt" and app.world.motion_left>0
  paint("magic",(3900 if struck else 3890)+int(app.elapsed*10)%3,app.world.player.anchor)
func paint(bank: String,index: int,at: Vector2) -> void:
 var frame: Dictionary=app.resources.frame(bank,index)
 if not frame.is_empty():draw_texture(frame.texture,(at+frame.offset).round())

func draw_ground(canvas: CanvasItem) -> void:
 if app==null or app.mode!="game":return
 for event in events:
  if not PROFILES[event.id].get("ground",false) or event.map!=app.world.metadata.id:continue
  var index:=frame_index(event.id,app.elapsed-float(event.time))
  if index<0:continue
  var frame: Dictionary=app.resources.frame(PROFILES[event.id].bank,index)
  if not frame.is_empty():canvas.draw_texture(frame.texture,(event.at+frame.offset).round())
