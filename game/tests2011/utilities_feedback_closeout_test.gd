extends SceneTree
func _initialize():call_deferred("run")
func click(app,prefix: String) -> void:
 for child in app.form.get_children():
  if child is Button and child.text.begins_with(prefix):child.pressed.emit();return
 assert(false,"button missing: "+prefix)
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-utilities-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"feedback","name":"商店反馈","job":"战士","gender":"女"})
 app.gameplay.show_utilities()
 var before: Dictionary=app.rules.state.duplicate(true)
 click(app,"购买 洗点石")
 assert(app.rules.state==before and app.notice.text==app.rules.message and app.notice.text.contains("金币不足"))
 click(app,"购买 回城石")
 assert(app.rules.state.gold==0 and app.rules.state.inventory.return_stone==1)
 assert(app.notice.text==app.rules.message and app.notice.text.contains("购买"))
 var next: Dictionary=app.rules.state.duplicate(true);next.level=2
 assert(app.rules.apply(next,"level_fixture"))
 click(app,"力量")
 assert(not app.notice.text.is_empty() and app.notice.text==app.rules.message)
 assert(app.form.get_children().any(func(c):return c is Button and c.text.begins_with("力量") and c.text.ends_with("已加 1")))
 print("PASS: insufficient funds preserves state; purchase updates inventory and inline notice; allocation rebuild retains result")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
