extends SceneTree
# Invoke the application's close notification, not an OS mouse event.
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-window-close-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"windowclose","name":"关闭保存","job":"战士","gender":"女"})
 app.play_sound_id(106)
 var before: Dictionary=app.rules.state.duplicate(true)
 var track=app.music.stream
 assert(track!=null)
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 assert(app.mode=="game" and app.store.opened and app.rules.state==before)
 assert(app.music.stream==track and not app.pending_message.is_empty())
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 print("PASS: failed window-close save retains state and audio")
 app._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 assert(not app.store.opened and app.music.stream==null and app.resources.sounds.is_empty())
 for player in app.effects:assert(player.stream==null and not player.playing)
 var check:=EditionStore.new();check.path=path;assert(check.open())
 assert(not check.load_world("windowclose").is_empty())
 assert(FileAccess.file_exists(path+".backup.sqlite"));check.close()
 print("PASS: successful window close saves, backs up and clears audio before quitting")
 track=null
 app.free()
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
