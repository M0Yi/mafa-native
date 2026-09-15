extends SceneTree
const Effects=preload("res://scripts/edition2011/skill_effects.gd")
func _initialize():call_deferred("run")
func run():
 assert(EditionWorld.poison_tint({"hp":1,"poison_until":10},9)==Color(0.3,1,0.3))
 assert(EditionWorld.poison_tint({"hp":1,"poison_until":10},10)==Color.WHITE)
 assert(EditionWorld.poison_tint({"hp":0,"poison_until":10},9)==Color.WHITE)
 assert(EditionWorld.poison_tint({"hp":1,"green_poison":{"until":10}},9)==Color(0.3,1,0.3))
 assert(EditionWorld.poison_tint({"hp":1},9)==Color.WHITE)
 print("PASS: poison tint follows committed status, expiration and death")
 assert(Effects.PROFILES.manafire.bank=="magic2" and Effects.PROFILES.manafire.start==140)
 assert(Effects.PROFILES.heal.start==370 and Effects.PROFILES.poison.start==770)
 assert(not Effects.PROFILES.poison.get("ground",false))
 var resources:=EditionResources.new();assert(resources.initialize())
 var count:=0
 for id in Effects.PROFILES:
  var p: Dictionary=Effects.PROFILES[id]
  assert(Effects.frame_index(id,-0.01)==-1)
  assert(Effects.frame_index(id,float(p.count)*float(p.step))==-1)
  for i in range(p.count):
   assert(Effects.frame_index(id,i*float(p.step))==int(p.start)+i)
   var f:=resources.frame(p.bank,int(p.start)+i)
   assert(not f.is_empty(),id+":"+str(i));count+=1
  for fps in [30,60,120]:
   assert(Effects.frame_index(id,float(fps*2/5)/fps)==int(p.start)+int(floor(0.4/float(p.step))))
 for direction in range(16):
  for relative in range(10):assert(not resources.frame("magic",970+direction*10+relative).is_empty())
 print("PASS: beam 16 directions/160 source frames decode")
 for id in Effects.MELEE:
  var action: Dictionary=EditionAnimation.HUMAN[EditionSkills.DEFINITIONS[id].action]
  for direction in range(8):
   for relative in range(action.count):
    var frame:=Effects.melee_frame(id,direction,(float(relative)+0.1)*float(action.ms)/1000)
    assert(frame==int(Effects.MELEE[id])+direction*10+relative)
    assert(not resources.frame("magic",frame).is_empty())
   assert(Effects.melee_frame(id,direction,float(action.count)*float(action.ms)/1000)==-1)
 print("PASS: thrust, halfmoon and flame eight-direction source frames match body action timing")
 for direction in range(16):
  for index in range(6):
   var frame:=Effects.flight_frame(direction,index*0.05)
   assert(frame==10+direction*10+index)
   assert(not resources.frame("magic",frame).is_empty())
  assert(Effects.flight_frame(direction,-0.01)==-1 and Effects.flight_frame(direction,0.3)==-1)
 for direction in range(16):
  for relative in range(6):
   var index:=Effects.flight_frame(direction,relative*0.05,"bigfireball")
   assert(index==410+direction*10+relative)
   assert(not resources.frame("magic",index).is_empty())
 assert(Effects.flight_frame(0,0,"unknown")==-1)
 print("PASS: big fireball uses its own 96 directional source frames and impact bank")
 var compass:=[Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1),Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1)]
 for i in range(8):assert(Effects.direction16(compass[i])==i*2)
 for start in [3890,3900]:
  for i in range(3):assert(not resources.frame("magic",start+i).is_empty())
 var lightning:=resources.frame("magic2",10)
 assert(lightning.offset.y<-800 and lightning.size.y>900)
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-skill-vfx-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"vfx","name":"特效测试","job":"法师","gender":"女"})
 var effects=app.gameplay.skill_effects
 assert(not effects.ground_layer.z_as_relative and effects.ground_layer.z_index==0)
 assert(app.world.foreground_layer.z_index==1 and app.gameplay.z_index==2 and app.world.labels.z_index==3)
 assert(effects.PROFILES.armor.ground and effects.PROFILES.ghostshield.ground and not effects.PROFILES.heal.get("ground",false))
 effects.melee_id="thrust";app.world.animate("hurt");effects._process(0);assert(effects.melee_id.is_empty())
 effects.add("lightning",Vector2(500,500));var age:float=app.elapsed
 app.world.paused=true;effects._process(3)
 assert(effects.events.size()==1 and app.elapsed==age)
 app.elapsed+=0.5;effects._process(0);assert(effects.events.is_empty())
 effects.add("heal",Vector2.ZERO);effects.events[0].map="other";effects._process(0);assert(effects.events.is_empty())
 effects.add("heal",Vector2.ZERO);effects.clear();assert(effects.events.is_empty())
 effects.add("unknown",Vector2.ZERO);assert(effects.events.is_empty())
 effects.launch_beam(app.world.entities[0]);effects._process(0)
 assert(effects.events.size()==1 and effects.events[0].at==app.world.player.anchor)
 assert(Effects.frame_index("beam",app.elapsed-float(effects.events[0].time))==-1)
 effects.add("beam",Vector2.ZERO);assert(effects.events.size()==1,"Line hits must not duplicate the cast beam")
 app.elapsed+=0.12;effects._process(0);assert(effects.events.size()==1)
 app.elapsed+=0.8;effects._process(0);assert(effects.events.is_empty())
 effects.launch_beam(app.world.entities[0]);effects.events[0].map="other";effects._process(0);assert(effects.events.is_empty())
 print("PASS: beam stays at cast origin, waits for release, expires, clears across maps and ignores duplicate hit effects")
 effects.flights.append({"map":app.world.metadata.id,"time":app.elapsed+0.12,"direction":4,"from":Vector2.ZERO,"to":Vector2.ONE,"target":"missing","generation":0})
 effects._process(0);assert(effects.flights.size()==1)
 app.elapsed+=0.42;effects._process(0);assert(effects.flights.is_empty())
 effects.flights.append({"map":"other","time":app.elapsed});effects._process(0);assert(effects.flights.is_empty())
 print("PASS: fireball 16 directions/96 source frames; release delay, flight expiration and map cleanup")
 assert(resources.fallback_used.is_empty(),"Effects must use original frames, not substitutions")
 print("PASS: ",count," original effect frames and six shield frames decode; timeline expires; pause freezes; map mismatch and clear remove effects; lightning uses tall hotspot")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
