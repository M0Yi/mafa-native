extends SceneTree
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	if not ok:failures.append(note)
func corrupt(path: String,text: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func _initialize():call_deferred("run")
func run() -> void:
	var folder:="/tmp/mafa-store-recovery-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var store:=EditionStore.new();store.path=folder.path_join("world.sqlite")
	check(store.open(),"fresh database opens")
	var state:={"schema_version":1,"revision":0,"gold":560,"quests":{"nv_equip":"done"}}
	check(store.commit("fixture",state,"fixture"),"persist fixture")
	check(store.backup(),"backup")
	store.close()
	DirAccess.remove_absolute(store.path)
	check(store.open(),"missing primary recovers")
	check(store.load_world("fixture").get("gold")==560,"missing primary preserves backup progress")
	store.close()
	corrupt(store.path,"deliberately corrupt fixture")
	check(store.open(),"corrupt primary recovers")
	check(store.load_world("fixture").get("quests",{}).get("nv_equip")=="done","corrupt recovery retains quests")
	store.close()
	var quarantines: Array=[]
	for file in DirAccess.get_files_at(folder):
		if file.contains(".corrupt-"):quarantines.append(file)
	check(not quarantines.is_empty(),"corrupt original retained")
	for file in quarantines:check(FileAccess.get_file_as_string(folder.path_join(file))=="deliberately corrupt fixture","quarantine bytes unchanged")
	corrupt(store.path,"bad primary")
	corrupt(store.path+".backup.sqlite","bad backup")
	check(not store.open(),"both damaged rejected")
	check(FileAccess.get_file_as_string(store.path)=="bad primary" and FileAccess.get_file_as_string(store.path+".backup.sqlite")=="bad backup","both bad files retained")
	store.close()
	var orphan:=EditionStore.new();orphan.path=folder.path_join("orphan.sqlite")
	corrupt(orphan.path+"-wal","orphan WAL fixture")
	check(not orphan.open(),"missing primary with orphan log rejected")
	check(not FileAccess.file_exists(orphan.path),"orphan log cannot create new primary")
	check(FileAccess.get_file_as_string(orphan.path+"-wal")=="orphan WAL fixture","orphan WAL preserved")
	orphan.close()
	var report:={"failures":failures,"scope":"isolated actual SQLite VACUUM backup, missing/corrupt primary recovery and quarantine, both damaged refusal and orphan WAL preservation; not power-loss or graphical recovery acceptance"}
	FileAccess.open("res://../artifacts/closeout-store-recovery.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	quit(0 if failures.is_empty() else 1)
