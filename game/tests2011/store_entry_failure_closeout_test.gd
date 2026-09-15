extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var path:="/tmp/mafa-store-entry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 var seed:=SQLite.new();seed.path=path;seed.verbosity_level=0;assert(seed.open_db())
 assert(seed.query("CREATE TABLE metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL);"))
 assert(seed.query("INSERT INTO metadata VALUES ('schema_version','1');"))
 assert(seed.query("CREATE TRIGGER reject_metadata BEFORE INSERT ON metadata BEGIN SELECT RAISE(ABORT,'injected entry failure'); END;"));seed.close_db()
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.store.path=path
 root.add_child(app)
 assert(app.mode=="error" and app.pending_message.contains("injected entry failure"))
 assert(not app.store.opened and app.store.db==null and app.rules.state.is_empty())
 var owned: Array=[weakref(app.world),weakref(app.gameplay),weakref(app.world.light_layer),weakref(app.world.monster_effects),weakref(app.world.labels),weakref(app.entry.canvas)]
 app.queue_free();await process_frame
 assert(owned.all(func(reference):return reference.get_ref()==null))
 assert(seed.open_db())
 assert(seed.query("SELECT count(*) AS total FROM worlds;"));assert(seed.query_result[0].total==0)
 assert(seed.query("SELECT count(*) AS total FROM operations;"));assert(seed.query_result[0].total==0)
 seed.close_db()
 for suffix in ["","-wal","-shm"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("PASS: startup SQL failure shows error, releases store, creates no world or operation and tears down safely")
 quit()
