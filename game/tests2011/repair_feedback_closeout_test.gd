extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-repair-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"repair","name":"修理重试","job":"战士","gender":"女"})
 var npc: Dictionary=app.rules.story_npc("server:merchant:56")
 app.world.metadata.id=npc.map;app.world.player.cell=Vector2i(npc.cell[0],npc.cell[1]);app.world.paused=false
 var next: Dictionary=app.rules.state.duplicate(true);next.gold=1000
 next.items=next.items.filter(func(i):return i.container!="equipment" or int(i.slot)!=0)
 var sword:=EditionInventory.make_item("wood_sword",1,"equipment",0,50);next.items.append(sword);EditionInventory.mirror(next)
 assert(app.rules.apply(next,"repair_fixture"))
 app.game_panel("手柄修理")
 var view=load("res://scripts/edition2011/ui/controller_repair.gd").new();app.form.add_child(view);view.setup(app,npc)
 var quote: Dictionary=app.rules.reference_repair_quote(npc.id)
 assert(int(quote.cost)>0 and view.detail.text.contains("预计合计 %d 金币"%int(quote.cost)))
 var before: Dictionary=app.rules.state.duplicate(true)
 var event:=InputEventJoypadButton.new();event.pressed=true;event.button_index=JOY_BUTTON_A
 assert(app.store.db.query("PRAGMA query_only=ON;"));view._input(event)
 assert(app.rules.state==before and view.result.text==app.rules.message and not view.result.text.is_empty())
 assert(app.windows.windows.has("手柄修理"))
 assert(app.store.db.query("PRAGMA query_only=OFF;"));view._input(event)
 assert(EditionInventory.find_item(app.rules.state,sword.uid).durability==100 and app.rules.state.gold==before.gold-int(quote.cost))
 before=app.rules.state.duplicate(true);view._input(event)
 assert(app.rules.state==before and view.result.text.contains("没有此商店可以修理"))
 print("PASS: repair write failure retains panel, gold and durability; retry repairs and charges once")
 next=app.rules.state.duplicate(true)
 for item in next.items:
  if item.uid==sword.uid:item.durability=50
 EditionInventory.mirror(next);assert(app.rules.apply(next,"stale_repair_fixture"))
 before=app.rules.state.duplicate(true)
 app.windows.close("手柄修理");app.game_panel("手柄修理")
 view._input(event)
 assert(app.rules.state==before)
 print("PASS: closed repair panel cannot transact after a same-title window reopens")
 app.game_panel("手柄桃源合成")
 var craft=load("res://scripts/edition2011/ui/controller_crafting.gd").new();app.form.add_child(craft);craft.setup(app,npc)
 craft.phase="confirm"
 app.windows.close("手柄桃源合成");app.game_panel("手柄桃源合成")
 craft._input(event)
 assert(craft.phase=="confirm" and app.rules.state==before)
 print("PASS: closed crafting panel ignores stale confirmation")
 if "--stop-audio" in OS.get_cmdline_user_args():
  app.stop_audio()
  assert(app.music.stream==null and app.resources.sounds.is_empty())
  for player in app.effects:assert(player.stream==null and not player.playing)
 if "--settle-audio" in OS.get_cmdline_user_args():await create_timer(0.1).timeout
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
