class_name LocalAccounts
extends RefCounted

const ITERATIONS := 600000
const JOBS := ["战士","法师","道士"]
const GENDERS := ["男","女"]
var directory := "user://"
var data: Dictionary = {"version":1,"accounts":[]}
var current_id := ""
var healthy := true
var message := ""

static func matches(value: String,pattern: String) -> bool:
	var regex:=RegEx.new()
	return regex.compile(pattern)==OK and regex.search(value)!=null

static func password_hash(password: String,salt: PackedByteArray,iterations := ITERATIONS) -> PackedByteArray:
	var crypto:=Crypto.new();var key:=password.to_utf8_buffer()
	var block:=salt.duplicate();block.append_array(PackedByteArray([0,0,0,1]))
	var u:=crypto.hmac_digest(HashingContext.HASH_SHA256,key,block)
	var result:=u.duplicate()
	for i in range(1,iterations):
		u=crypto.hmac_digest(HashingContext.HASH_SHA256,key,u)
		for j in range(32):result[j]=result[j]^u[j]
	return result

func valid_db(value) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("accounts") is Array or value.accounts.size()>32:return false
	var ids: Dictionary={};var names: Dictionary={};var character_ids: Dictionary={}
	for a in value.accounts:
		if not a is Dictionary:return false
		for key in ["id","username","salt","hash"]:
			if not a.get(key) is String:return false
		if not matches(a.id,"^[0-9a-f]{32}$") or ids.has(a.id):return false
		if not matches(a.username,"^[a-z0-9_]{3,24}$") or names.has(a.username):return false
		if not matches(a.salt,"^[0-9a-f]{32}$") or not matches(a.hash,"^[0-9a-f]{64}$") or a.get("iterations")!=ITERATIONS:return false
		if not a.get("characters") is Array or a.characters.size()>3:return false
		if a.has("archived") and (not a.archived is Array or a.archived.size()>256):return false
		ids[a.id]=true;names[a.username]=true
		var char_names: Dictionary={}
		for c in a.characters:
			if not c is Dictionary or not c.get("id") is String or not c.get("name") is String:return false
			if not matches(c.id,"^[0-9a-f]{32}$") or character_ids.has(c.id):return false
			if not matches(c.name,"^[\\p{L}\\p{N}_·]{2,12}$") or char_names.has(c.name.to_lower()):return false
			if c.get("job") not in JOBS or c.get("gender") not in GENDERS or c.get("level")!=1:return false
			character_ids[c.id]=true;char_names[c.name.to_lower()]=true
	return true

func load_database() -> bool:
	current_id="";healthy=true;message=""
	var path:=directory.path_join("accounts.json")
	if not FileAccess.file_exists(path):data={"version":1,"accounts":[]};return true
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:healthy=false;message="账号资料无法读取："+path;return false
	var parsed=null
	if file.get_length()<=4*1024*1024:
		var parser:=JSON.new()
		if parser.parse(file.get_as_text())==OK:parsed=parser.data
	file.close()
	if not valid_db(parsed):
		healthy=false
		var backup:=directory.path_join("accounts.corrupt-%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		var copied:=DirAccess.copy_absolute(path,backup)==OK
		message="账号资料损坏。"+("已另存损坏文件；" if copied else "原文件仍保留；")+"请从备份恢复，避免覆盖现有角色。"
		return false
	data=parsed;return true

func persist(next: Dictionary) -> bool:
	if not healthy or not valid_db(next):message="账号资料校验失败，未写入。";return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:message="无法创建账号目录。";return false
	var path:=directory.path_join("accounts.json")
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:message="无法写入账号资料。";return false
	file.store_string(JSON.stringify(next));file.flush();var error:=file.get_error();file.close()
	if error!=OK:message="账号资料写入失败。";return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK:message="无法备份账号资料，本次修改未提交。";return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:message="账号资料保存失败。";return false
	data=next;return true

func restore_backup() -> bool:
	var path:=directory.path_join("accounts.json")
	var backup:=path+".bak"
	if not FileAccess.file_exists(backup):message="没有可用的账号备份。";return false
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(backup))
	if not valid_db(parsed):message="账号备份也已损坏，原文件仍保留。";return false
	var recovery:=path+".recovery"
	if DirAccess.copy_absolute(backup,recovery)!=OK or DirAccess.rename_absolute(recovery,path)!=OK:message="恢复备份失败。";return false
	return load_database()

