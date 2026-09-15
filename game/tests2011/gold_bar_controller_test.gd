extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
 for i in range(8):await process_frame
func press(key: int) -> void:
 var e:=InputEventJoypadButton.new();e.button_index=key;e.pressed=true;root.push_input(e,true);await settle()
 e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func choose(npc: Dictionary,buy: bool) -> void:
 app.windows.close_all();app.controller_interact(npc);await settle();await press(JOY_BUTTON_Y)
 var title: String="1002000 金币 → 金条 ×1" if buy else "金条 ×1 → 998000 金币"
 var target: Button=null
 for button in app.panel.navigation_buttons(app.panel.body):
  if button.text==title:target=button
 expect(target!=null,"controller services expose exchange")
 if target==null:return
 for i in range(20):
  if root.gui_get_focus_owner()==target:break
  await press(JOY_BUTTON_DPAD_DOWN)
 expect(root.gui_get_focus_owner()==target,"dpad selects exact direction")
func run() -> void:
 root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 app.store.path="/tmp/gold-controller-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
 app.start_character({"id":"goldpad","name":"手柄兑换","gender":"男","job":"战士"})
 var npc: Dictionary=app.rules.story_npc("server:merchant:105");var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
 app.enter_map(npc.map,at);app.world.paused=false
 var next: Dictionary=app.rules.state.duplicate(true);next.gold=1002000;app.rules.apply(next,"budget_fixture")
 await choose(npc,true)
 var before: Dictionary=app.rules.state.duplicate(true);app.world.paused=true;await press(JOY_BUTTON_A)
 expect(app.rules.state==before,"paused A cannot exchange")
 app.world.paused=false;await press(JOY_BUTTON_A)
 expect(app.rules.state.gold==0 and app.rules.state.inventory.get("ref:226",0)==1,"A buys gold bar")
 await choose(npc,false)
 before=app.rules.state.duplicate(true);app.world.player.reset(at+Vector2i(20,0));await press(JOY_BUTTON_A)
 expect(app.rules.state==before,"stale distant service cannot redeem")
 app.world.player.reset(at);await choose(npc,false)
 app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A)
 expect(app.rules.state==before,"controller write failure preserves bar")
 app.store.db.query("PRAGMA query_only=OFF;");await choose(npc,false);await press(JOY_BUTTON_A)
 expect(app.rules.state.gold==998000 and not app.rules.state.inventory.has("ref:226"),"controller retry redeems exactly once")
 var report:={"checks":checks,"failures":failures,"scope":"native joypad events from NPC Y services through direction selection and A exchange, pause/distance/write rollback; budget and position fixtures, not physical controller acceptance"}
 FileAccess.open("res://../artifacts/world-story/gold-bar-controller-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
