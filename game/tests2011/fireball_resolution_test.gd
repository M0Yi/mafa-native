extends SceneTree
class AudioProbe extends EditionGameplay:
 var stages: Array=[]
 func play_skill_stage(id: String,stage: int) -> void:stages.append([id,stage])
func _initialize():call_deferred("run")
func run():
 var skill:="bigfireball" if "--bigfireball" in OS.get_cmdline_user_args() else "fireball"
 var cost:int=EditionSkills.DEFINITIONS[skill].mp
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-fireball-resolution-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.gameplay.free();app.gameplay=AudioProbe.new()
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"fireball","name":"火球结算","job":"法师","gender":"女"})
 app.enter_map("0",Vector2i(300,614));app.world.paused=false
 var target: Dictionary={}
 for e in app.world.entities:
  if e.kind!="monster" or e.hp<=0 or EditionRegion.safe("0",Vector2i(e.cell[0],e.cell[1])):continue
  for d in ClassicNavigation.DIRECTIONS:
   var cell:Vector2i=Vector2i(e.cell[0],e.cell[1])+d
   if app.world.navigation.mobile(cell) and not EditionRegion.safe("0",cell) and app.gameplay.line_clear(cell,Vector2i(e.cell[0],e.cell[1])):
    target=e;app.world.player.reset(cell);break
  if not target.is_empty():break
 assert(not target.is_empty())
 target.hp=100000;app.selected=target
 var next:Dictionary=app.rules.state.duplicate(true);next.level=20;next.mp=100;next.skills[skill]={"rank":1,"proficiency":0}
 assert(app.rules.apply(next,"test_skill_fixture"))
 var before:int=target.hp;var mana:int=app.rules.state.mp;var start:float=app.elapsed
 assert(app.gameplay.cast(skill),app.pending_message)
 assert(is_equal_approx(app.pending_attack.at,start+0.42))
 assert(app.rules.state.mp==mana-cost and app.gameplay.skill_effects.flights.size()==1)
 app.elapsed=start+0.419;app.resolve_attack();assert(target.hp==before and app.gameplay.skill_effects.events.is_empty())
 app.elapsed=start+0.421;app.resolve_attack();var after:int=target.hp
 assert(after<before and app.gameplay.skill_effects.events.size()==1)
 assert(app.gameplay.stages.count([skill,2])==1)
 app.resolve_attack();assert(target.hp==after and app.rules.state.mp==mana-cost and app.gameplay.skill_effects.events.size()==1)
 app.gameplay.skill_effects.clear();app.fight_timer=0;app.elapsed=start+2
 assert(app.gameplay.cast(skill));target.generation+=1
 app.elapsed+=0.5;app.resolve_attack();assert(target.hp==after and app.gameplay.skill_effects.events.is_empty())
 app.gameplay.skill_effects.clear()
 var lethal:={"skill":skill,"damage":1000000}
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 var sounds_before:int=app.gameplay.stages.size()
 lethal.merge({"id":target.id,"generation":target.generation,"at":app.elapsed,"range":6})
 app.pending_attack=lethal;app.resolve_attack()
 assert(app.gameplay.stages.size()==sounds_before)
 assert(target.hp==after and app.gameplay.skill_effects.events.is_empty())
 for status_skill in ["poison","manafire"]:
  target.mp=80;target.poison_until=app.elapsed+4;target.poison_next=app.elapsed+1
  var snapshot:Dictionary=target.duplicate(true)
  var status_attack:Dictionary={"skill":status_skill,"damage":1000000,"id":target.id,"generation":target.generation,"at":app.elapsed,"range":6}
  app.pending_attack=status_attack;app.resolve_attack()
  assert(target==snapshot,"Failed lethal "+status_skill+" must preserve all target state")
  assert(app.gameplay.stages.size()==sounds_before and app.gameplay.skill_effects.events.is_empty())
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 # A successful surviving hit must still apply the same status changes.
 assert(app.apply_attack_hit(target,{"skill":"poison","damage":1}))
 assert(target.poison_until==app.elapsed+10 and target.poison_next==app.elapsed+1.5)
 assert(app.apply_attack_hit(target,{"skill":"manafire","damage":1}))
 assert(target.mp==60)
 app.gameplay.skill_effects.clear()
 print("PASS: failed lethal poison and manafire preserve target state; successful hits apply status and mana drain")
 print("PASS: impact sound dispatch follows committed damage and is silent on failed lethal save")
 print("PASS: failed lethal reward transaction preserves target health and emits no impact visual")
 # A target visible but off the eight-direction attack ray must not consume a cast.
 var original_cell:Array=target.cell.duplicate()
 var origin:Vector2i=app.world.player.cell
 var off_ray_found:=false
 for offset in [Vector2i(2,1),Vector2i(-2,1),Vector2i(2,-1),Vector2i(-2,-1)]:
  var cell:Vector2i=origin+offset
  if app.world.navigation.mobile(cell) and not EditionRegion.safe("0",cell) and app.gameplay.line_clear(origin,cell):
   target.cell=[cell.x,cell.y];off_ray_found=true;break
 assert(off_ray_found)
 var entities:Array=app.world.entities;app.world.entities=[target]
 next=app.rules.state.duplicate(true);next.level=50;next.mp=100;next.skills.beam={"rank":1,"proficiency":0}
 assert(app.rules.apply(next,"test_off_ray_fixture"))
 app.fight_timer=0;app.elapsed+=2
 var state_before:Dictionary=app.rules.state.duplicate(true)
 assert(not app.gameplay.cast("beam"))
 assert(app.rules.state==state_before and app.pending_attack.is_empty())
 assert(app.gameplay.skill_effects.events.is_empty() and app.gameplay.skill_effects.flights.is_empty())
 # A selected area center must not be replaced by the nearest collateral target.
 var neighbor:Dictionary=target.duplicate(true);neighbor.id="area_neighbor";neighbor.cell=[origin.x,origin.y];neighbor.hp=100000
 app.world.entities=[neighbor,target];app.selected=target
 next=app.rules.state.duplicate(true);next.skills.explosion={"rank":1,"proficiency":0}
 assert(app.rules.apply(next,"test_area_fixture"))
 # Move the nearby target one tile toward the selected center, within the blast radius.
 neighbor.cell=[int(target.cell[0])-signi(int(target.cell[0])-origin.x),int(target.cell[1])]
 assert(app.gameplay.cast("explosion"))
 var center:Vector2=app.world.actors.anchor(target)
 assert(app.pending_attack.hits.size()==2 and app.pending_attack.id==target.id and app.pending_attack.effect_at==center)
 var area_attack:Dictionary=app.pending_attack.duplicate(true);app.pending_attack.clear()
 app.show_hit_effect(neighbor,area_attack);app.show_hit_effect(target,area_attack)
 assert(app.gameplay.skill_effects.events.size()==1 and app.gameplay.skill_effects.events[0].at==center)
 app.gameplay.skill_effects.clear()
 print("PASS: selected area center survives distance sorting and collateral hits emit one effect at that center")
 # The collateral target leaves the blast after casting, but remains in caster range.
 var neighbor_hp:int=neighbor.hp;var target_hp:int=target.hp
 neighbor.cell=[origin.x,origin.y]
 app.pending_attack=area_attack.duplicate(true);app.pending_attack.erase("visual_played")
 app.elapsed=float(app.pending_attack.at)+0.001;app.resolve_attack()
 assert(neighbor.hp==neighbor_hp and target.hp<target_hp)
 assert(app.gameplay.skill_effects.events.size()==1 and app.gameplay.skill_effects.events[0].at==center)
 app.gameplay.skill_effects.clear()
 print("PASS: area resolution excludes escaped target while damaging target still inside the fixed blast")
 target.cell=original_cell;app.world.entities=entities
 print("PASS: off-ray line target rejects before mana, cooldown, proficiency or effect mutation")
 app.fight_timer=0;app.elapsed+=2
 assert(app.gameplay.cast(skill))
 app.world.monster_hit.emit({"stone":true},1)
 assert(app.rules.stoned(app.elapsed) and app.pending_attack.is_empty())
 assert(app.gameplay.spell_events.is_empty() and app.gameplay.skill_effects.flights.is_empty() and app.gameplay.skill_effects.events.is_empty())
 print("PASS: committed petrification cancels pending attack and scheduled spell presentation")
 next=app.rules.state.duplicate(true);next.erase("stone_until");assert(app.rules.apply(next,"test_clear_stone"))
 app.fight_timer=0;app.elapsed+=2
 assert(app.gameplay.cast(skill));assert(app.enter_map("0",Vector2i(289,618)))
 assert(app.pending_attack.is_empty() and app.gameplay.skill_effects.flights.is_empty())
 print("PASS: real projectile cast consumes once; damage and impact wait for flight; repeated resolve is inert; invalid generation and map transition cancel impact")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
