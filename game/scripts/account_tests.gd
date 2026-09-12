extends SceneTree
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok:failures.append(description);push_error(description)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var a:=LocalAccounts.new();a.directory="/tmp/mafa-accounts-%d" % Time.get_ticks_usec()
	check(a.load_database(),"empty database")
	check(LocalAccounts.password_hash("password","salt".to_utf8_buffer(),1).hex_encode()=="120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b","PBKDF2 SHA256 vector 1")
	check(LocalAccounts.password_hash("password","salt".to_utf8_buffer(),2).hex_encode()=="ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43","PBKDF2 SHA256 vector 2")
	check(not a.register_account("../bad","test-password","test-password"),"unsafe username")
	check(not a.register_account("tester","short","short"),"short password")
	check(not a.register_account("tester","test-password","different"),"password mismatch")
	check(a.register_account("Tester","test-password","test-password"),"register")
	check(not a.register_account("TESTER","test-password","test-password"),"case insensitive duplicate")
	check(not FileAccess.get_file_as_string(a.directory.path_join("accounts.json")).contains("test-password"),"no plaintext password")
	check(not a.login("tester","wrong-password"),"reject wrong password")
	check(a.login("tester","test-password"),"login")
	check(a.create_character("../escape","战士","男").is_empty(),"unsafe character name")
	check(a.create_character("测试","刺客","男").is_empty(),"unknown job")
	var roles: Array=[]
	for spec in [["砍柴战士","战士","男"],["霜月法师","法师","女"],["清风道士","道士","男"]]:
		var c:=a.create_character(spec[0],spec[1],spec[2]);roles.append(c);check(not c.is_empty(),"create "+spec[1])
	check(a.create_character("第四角色","道士","女").is_empty(),"three slot limit")
	var folder:=a.character_directory(roles[0].id)
	DirAccess.make_dir_recursive_absolute(folder)
	var f:=FileAccess.open(folder.path_join("marker.txt"),FileAccess.WRITE);f.store_string("retained");f.close()
	check(not a.archive_character(roles[0].id,"错误名字"),"delete confirmation")
	check(a.archive_character(roles[0].id,roles[0].name),"archive role")
	check(FileAccess.file_exists(folder.path_join("marker.txt")),"archive retains save")
	check(a.character_directory(roles[0].id).is_empty(),"archived no longer playable")
	check(a.register_account("second","test-password","test-password"),"second account")
	check(a.data.accounts[0].salt!=a.data.accounts[1].salt and a.data.accounts[0].hash!=a.data.accounts[1].hash,"independent random salts")
	check(a.login("second","test-password"),"second login")
	check(a.character(roles[1].id).is_empty() and a.character_directory(roles[1].id).is_empty(),"account ownership boundary")
	check(a.change_password("tester","test-password","new-password","new-password"),"change password")
	check(not a.login("tester","test-password") and a.login("tester","new-password"),"password replacement")
	var b:=LocalAccounts.new();b.directory=a.directory
	check(b.load_database() and b.login("tester","new-password"),"reload persisted accounts")
	check(b.characters().size()==2,"reload roles")
	var dbpath:=a.directory.path_join("accounts.json")
	f=FileAccess.open(dbpath,FileAccess.WRITE);f.store_string("broken");f.close()
	check(not b.load_database() and not b.healthy,"corrupt db blocked")
	check(not b.register_account("erase","test-password","test-password") and FileAccess.get_file_as_string(dbpath)=="broken","corruption not overwritten")
	check(b.restore_backup() and b.healthy,"recover previous backup")
	print("ACCOUNT_TESTS ",JSON.stringify({"checks":checks,"failures":failures,"directory":a.directory}))
	quit(0 if failures.is_empty() else 1)
