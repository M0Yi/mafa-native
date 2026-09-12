class_name EditionStore
extends RefCounted

var db: SQLite
var error := ""
var path := "user://worlds.sqlite"
var warning := ""
var opened := false

func open() -> bool:
	error=""
	db=SQLite.new();db.path=path;db.verbosity_level=0
	opened=db.open_db()
	if not opened or not db.query("PRAGMA quick_check;") or db.query_result.is_empty() or str(db.query_result[0].values()[0])!="ok":
		if opened:db.close_db();opened=false
		if not recover_backup():return false
		return open()
	# Inspect an existing schema before making any changes to a newer database.
	if not db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='metadata';"):error=db.error_message;return false
	if not db.query_result.is_empty():
		var version:=read_metadata("schema_version")
		if version!="1":error="不支持的存档版本："+version+"；数据库未修改";close();return false
	for sql in ["PRAGMA foreign_keys=ON;","PRAGMA journal_mode=WAL;","PRAGMA synchronous=FULL;",
		"CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS worlds (character_id TEXT PRIMARY KEY, revision INTEGER NOT NULL, state TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS operations (id TEXT PRIMARY KEY, character_id TEXT NOT NULL, action TEXT NOT NULL, world_revision INTEGER NOT NULL);",
		"INSERT OR IGNORE INTO metadata VALUES ('schema_version','1');"]:
		if not db.query(sql):error=db.error_message;return false
	return true

func read_metadata(key: String) -> String:
	error=""
	if not db.query_with_bindings("SELECT value FROM metadata WHERE key=?;",[key]):error=db.error_message;return ""
	return str(db.query_result[0].value) if not db.query_result.is_empty() else ""

func put_metadata(key: String,value: String) -> bool:
	error=""
	var ok:=db.query_with_bindings("INSERT INTO metadata(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value;",[key,value])
	if not ok:error=db.error_message
	return ok

func load_world(id: String) -> Dictionary:
	error=""
	if not db.query_with_bindings("SELECT revision,state FROM worlds WHERE character_id=?;",[id]):error=db.error_message;return {}
	if db.query_result.is_empty():return {}
	var row=db.query_result[0];var state=JSON.parse_string(row.state)
	if not state is Dictionary or state.get("schema_version")!=1:
		error="角色状态损坏或版本不支持；原始数据库已保留";return {}
	state["revision"]=int(row.revision)
	return state

func commit(id: String,state: Dictionary,action: String,operation_id: String="") -> bool:
	error=""
	if operation_id.is_empty():operation_id=Crypto.new().generate_random_bytes(16).hex_encode()
	if not db.query("BEGIN IMMEDIATE;"):error=db.error_message;return false
	var rev:=int(state.get("revision",0));var next:=state.duplicate(true);next.revision=rev+1
	var ok:=db.query_with_bindings("SELECT 1 FROM operations WHERE id=?;",[operation_id])
	if ok and not db.query_result.is_empty():db.query("ROLLBACK;");error="操作已提交，不能重复执行";return false
	ok=ok and db.query_with_bindings("SELECT revision FROM worlds WHERE character_id=?;",[id])
	if ok and ((db.query_result.is_empty() and rev!=0) or (not db.query_result.is_empty() and int(db.query_result[0].revision)!=rev)):
		db.query("ROLLBACK;");error="存档版本冲突，请重新读取角色";return false
	ok=ok and db.query_with_bindings("INSERT INTO worlds(character_id,revision,state) VALUES(?,?,?) ON CONFLICT(character_id) DO UPDATE SET revision=excluded.revision,state=excluded.state;",[id,rev+1,JSON.stringify(next)])
	ok=ok and db.query_with_bindings("INSERT INTO operations VALUES(?,?,?,?);",[operation_id,id,action,rev+1])
	if ok:ok=db.query("COMMIT;")
	if not ok:error=db.error_message;db.query("ROLLBACK;");return false
	state.revision=rev+1
	return true

func close() -> void:
	if db!=null and opened:db.query("PRAGMA wal_checkpoint(TRUNCATE);");db.close_db();opened=false
	db=null

func backup() -> bool:
	var target:=ProjectSettings.globalize_path(path+".backup.sqlite")
	var temporary:=target+".tmp"
	if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	if not db.query_with_bindings("VACUUM INTO ?;",[temporary]):error=db.error_message;return false
	if DirAccess.rename_absolute(temporary,target)!=OK:error="备份替换失败："+target;return false
	return true

func recover_backup() -> bool:
	var original:=ProjectSettings.globalize_path(path)
	var backup_path:=original+".backup.sqlite"
	if not FileAccess.file_exists(backup_path):error="存档损坏且没有可恢复备份；原文件已保留："+original;return false
	var check:=SQLite.new();check.path=backup_path;check.read_only=true
	var good:=check.open_db()
	if good:good=check.query("PRAGMA quick_check;") and not check.query_result.is_empty() and str(check.query_result[0].values()[0])=="ok"
	check.close_db()
	if not good:error="主存档和备份均未通过检查；原文件均已保留";return false
	var quarantine:=original+".corrupt-"+str(Time.get_unix_time_from_system())
	for suffix in ["","-wal","-shm"]:
		if FileAccess.file_exists(original+suffix):
			if DirAccess.rename_absolute(original+suffix,quarantine+suffix)!=OK:error="无法隔离损坏存档";return false
	if DirAccess.copy_absolute(backup_path,original)!=OK:error="无法复制存档备份";return false
	warning="存档损坏，已恢复最近备份。损坏文件保留在："+quarantine
	return true
