extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-character-switch-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"first","name":"前一角色","job":"战士","gender":"男"})
 app.gameplay.potion_ready=5000.0;app.gameplay.pending_pickup="old-loot";app.gameplay.pickup_retry_left=2.0
 app.fight_timer=1.0;app.ai_elapsed=2.0;app.save_elapsed=3.0
 app.pending_attack={"id":"old-target"};app.gameplay.spell_events=[{"id":"old-spell"}]
 app.selected_item_uid="old-item";app.warehouse_keeper={"map":"0","cell":[1,1]}
 app.game_panel("残留测试窗口")
 var calls: Array=[]
 var old_button: Button=app.button("旧窗口操作",func():calls.append("old"))
 old_button.pressed.emit();assert(calls==["old"]);calls.clear()
 old_button.disabled=true;old_button.pressed.emit();assert(calls.is_empty());old_button.disabled=false
 var confirmations: Array=[]
 app.windows.confirm("旧角色确认",func():confirmations.append("old"))
 app.start_character({"id":"second","name":"后一角色","job":"法师","gender":"女"})
 old_button.pressed.emit();assert(calls.is_empty())
 assert(not app.windows.modal.visible)
 app.windows.modal.confirmed.emit();assert(confirmations.is_empty())
 app.windows.confirm("新角色确认",func():confirmations.append("new"))
 app.windows.modal.confirmed.emit();app.windows.modal.hide();assert(confirmations==["new"])
 assert(app.selected_item_uid.is_empty() and app.warehouse_keeper.is_empty() and app.windows.windows.is_empty())
 assert(app.fight_timer==0.0 and app.ai_elapsed==0.0 and app.save_elapsed==0.0)
 assert(app.pending_attack.is_empty() and app.gameplay.spell_events.is_empty())
 assert(app.gameplay.potion_ready==0.0 and app.gameplay.pending_pickup.is_empty() and app.gameplay.pickup_retry_left==0.0)
 var next: Dictionary=app.rules.state.duplicate(true);next.hp=1
 assert(app.rules.apply(next,"injury_fixture"))
 var before: int=int(app.rules.state.inventory.potion)
 assert(app.gameplay.use_type("potion"))
 assert(app.rules.state.inventory.potion==before-1 and app.rules.state.hp>1)
 var ready: float=app.gameplay.potion_ready
 app.start_character({"id":"second","name":"后一角色","job":"法师","gender":"女"})
 assert(app.gameplay.potion_ready==ready)
 before=int(app.rules.state.inventory.potion)
 assert(not app.gameplay.use_type("potion") and app.rules.state.inventory.potion==before)
 print("PASS: returning to the same character preserves current potion cooldown")
 print("PASS: character switch clears stale windows, selections and pickup; prior character clock cannot block new character potion")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
