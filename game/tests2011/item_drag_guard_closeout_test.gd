extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-drag-guard-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"drag","name":"拖拽检查","job":"战士","gender":"女"})
 var slot:=EditionItemSlot.new();root.add_child(slot);slot.setup(app,"inventory",20)
 var item: Dictionary=app.rules.state.items[0]
 var valid:={"kind":"item","character":"drag","uid":item.uid}
 assert(slot._can_drop_data(Vector2.ZERO,valid))
 var revision: int=app.rules.state.revision
 for invalid in [null,{}, {"kind":"item","character":"drag"}, {"kind":"item","character":"drag","uid":"gone"}, {"kind":"item","character":"other","uid":item.uid}, {"kind":"item","character":"drag","uid":42}]:
  assert(not slot._can_drop_data(Vector2.ZERO,invalid));slot._drop_data(Vector2.ZERO,invalid)
 assert(app.rules.state.revision==revision)
 app.world.paused=true;assert(not slot._can_drop_data(Vector2.ZERO,valid));app.world.paused=false
 app.rules.state.hp=0;assert(not slot._can_drop_data(Vector2.ZERO,valid));app.rules.state.hp=130
 slot._drop_data(Vector2.ZERO,valid)
 assert(EditionInventory.find_item(app.rules.state,item.uid).slot==20)
 var quick:=EditionQuickSlot.new();quick.app=app;quick.index=5;root.add_child(quick)
 assert(quick._can_drop_data(Vector2.ZERO,valid))
 var modal_state: Dictionary=app.rules.state.duplicate(true)
 slot._process(0)
 assert(slot.item_is_current())
 app.windows.modal.show()
 assert(slot._get_drag_data(Vector2.ZERO)==null)
 assert(not quick._can_drop_data(Vector2.ZERO,valid) and not slot._can_drop_data(Vector2.ZERO,valid))
 quick._drop_data(Vector2.ZERO,valid);slot._drop_data(Vector2.ZERO,valid)
 assert(app.rules.state==modal_state)
 app.windows.modal.hide()
 assert(quick._can_drop_data(Vector2.ZERO,valid) and slot._can_drop_data(Vector2.ZERO,valid))
 print("PASS: modal blocks item and quickbar drops; dismissal restores valid targets")
 var before_mode_drop: Dictionary=app.rules.state.duplicate(true)
 app.mode="roster"
 assert(slot._get_drag_data(Vector2.ZERO)==null)
 assert(not quick._can_drop_data(Vector2.ZERO,valid) and not slot._can_drop_data(Vector2.ZERO,valid))
 quick._drop_data(Vector2.ZERO,valid);slot._drop_data(Vector2.ZERO,valid)
 assert(app.rules.state==before_mode_drop)
 app.mode="game"
 print("PASS: non-game item and quickbar drops preserve inventory and bindings")
 var old_binding: Array=app.rules.state.quickbar.duplicate()
 var old_items: Array=app.rules.state.items.duplicate(true)
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 revision=app.rules.state.revision
 quick._drop_data(Vector2.ZERO,valid)
 assert(app.rules.state.revision==revision and app.rules.state.quickbar==old_binding)
 assert(app.rules.state.items==old_items and not app.pending_message.is_empty())
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 quick._drop_data(Vector2.ZERO,valid)
 assert(app.rules.state.quickbar[5]==item.type and app.rules.state.items==old_items)
 assert(app.rules.inventory_action("move",{"uid":item.uid,"container":"warehouse","slot":0}))
 revision=app.rules.state.revision
 assert(not quick._can_drop_data(Vector2.ZERO,valid))
 quick._drop_data(Vector2.ZERO,valid)
 assert(app.rules.state.revision==revision)
 var bank_slot:=EditionItemSlot.new();root.add_child(bank_slot);bank_slot.setup(app,"warehouse",0);bank_slot._process(0)
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true
 var bank_before: Dictionary=app.rules.state.duplicate(true)
 for guard in ["modal","roster","dead"]:
  var hp_before=app.rules.state.hp
  if guard=="modal":app.windows.modal.show()
  if guard=="roster":app.mode="roster"
  if guard=="dead":app.rules.state.hp=0
  bank_slot.gui_input.emit(click)
  app.windows.modal.hide();app.mode="game";app.rules.state.hp=hp_before
  assert(app.rules.state==bank_before)
 print("PASS: warehouse right-click respects modal, roster and death guards")
 app.world.paused=true
 bank_slot.gui_input.emit(click)
 assert(app.rules.state.revision==revision and app.pending_message=="请继续游戏后操作物品")
 var bank:=EditionItemPanel.new();root.add_child(bank);bank.setup(app,"warehouse")
 app.selected_item_uid=item.uid
 var take: EditionSkinButton=bank.get_children().filter(func(n):return n is EditionSkinButton and n.text=="取出")[0]
 take.pressed.emit()
 assert(app.rules.state.revision==revision)
 app.world.paused=false
 for guard in ["modal","roster","dead"]:
  var hp_before=app.rules.state.hp
  if guard=="modal":app.windows.modal.show()
  if guard=="roster":app.mode="roster"
  if guard=="dead":app.rules.state.hp=0
  take.pressed.emit()
  app.windows.modal.hide();app.mode="game";app.rules.state.hp=hp_before
  assert(app.rules.state.revision==revision)

 app.world.paused=false;take.pressed.emit()
 assert(EditionInventory.find_item(app.rules.state,item.uid).container=="inventory")
 var transferred: Dictionary=app.rules.state.duplicate(true)
 app.selected_item_uid=""
 bank_slot.gui_input.emit(click);bank_slot.pressed.emit()
 assert(bank_slot._get_drag_data(Vector2.ZERO)==null)
 assert(app.rules.state==transferred and app.selected_item_uid.is_empty())
 print("PASS: stale item cell cannot click or drag an item moved to another container")
 bank_slot.queue_free();bank.queue_free()
 root.remove_child(quick);root.remove_child(slot)
 var detached_state: Dictionary=app.rules.state.duplicate(true)
 assert(not quick._can_drop_data(Vector2.ZERO,valid) and not slot._can_drop_data(Vector2.ZERO,valid))
 quick._drop_data(Vector2.ZERO,valid);slot._drop_data(Vector2.ZERO,valid)
 assert(app.rules.state==detached_state)
 print("PASS: detached item and quickbar targets reject drops without state changes")
 quick.queue_free()
 print("PASS: malformed, stale, foreign, paused and dead drops rejected; valid move succeeds; quickbar save rollback, retry, no item consumption, warehouse rejection; paused right-click/button blocked and resume succeeds")
 slot.queue_free();app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
