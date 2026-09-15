extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-warehouse-distance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"warehouse","name":"仓库距离","job":"战士","gender":"女"});app.world.paused=false
 var keeper: Dictionary={"id":"fixture","name":"保管员","map":app.world.metadata.id,"cell":[app.world.player.cell.x,app.world.player.cell.y]}
 app.game_panel("手柄仓库")
 var view=load("res://scripts/edition2011/ui/controller_warehouse.gd").new();app.form.add_child(view);view.setup(app,keeper)
 var before: Dictionary=app.rules.state.duplicate(true)
 app.windows.confirm("阻止底层仓库操作",func():pass)
 view.operate();assert(app.rules.state==before)
 for key in [JOY_BUTTON_A,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_B]:
  var event:=InputEventJoypadButton.new();event.pressed=true;event.button_index=key;view._input(event)
 assert(app.rules.state==before and view.page==0 and app.windows.windows.has("手柄仓库"))
 app.windows.modal.canceled.emit();app.windows.modal.hide()
 app.game_panel("上层测试窗口")
 var shoulder:=InputEventJoypadButton.new();shoulder.pressed=true;shoulder.button_index=JOY_BUTTON_RIGHT_SHOULDER
 view._input(shoulder);assert(view.page==0)
 app.windows.close("上层测试窗口")
 view._input(shoulder);assert(view.page==1)
 view._input(shoulder);assert(view.page==0)
 print("PASS: controller warehouse ignores modal and covered inputs; shoulders work after uncovering")
 var origin: Vector2i=app.world.player.cell
 app.world.player.cell=origin+Vector2i(5,0);view.operate()
 assert(app.rules.state==before and view.result.text.contains("保管员"))
 app.world.player.cell=origin;app.world.paused=true;view.operate();assert(app.rules.state==before)
 app.world.paused=false
 var map_id: String=app.world.metadata.id
 app.world.metadata.id="other-map";view.operate();assert(app.rules.state==before)
 app.world.metadata.id=map_id
 app.rules.state.hp=0;before=app.rules.state.duplicate(true);view.operate();assert(app.rules.state==before)
 app.rules.state.hp=app.rules.max_hp()
 var uid: String=view.rows[0].uid
 view.operate();assert(EditionInventory.find_item(app.rules.state,uid).container=="warehouse")
 view.page=1;view.refresh();view.operate()
 assert(EditionInventory.find_item(app.rules.state,uid).container=="inventory")
 app.windows.close("手柄仓库")
 before=app.rules.state.duplicate(true);view.page=0;view.refresh();view.operate()
 assert(app.rules.state==before)
 app.game_panel("手柄仓库")
 view.operate();assert(app.rules.state==before)
 app.windows.close("手柄仓库")
 print("PASS: detached controller warehouse cannot mutate items after close or replacement")
 app.show_warehouse(keeper)
 assert(app.warehouse_keeper==keeper)
 app.show_warehouse()
 assert(app.warehouse_keeper==keeper and app.pending_message.contains("服务NPC"))
 app.warehouse_keeper=keeper.duplicate(true)
 var slot:=EditionItemSlot.new();app.add_child(slot);slot.setup(app,"warehouse",0)
 var data: Dictionary={"kind":"item","uid":uid,"character":app.rules.character.id}
 before=app.rules.state.duplicate(true)
 app.world.player.cell=origin+Vector2i(5,0)
 assert(not slot._can_drop_data(Vector2.ZERO,data));slot._drop_data(Vector2.ZERO,data)
 assert(app.rules.state==before)
 app.world.player.cell=origin
 assert(slot._can_drop_data(Vector2.ZERO,data));slot._drop_data(Vector2.ZERO,data)
 assert(EditionInventory.find_item(app.rules.state,uid).container=="warehouse")
 var bag:=EditionItemSlot.new();app.add_child(bag);bag.setup(app,"inventory",20)
 app.world.player.cell=origin+Vector2i(5,0)
 assert(not bag._can_drop_data(Vector2.ZERO,data))
 before=app.rules.state.duplicate(true);bag._drop_data(Vector2.ZERO,data);assert(app.rules.state==before)
 app.world.player.cell=origin
 app.windows.close("个人仓库")
 before=app.rules.state.duplicate(true)
 assert(not bag._can_drop_data(Vector2.ZERO,data));bag._drop_data(Vector2.ZERO,data)
 assert(app.rules.state==before and app.pending_message.contains("仓库已关闭"))
 app.show_warehouse(keeper)
 assert(bag._can_drop_data(Vector2.ZERO,data));bag._drop_data(Vector2.ZERO,data)
 assert(EditionInventory.find_item(app.rules.state,uid).container=="inventory")
 print("PASS: closed warehouse rejects stale withdrawal drag; reopening restores valid access")
 print("PASS: NPC-bound mouse warehouse rejects distant deposit and withdrawal drag; nearby transfer succeeds")
 print("PASS: controller warehouse rejects distance, pause, map change and death; nearby deposit/withdraw preserves item identity")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
