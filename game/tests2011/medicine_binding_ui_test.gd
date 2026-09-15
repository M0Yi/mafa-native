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
func run() -> void:
 root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 app.store.path="/tmp/binding-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
 app.start_character({"id":"bindingpad","name":"捆药操作","gender":"男","job":"战士"})
 var npc: Dictionary=app.rules.story_npc("server:merchant:105");var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
 app.enter_map(npc.map,at);app.world.paused=false
 var recipes: Dictionary=EditionRules.MEDICINE_BUNDLES.merged(EditionRules.SCROLL_BUNDLES)
 for bundle in recipes:
  var ingredient: String=recipes[bundle]
  var next: Dictionary=app.rules.state.duplicate(true);next.gold=100;next.items=[];next.inventory={ingredient:6};next.warehouse={}
  expect(app.rules.apply(next,"ui_material_fixture"),"prepare recipe")
  app.windows.close_all();app.controller_interact(npc);await settle();await press(JOY_BUTTON_Y)
  var title: String="捆扎 %s ×6 → %s · 100 金币"%[EditionRules.ITEMS[ingredient].name,EditionRules.ITEMS[bundle].name]
  if bundle=="ref:262":title="捆扎回城卷 ×6 → 回城卷包 · 100 金币"
  var target: Button=null
  for button in app.panel.navigation_buttons(app.panel.body):
   if button.text==title:target=button
  expect(target!=null,"recipe visible in services")
  if target==null:continue
  for i in range(24):
   if root.gui_get_focus_owner()==target:break
   await press(JOY_BUTTON_DPAD_DOWN)
  expect(root.gui_get_focus_owner()==target,"dpad reaches recipe")
  var rect:=target.get_global_rect()
  expect(app.panel.scroll.get_global_rect().has_point(rect.get_center()) and root.get_visible_rect().has_point(rect.get_center()),"focused recipe scrolls into viewport")
  if bundle=="ref:262":
   RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://../artifacts/world-story/binding-scroll-small-window.png")
  await press(JOY_BUTTON_A)
  expect(app.rules.state.gold==0 and app.rules.state.inventory.get(bundle,0)==1 and not app.rules.state.inventory.has(ingredient),"A uses correct recipe")
 var report:={"checks":checks,"failures":failures,"scope":"800x600 native joypad events from NPC services, all seven medicine/return-scroll recipes selected and executed, focused button center within scroll/viewport; item/position fixtures, no hardware acceptance"}
 FileAccess.open("res://../artifacts/world-story/medicine-binding-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
