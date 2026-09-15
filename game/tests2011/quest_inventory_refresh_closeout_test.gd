extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-quest-refresh-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"split","name":"拆分检查","job":"战士","gender":"女"})
 var next: Dictionary=app.rules.state.duplicate(true)
 next.quests={"nv_arrival":"done","nv_equip":"done","nv_hunt":"accepted"};next.novice={"chickens":3,"patrol":false}
 var meat:=EditionInventory.make_item("chicken_meat",3,"inventory",EditionInventory.free_slot(next.items,"inventory"))
 next.items.append(meat);EditionInventory.mirror(next);if not app.rules.apply(next,"quest_refresh_fixture"):printerr(app.rules.message);quit(1);return
 var view=load("res://scripts/edition2011/ui/quest_panel.gd").new();root.add_child(view);view.setup(app,{"name":"村长","cell":[289,618]})
 view.selected="nv_hunt";view.refresh();view._process(0)
 assert(not view.submit_control.disabled)
 assert(app.rules.inventory_action("move",{"uid":meat.uid,"container":"warehouse","slot":0}))
 view._process(0)
 assert(view.submit_control.disabled)
 assert(view.progress_rows.any(func(row):return row.label.text.contains("鸡肉 0/3")))
 assert(app.rules.inventory_action("move",{"uid":meat.uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")}))
 view._process(0)
 assert(not view.submit_control.disabled)
 assert(view.progress_rows.any(func(row):return row.label.text.contains("可以交付")))
 var blocked_revision: int=app.rules.state.revision
 app.world.paused=true;view.submit_control.pressed.emit()
 assert(app.rules.state.revision==blocked_revision and app.pending_message.contains("继续游戏"))
 app.world.paused=false
 var old_cell: Vector2i=app.world.player.cell
 app.world.player.cell=Vector2i(0,0)
 view.submit_control.pressed.emit()
 assert(app.rules.state.revision==blocked_revision and app.pending_message.contains("村长身边"))
 app.world.player.cell=old_cell
 var before: Dictionary=app.rules.state.duplicate(true)
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 assert(not app.rules.novice_quest("nv_hunt"))
 assert(app.rules.state==before)
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 assert(app.rules.novice_quest("nv_hunt"))
 var completed: Dictionary=app.rules.state.duplicate(true)
 assert(completed.quests.nv_hunt=="done" and completed.inventory.get("chicken_meat",0)==0)
 assert(completed.inventory.mana==before.inventory.mana+2)
 assert(completed.gold==before.gold+(200 if before.preset=="easy" else 100))
 assert(not app.rules.novice_quest("nv_hunt"))
 assert(app.rules.state==completed)
 view.show_completed=true;view.selected="nv_hunt";view.refresh()
 assert(view.submit_control.disabled and view.submit_control.text=="已完成")
 print("PASS: quest submission and progress update after warehouse deposit and withdrawal; failed submission rollback, retry and no duplicate rewards; paused and distant submit rejected")
 view.queue_free();app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
