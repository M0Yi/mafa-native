extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-item-use-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"split","name":"拆分检查","job":"战士","gender":"女"})
 var potion: Dictionary=app.rules.state.items.filter(func(i):return i.type=="potion")[0]
 app.selected_item_uid=potion.uid
 var view:=EditionItemPanel.new();root.add_child(view);view.setup(app,"inventory",true)
 var use: EditionSkinButton=view.get_children().filter(func(n):return n is EditionSkinButton and n.tooltip_text=="使用选中物品")[0]
 app.rules.message="旧的成功消息"
 app.gameplay.potion_ready=app.elapsed+10
 var revision: int=app.rules.state.revision
 use.pressed.emit()
 assert(app.pending_message=="药品冷却中")
 assert(app.rules.state.revision==revision)
 app.gameplay.potion_ready=0
 use.pressed.emit()
 assert(app.pending_message==app.rules.message and app.rules.state.inventory.potion==4)
 revision=app.rules.state.revision
 app.world.paused=true
 use.pressed.emit()
 assert(app.pending_message=="请继续游戏后使用物品")
 app.world.paused=false;app.rules.state.hp=0
 use.pressed.emit()
 assert(app.pending_message=="死亡状态不能使用物品")
 app.rules.state.hp=130
 assert(not app.gameplay.use_item_uid("missing-item"))
 assert(app.pending_message=="物品已不存在，请重新选择")
 assert(app.rules.state.revision==revision and app.rules.state.inventory.potion==4)
 var next: Dictionary=app.rules.state.duplicate(true)
 var stone:=EditionInventory.make_item("return_stone",1,"warehouse",0)
 next.items.append(stone);EditionInventory.mirror(next)
 assert(app.rules.apply(next,"warehouse_return_fixture"))
 app.pending_attack={"fixture":true}
 var old_cell: Vector2i=app.world.player.cell
 revision=app.rules.state.revision
 assert(not app.gameplay.use_item_uid(stone.uid))
 assert(app.pending_message=="请先把回城物品取回背包")
 assert(app.rules.state.revision==revision and app.pending_attack=={"fixture":true})
 assert(app.world.player.cell==old_cell and EditionInventory.find_item(app.rules.state,stone.uid).count==1)
 print("PASS: item use cooldown feedback preserved; rejection does not consume; successful use consumes once; paused/dead/stale feedback and no mutation; warehouse return does not change scene")
 var app_ref:=weakref(app);var view_ref:=weakref(view)
 view.queue_free();app.queue_free();await process_frame;await create_timer(0.2).timeout
 assert(app_ref.get_ref()==null and view_ref.get_ref()==null)
 print("PASS: application and item panel nodes released")
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
