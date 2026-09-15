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
 app.store.path="/tmp/gold-bar-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
 for i in range(8):await process_frame
 app.set_process(false);app.start_character({"id":"gold","name":"兑换检查","gender":"男","job":"战士"})
 var npc: Dictionary=app.rules.story_npc("server:merchant:105");var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
 var before: Dictionary=app.rules.state.duplicate(true)
 expect(not app.rules.shop("ref:226",1) and app.rules.state==before,"cheap generic purchase blocked")
 expect(not app.rules.reference_trade(npc.id,"ref:226",true,0) and app.rules.state==before,"generic merchant purchase blocked")
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at,true) and app.rules.state==before,"insufficient funds preserves state")
 var next: Dictionary=app.rules.state.duplicate(true);next.gold=1002000;app.rules.apply(next,"budget_fixture")
 before=app.rules.state.duplicate(true)
 expect(not app.rules.exchange_gold_bar(npc.id,"0",at,true) and app.rules.state==before,"wrong map blocked")
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at+Vector2i(20,0),true) and app.rules.state==before,"distant exchange blocked")
 app.store.db.query("PRAGMA query_only=ON;")
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at,true) and app.rules.state==before,"failed write does not lose funds")
 app.store.db.query("PRAGMA query_only=OFF;")
 expect(app.rules.exchange_gold_bar(npc.id,npc.map,at,true),"buy bar at exact threshold")
 expect(app.rules.state.gold==0 and app.rules.state.inventory.get("ref:226",0)==1,"money and one bar committed together")
 expect(app.rules.exchange_gold_bar(npc.id,npc.map,at,false),"redeem bar")
 expect(app.rules.state.gold==998000 and not app.rules.state.inventory.has("ref:226"),"round trip costs four thousand")
 before=app.rules.state.duplicate(true)
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at,false) and app.rules.state==before,"same bar cannot redeem twice")
 var disk: Dictionary=app.store.load_world(app.rules.character.id)
 expect(disk.gold==998000 and not disk.inventory.has("ref:226"),"exchange result persists")
 var baseline: Dictionary=app.rules.state.duplicate(true)
 next=baseline.duplicate(true);next.revision=app.rules.state.revision;next.gold=1002000;next.items=[];next.inventory={};next.warehouse={}
 for slot in range(48):next.items.append(EditionInventory.make_item("charm",1,"inventory",slot,100))
 EditionInventory.mirror(next);expect(app.rules.apply(next,"full_bag_fixture"),"prepare full slots below weight limit")
 before=app.rules.state.duplicate(true)
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at,true) and app.rules.state==before and "空格" in app.rules.message,"full bag preserves coins")
 next=baseline.duplicate(true);next.revision=app.rules.state.revision;next.gold=1002000;next.items=[];next.inventory={"charm":100};next.warehouse={}
 expect(app.rules.apply(next,"weight_fixture"),"prepare nearly full weight")
 before=app.rules.state.duplicate(true)
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at,true) and app.rules.state==before and "负重" in app.rules.message,"overweight conversion preserves coins")
 next=baseline.duplicate(true);next.revision=app.rules.state.revision;next.gold=4002001;next.inventory["ref:226"]=1
 expect(app.rules.apply(next,"ceiling_fixture"),"prepare cap boundary with bar")
 before=app.rules.state.duplicate(true)
 expect(not app.rules.exchange_gold_bar(npc.id,npc.map,at,false) and app.rules.state==before,"above redemption cap preserves bar")
 expect(not app.rules.use_item("ref:226") and app.rules.state==before,"double click cannot consume currency item")
 next=app.rules.state.duplicate(true);next.gold=4002000;app.rules.apply(next,"exact_cap_fixture")
 expect(app.rules.exchange_gold_bar(npc.id,npc.map,at,false) and app.rules.state.gold==5000000,"exact redemption cap permitted")
 # Click both actual merchant buttons through viewport input, with an isolated budget.
 next=baseline.duplicate(true);next.revision=app.rules.state.revision;next.gold=1002000;app.rules.apply(next,"ui_budget_fixture")
 app.enter_map(npc.map,at);app.world.paused=false
 for buy in [true,false]:
  app.windows.close_all();app.show_reference_npc(npc)
  for i in range(8):await process_frame
  var caption: String="1002000 金币 → 金条 ×1" if buy else "金条 ×1 → 998000 金币"
  var target: Button=null
  for button in app.panel.navigation_buttons(app.panel.body):
   if button.text==caption:target=button
  expect(target!=null,"exchange button present")
  if target==null:continue
  var point:=target.get_global_rect().get_center()
  for pressed in [true,false]:
   var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true)
   for i in range(8):await process_frame
  expect(app.rules.state.gold==(0 if buy else 998000) and int(app.rules.state.inventory.get("ref:226",0))==(1 if buy else 0),"mouse button invokes correct exchange direction")
 var report:={"checks":checks,"failures":failures,"scope":"reference fees, exact budget, source NPC and distance guards, generic price exploit prevention, rollback and SQLite; positions/budget fixtures, full slots/weight/cap and viewport mouse directions covered; no physical hardware input"}
 FileAccess.open("res://../artifacts/world-story/gold-bar-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
 for i in range(3):await process_frame
 quit(0 if failures.is_empty() else 1)
