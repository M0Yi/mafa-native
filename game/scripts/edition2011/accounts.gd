class_name EditionAccounts
extends LocalAccounts

var store: EditionStore

func load_database() -> bool:
	current_id="";healthy=true;message=""
	var text:=store.read_metadata("accounts")
	if not store.error.is_empty():healthy=false;message=store.error;return false
	if text.is_empty():data={"version":1,"accounts":[]};return true
	var parsed=JSON.parse_string(text)
	if not valid_db(parsed):healthy=false;message="本地账号记录损坏，数据库保留，未覆盖。";return false
	data=parsed;return true

func persist(next: Dictionary) -> bool:
	if not healthy or not valid_db(next):message="账号数据无效";return false
	if not store.put_metadata("accounts",JSON.stringify(next)):message=store.error;return false
	data=next;return true

func import_old_accounts() -> bool:
	if not data.accounts.is_empty():message="新库已有账号，不能重复导入";return false
	var old:=OS.get_data_dir()+"/MafaNative/accounts.json"
	if not FileAccess.file_exists(old):message="未找到旧原型账号";return false
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(old))
	if not valid_db(parsed):message="旧账号记录格式无效，未导入";return false
	return persist(parsed.duplicate(true))

var last_recovery_code := ""

func register_account(username: String,password: String,confirm: String) -> bool:
	message="";last_recovery_code="";username=username.strip_edges().to_lower()
	if not healthy:message="先恢复账号资料，再注册。";return false
	if not matches(username,"^[a-z0-9_]{3,24}$"):message="账号需要 3–24 位英文字母、数字或下划线。";return false
	if password.length()<8 or password.length()>128:message="密码需要 8–128 个字符。";return false
	if password!=confirm:message="两次输入的密码不一致。";return false
	if data.accounts.size()>=32:message="本机账号数量已达上限。";return false
	for a in data.accounts:
		if a.username==username:message="这个本机账号已存在。";return false
	var crypto:=Crypto.new();var salt:=crypto.generate_random_bytes(16)
	var code:=crypto.generate_random_bytes(16).hex_encode()
	var next:=data.duplicate(true)
	next.accounts.append({"id":crypto.generate_random_bytes(16).hex_encode(),"username":username,"salt":salt.hex_encode(),"hash":password_hash(password,salt).hex_encode(),"iterations":ITERATIONS,"characters":[],"created":Time.get_unix_time_from_system(),"recovery_hash":code.sha256_text()})
	if not persist(next):return false
	last_recovery_code=code;return true

func recover_password(username: String,code: String,password: String,confirm: String) -> bool:
	current_id="";message="";username=username.strip_edges().to_lower()
	if not healthy:message="账号库需要恢复";return false
	if password.length()<8 or password.length()>128 or password!=confirm:message="新密码需为 8–128 位且两次一致";return false
	var next:=data.duplicate(true)
	for a in next.accounts:
		if a.username!=username:continue
		var digest: String=a.get("recovery_hash","")
		if digest.is_empty() or not Crypto.new().constant_time_compare(code.strip_edges().sha256_buffer(),digest.hex_decode()):break
		var salt:=Crypto.new().generate_random_bytes(16)
		a.salt=salt.hex_encode();a.hash=password_hash(password,salt).hex_encode()
		# Single use: a stolen old code cannot reset the password again.
		a.erase("recovery_hash")
		return persist(next)
	message="账号或恢复码不正确，或该账号尚未设置恢复码";return false

func restore_character(id: String) -> bool:
	message=""
	if characters().size()>=3:message="请先空出一个角色槽位";return false
	var next:=data.duplicate(true)
	for a in next.accounts:
		if a.id!=current_id:continue
		for c in a.get("archived",[]):
			if c.id!=id:continue
			for existing in a.characters:
				if existing.name.to_lower()==c.name.to_lower():message="已有同名角色，无法恢复";return false
			a.characters.append(c.duplicate(true))
			a.archived=a.archived.filter(func(item):return item.id!=id)
			return persist(next)
	message="未找到删除记录";return false
