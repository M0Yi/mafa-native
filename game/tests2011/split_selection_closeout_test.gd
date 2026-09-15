extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-split-selection-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"split","name":"拆分检查","job":"战士","gender":"女"})
 var potion: Dictionary=app.rules.state.items.filter(func(i):return i.type=="potion")[0]
 assert(app.rules.inventory_action("split",{"uid":potion.uid,"count":2}))
 var stacks: Array=app.rules.state.items.filter(func(i):return i.type=="potion" and i.container=="inventory")
 var target: Dictionary=stacks[-1]
 app.selected_item_uid=target.uid
 var view:=EditionItemPanel.new();root.add_child(view);view.setup(app,"inventory")
 var pre_revision: int=app.rules.state.revision
 app.world.paused=true
 view.split_prompt()
 assert(not view.get_children().any(func(n):return n is ConfirmationDialog))
 var sort: Button=view.get_children().filter(func(n):return n is Button and n.text=="整理")[0]
 sort.pressed.emit()
 assert(app.rules.state.revision==pre_revision)
 app.world.paused=false
 view.split_prompt()
 var dialog: ConfirmationDialog=view.get_children().filter(func(n):return n is ConfirmationDialog)[0]
 assert(app.windows.has_modal())
 var choices: Array=dialog.find_children("*","OptionButton",true,false)
 var choice: OptionButton=choices[0]
 var count: SpinBox=dialog.find_children("*","SpinBox",true,false)[0]
 assert(choice.get_item_text(choice.selected).contains("格%d"%(int(target.slot)+1)))
 assert(count.max_value==int(target.count)-1)
 app.world.paused=true
 dialog.confirmed.emit()
 assert(app.rules.state.revision==pre_revision and not dialog.is_queued_for_deletion())
 assert(app.pending_message=="请继续游戏后操作物品")
 app.world.paused=false
 var hidden_state: Dictionary=app.rules.state.duplicate(true)
 dialog.hide();dialog.confirmed.emit()
 assert(app.rules.state==hidden_state)
 dialog.show()
 print("PASS: hidden split dialog cannot submit stale confirmation")
 var guarded_state: Dictionary=app.rules.state.duplicate(true)
 for guard in ["dead","roster"]:
  var original_hp=app.rules.state.hp
  if guard=="dead":app.rules.state.hp=0
  else:app.mode="roster"
  dialog.confirmed.emit()
  app.rules.state.hp=original_hp;app.mode="game"
  assert(app.rules.state==guarded_state and not dialog.is_queued_for_deletion())
  var labels=dialog.find_children("*","Label",true,false)
  assert(labels.any(func(label):return label.text=="请进入游戏并复活后操作物品"))
 print("PASS: death or roster during split preserves item instances and allows later retry")
 var before: int=app.rules.state.inventory.potion
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 var revision: int=app.rules.state.revision
 dialog.confirmed.emit()
 assert(not dialog.is_queued_for_deletion() and not dialog.dialog_hide_on_ok)
 assert(app.rules.state.revision==revision and app.rules.state.inventory.potion==before)
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 dialog.confirmed.emit()
 var committed: int=app.rules.state.revision
 dialog.confirmed.emit()
 assert(app.rules.state.revision==committed)
 assert(EditionInventory.find_item(app.rules.state,target.uid).count==1)
 assert(EditionInventory.find_item(app.rules.state,potion.uid).count==3)
 assert(app.rules.state.inventory.potion==before)
 await process_frame
 assert(not app.windows.has_modal())
 app.selected_item_uid=potion.uid
 view.split_prompt()
 var stale: ConfirmationDialog=view.get_children().filter(func(n):return n is ConfirmationDialog and not n.is_queued_for_deletion())[0]
 assert(app.rules.inventory_action("move",{"uid":potion.uid,"container":"warehouse","slot":0}))
 var moved_revision: int=app.rules.state.revision
 stale.confirmed.emit()
 assert(app.rules.state.revision==moved_revision)
 assert(EditionInventory.find_item(app.rules.state,potion.uid).count==3)
 assert(not stale.is_queued_for_deletion())
 assert(app.pending_message.contains("已移动"))
 stale.canceled.emit()
 await process_frame
 assert(not app.windows.has_modal())
 assert(not view.get_children().any(func(n):return n is ConfirmationDialog))
 print("PASS: selected stack and slot, quantity bound, correct instance split, conserved total, failed save retry, duplicate confirmation guard, moved item rejected, success/cancel release modal input; paused sort/open/confirm rejected")
 assert(app.rules.inventory_action("move",{"uid":potion.uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")}))
 app.selected_item_uid=potion.uid;view.split_prompt()
 var detached: ConfirmationDialog=view.get_children().filter(func(n):return n is ConfirmationDialog)[0]
 root.remove_child(view)
 var closed_state: Dictionary=app.rules.state.duplicate(true)
 detached.confirmed.emit();view.split_prompt()
 assert(app.rules.state==closed_state)
 assert(view.get_children().filter(func(n):return n is ConfirmationDialog).size()==1)
 print("PASS: detached inventory panel cannot open or confirm a split")
 var old_page: int=view.page;var old_message: String=app.pending_message
 sort.pressed.emit()
 for control in view.get_children():
  if control is BaseButton and (control.text=="翻页" or control.tooltip_text=="使用选中物品"):control.pressed.emit()
 assert(app.rules.state==closed_state and view.page==old_page and app.pending_message==old_message)
 print("PASS: detached inventory sort, use and paging callbacks are inert")
 var app_ref:=weakref(app);var view_ref:=weakref(view)
 view.queue_free();app.queue_free();await process_frame;await create_timer(0.2).timeout
 assert(app_ref.get_ref()==null and view_ref.get_ref()==null)
 print("PASS: application and item panel nodes released")
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