func register_account(username: String,password: String,confirm: String) -> bool:
	message="";username=username.strip_edges().to_lower()
	if not healthy:message="先恢复账号资料，再注册。";return false
	if not matches(username,"^[a-z0-9_]{3,24}$"):message="账号需要 3–24 位英文字母、数字或下划线。";return false
	if password.length()<8 or password.length()>128:message="密码需要 8–128 个字符。";return false
	if password!=confirm:message="两次输入的密码不一致。";return false
	if data.accounts.size()>=32:message="本机账号数量已达上限。";return false
	for a in data.accounts:
		if a.username==username:message="这个本机账号已存在。";return false
	var crypto:=Crypto.new();var salt:=crypto.generate_random_bytes(16)
	var next:=data.duplicate(true)
	next.accounts.append({"id":crypto.generate_random_bytes(16).hex_encode(),"username":username,"salt":salt.hex_encode(),"hash":password_hash(password,salt).hex_encode(),"iterations":ITERATIONS,"characters":[],"created":Time.get_unix_time_from_system()})
	return persist(next)

func login(username: String,password: String) -> bool:
	current_id="";message="";username=username.strip_edges().to_lower()
	if not healthy:message="请先恢复账号资料。";return false
	if password.length()>128:message="账号或密码不正确。";return false
	for a in data.accounts:
		if a.username==username:
			var digest:=password_hash(password,a.salt.hex_decode())
			if Crypto.new().constant_time_compare(digest,a.hash.hex_decode()):current_id=a.id;return true
	message="账号或密码不正确。";return false

func change_password(username: String,old: String,password: String,confirm: String) -> bool:
	if password.length()<8 or password.length()>128:message="新密码需要 8–128 个字符。";return false
	if password!=confirm:message="两次输入的新密码不一致。";return false
	if not login(username,old):return false
	var id:=current_id;current_id=""
	var next:=data.duplicate(true);var salt:=Crypto.new().generate_random_bytes(16)
	for a in next.accounts:
		if a.id==id:a.salt=salt.hex_encode();a.hash=password_hash(password,salt).hex_encode()
	return persist(next)

func account() -> Dictionary:
	for a in data.accounts:
		if a.id==current_id:return a
	return {}

func characters() -> Array:
	return account().get("characters",[])

func character(id: String) -> Dictionary:
	for c in characters():
		if c.id==id:return c
	return {}

func character_directory(id: String) -> String:
	if current_id.is_empty() or character(id).is_empty():return ""
	return directory.path_join("profiles").path_join(current_id).path_join(id)

func create_character(name: String,job: String,gender: String,import_legacy := false) -> Dictionary:
	message="";name=name.strip_edges()
	if account().is_empty():message="请先登录。";return {}
	if not matches(name,"^[\\p{L}\\p{N}_·]{2,12}$"):message="角色名需要 2–12 个汉字、字母、数字或 _·。";return {}
	if job not in JOBS or gender not in GENDERS:message="请选择有效的职业和性别。";return {}
	if characters().size()>=3:message="每个账号最多创建 3 个角色。";return {}
	for c in characters():
		if c.name.to_lower()==name.to_lower():message="这个角色名已被使用。";return {}
	var c: Dictionary={"id":Crypto.new().generate_random_bytes(16).hex_encode(),"name":name,"job":job,"gender":gender,"level":1,"created":Time.get_unix_time_from_system()}
	var next:=data.duplicate(true)
	for a in next.accounts:
		if a.id==current_id:a.characters.append(c)
	if not persist(next):return {}
	if import_legacy and FileAccess.file_exists(directory.path_join("save.json")):
		var target:=character_directory(c.id)
		if DirAccess.make_dir_recursive_absolute(target)!=OK or DirAccess.copy_absolute(directory.path_join("save.json"),target.path_join("save.json"))!=OK:
			message="角色已创建，但旧版位置复制失败；原存档已保留。"
	return c

func archive_character(id: String,confirmation: String) -> bool:
	var c:=character(id)
	if c.is_empty() or c.name!=confirmation:message="请输入选中角色的完整名称。";return false
	var next:=data.duplicate(true)
	for a in next.accounts:
		if a.id==current_id:
			if not a.has("archived"):a.archived=[]
			if not a.archived is Array or a.archived.size()>=256:message="保留的删除记录已达上限，请先备份整理账号资料。";return false
			a.archived.append(c.duplicate(true))
			a.characters=a.characters.filter(func(item):return item.id!=id)
	return persist(next)
