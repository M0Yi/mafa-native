extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
 app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 app.store.path="/tmp/medicine-binding-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
 for i in range(50):
  if app.rules.store!=null:break
  await create_timer(0.1).timeout
 if app.rules.store==null:printerr("application initialization timed out");quit(1);return
 app.set_process(false);app.start_character({"id":"gold","name":"兑换检查","gender":"男","job":"战士"})
 var npc: Dictionary=app.rules.story_npc("server:merchant:105");var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
 var q: Dictionary=EditionRules.Story.quest("story_palace_medicine")
 var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_palace_accounts="done";app.rules.apply(prepared,"quest_prerequisite_fixture")
 expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept binding commission")
 expect(not EditionRules.Story.ready(app.rules.state,q),"acceptance alone not ready")
 for bundle in EditionRules.MEDICINE_BUNDLES:
  var ingredient: String=EditionRules.MEDICINE_BUNDLES[bundle]
  var next: Dictionary=app.rules.state.duplicate(true);next.gold=1000;next.items=[];next.inventory={ingredient:6};next.warehouse={}
  expect(app.rules.apply(next,"medicine_fixture"),"prepare six matching bottles")
  var before: Dictionary=app.rules.state.duplicate(true)
  expect(not app.rules.shop(bundle,1) and app.rules.state==before,"generic purchase cannot bypass binding")
  expect(not app.rules.bind_medicine(npc.id,"0",at,bundle) and app.rules.state==before,"wrong map cannot bind")
  app.store.db.query("PRAGMA query_only=ON;")
  expect(not app.rules.bind_medicine(npc.id,npc.map,at,bundle) and app.rules.state==before,"failed binding preserves six bottles and money")
  app.store.db.query("PRAGMA query_only=OFF;")
  expect(app.rules.bind_medicine(npc.id,npc.map,at,bundle),"bind actual recipe")
  expect(EditionRules.Story.ready(app.rules.state,q)==(bundle in ["ref:256","ref:257"]),"only matching successful binding advances commission")
  expect(app.rules.state.gold==900 and app.rules.state.inventory.get(bundle,0)==1 and not app.rules.state.inventory.has(ingredient),"exact fee and six to one transformation")
  before=app.rules.state.duplicate(true)
  expect(not app.rules.bind_medicine(npc.id,npc.map,at,bundle) and app.rules.state==before,"insufficient bottles cannot bind twice")
  expect(app.rules.use_item(bundle),"unpack actual bundle")
  expect(app.rules.state.inventory.get(ingredient,0)==6 and not app.rules.state.inventory.has(bundle) and app.rules.state.hp==before.hp and app.rules.state.mp==before.mp,"unpack restores six bottles without healing")
 expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"deliver binding commission")
 var done: Dictionary=app.rules.state.duplicate(true)
 expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==done,"binding reward cannot repeat")
 expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","binding commission persists")
 for pack_count in [2,1]:
  var next: Dictionary=app.rules.state.duplicate(true);next.items=[];next.inventory={};next.warehouse={}
  for slot in range(47):next.items.append(EditionInventory.make_item("charm",1,"inventory",slot,100))
  next.items.append(EditionInventory.make_item("ref:256",pack_count,"inventory",47,100));EditionInventory.mirror(next)
  expect(app.rules.apply(next,"full_bundle_slots_fixture"),"prepare full bag with bundle stack")
  var before: Dictionary=app.rules.state.duplicate(true)
  if pack_count==2:
   expect(not app.rules.use_item("ref:256") and app.rules.state==before and "空格" in app.rules.message,"partial stack unpack needs new slot and preserves both packs on failure")
  else:
   expect(app.rules.use_item("ref:256") and app.rules.state.inventory.get("potion",0)==6 and not app.rules.state.inventory.has("ref:256"),"last bundle frees its own slot before adding six bottles")
 var heavy: Dictionary=app.rules.state.duplicate(true);heavy.items=[];heavy.inventory={"charm":100+int(heavy.level)*5-6,"potion":6};heavy.warehouse={};heavy.gold=100
 expect(app.rules.apply(heavy,"binding_weight_fixture"),"prepare full allowed weight")
 var before_heavy: Dictionary=app.rules.state.duplicate(true)
 expect(not app.rules.bind_medicine(npc.id,npc.map,at,"ref:256") and app.rules.state==before_heavy and "负重" in app.rules.message,"heavier source bundle rejects without losing money or bottles")
 var report:={"checks":checks,"failures":failures,"scope":"six original medicine recipes, fee and ingredient conservation, read-only rollback, wrong map, generic purchase rejection, real unpack; budget/items/positions fixtures, no physical input or scroll binding"}
 FileAccess.open("res://../artifacts/world-story/medicine-binding-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
 for i in range(3):await process_frame
 quit(0 if failures.is_empty() else 1)
