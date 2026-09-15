extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-logout-failure-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"logout","name":"返回保存","job":"战士","gender":"女"})
 var before: Dictionary=app.rules.state.duplicate(true)
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 app.classic_hud.logout();app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(app.mode=="game" and app.rules.state==before and not app.pending_message.is_empty())
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 var blocked_backup: String=path+".backup.sqlite.tmp"
 assert(DirAccess.make_dir_absolute(blocked_backup)==OK)
 app.classic_hud.logout();app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(app.mode=="game" and not app.pending_message.is_empty())
 assert(not app.store.error.is_empty())
 assert(DirAccess.remove_absolute(blocked_backup)==OK)
 assert(app.store.backup() and app.store.error.is_empty())
 assert(not app.store.load_world("logout").is_empty())
 print("PASS: backup failure after world write stays in game and preserves saved world")
 app.classic_hud.logout();app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(app.entry.page=="roster" and app.mode!="game")
 assert(not app.store.load_world("logout").is_empty())
 print("PASS: failed logout save stays in game; retry persists world and returns to roster")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
