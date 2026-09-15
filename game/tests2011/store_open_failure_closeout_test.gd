extends SceneTree
func _initialize() -> void:
 var path:="/tmp/mafa-open-failure-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 var seed:=SQLite.new();seed.path=path
 assert(seed.open_db())
 assert(seed.query("CREATE TABLE metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL);"))
 assert(seed.query("INSERT INTO metadata VALUES ('schema_version','1');"))
 assert(seed.query("INSERT INTO metadata VALUES ('keep','original');"))
 assert(seed.query("CREATE TRIGGER reject_metadata BEFORE INSERT ON metadata BEGIN SELECT RAISE(ABORT,'injected initialization failure'); END;"))
 seed.close_db()
 var store:=EditionStore.new();store.path=path
 assert(not store.open())
 assert(not store.opened and store.db==null)
 assert(store.error.contains("injected initialization failure"))
 assert(seed.open_db())
 assert(seed.query("SELECT value FROM metadata WHERE key='keep';"))
 assert(seed.query_result[0].value=="original")
 assert(seed.query("DROP TRIGGER reject_metadata;"));seed.close_db()
 assert(store.open() and store.opened)
 assert(store.read_metadata("keep")=="original")
 store.close()
 for suffix in ["","-wal","-shm"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("PASS: failed store initialization closes connection, preserves error and existing metadata; retry opens")
 quit()
