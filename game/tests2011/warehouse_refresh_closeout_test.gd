extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-warehouse-refresh-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"refresh","name":"仓库刷新","job":"战士","gender":"女"})
 var view=load("res://scripts/edition2011/ui/controller_warehouse.gd").new();root.add_child(view);view.setup(app,{"name":"测试保管员"})
 var uid: String=view.rows[0].uid
 var next: Dictionary=app.rules.state.duplicate(true)
 EditionInventory.find_item(next,uid).count-=1;EditionInventory.mirror(next)
 assert(app.rules.apply(next,"external_consumption_fixture"))
 for i in range(8):await process_frame
 assert(view.rows[view.cursor].uid==uid and view.rows[view.cursor].count==4)
 assert(view.list.get_item_text(view.cursor).ends_with("×4"))
 next=app.rules.state.duplicate(true)
 next.items=next.items.filter(func(item):return item.uid!=uid);EditionInventory.mirror(next)
 assert(app.rules.apply(next,"external_removal_fixture"))
 for i in range(8):await process_frame
 assert(not view.rows.any(func(item):return item.uid==uid) and view.cursor<view.rows.size())
 print("PASS: external item quantity refresh preserves selection; removed item leaves no stale row")
 view.queue_free();app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
