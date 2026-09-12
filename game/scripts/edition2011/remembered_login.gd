class_name EditionRememberedLogin
extends RefCounted

# Store a revocable device credential, never the user's password. The token is
# separate from SQLite backups and readable only by this OS user.
static func path(store: EditionStore) -> String:
	return ProjectSettings.globalize_path(store.path)+".login"

static func saved(accounts: EditionAccounts) -> Dictionary:
	var file:=FileAccess.open(path(accounts.store),FileAccess.READ)
	if file==null or file.get_length()>4096:return {}
	var value=JSON.parse_string(file.get_as_text())
	if not value is Dictionary or not value.get("username") is String or not value.get("token") is String:return {}
	var raw=JSON.parse_string(accounts.store.read_metadata("remembered_login"))
	if not raw is Dictionary:return {}
	for a in accounts.data.accounts:
		if a.username!=value.username:continue
		if raw.get("account")!=a.id or raw.get("credential")!=a.hash:return {}
		if str(value.token).length()!=64 or str(value.token).sha256_text()!=raw.get("token_hash"):return {}
		return value
	return {}

static func login(accounts: EditionAccounts,username: String) -> bool:
	accounts.current_id=""
	if accounts.healthy:
		var value:=saved(accounts)
		if not value.is_empty() and value.get("username","")==username.strip_edges().to_lower():
			for a in accounts.data.accounts:
				if a.username==value.username:accounts.current_id=a.id;accounts.message="";return true
	accounts.message="记住的登录信息已失效，请重新输入密码。"
	return false

static func forget(store: EditionStore) -> bool:
	var location:=path(store)
	if FileAccess.file_exists(location) and DirAccess.remove_absolute(location)!=OK:
		store.error="无法清除本机登录凭据，请重试。";return false
	return store.put_metadata("remembered_login","")

static func remember(accounts: EditionAccounts) -> bool:
	var a:=accounts.account()
	if a.is_empty():return false
	var token:=Crypto.new().generate_random_bytes(32).hex_encode()
	var location:=path(accounts.store);var temporary:=location+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:accounts.store.error="无法保存本机登录凭据。";return false
	# Apply permissions before writing the credential.
	if OS.get_name()!="Windows" and FileAccess.set_unix_permissions(temporary,384)!=OK:
		file.close();DirAccess.remove_absolute(temporary);accounts.store.error="无法保护本机登录凭据。";return false
	file.store_string(JSON.stringify({"username":a.username,"token":token}));file.flush()
	var error:=file.get_error();file.close()
	if error!=OK or DirAccess.rename_absolute(temporary,location)!=OK:
		DirAccess.remove_absolute(temporary);accounts.store.error="无法保存本机登录凭据。";return false
	return accounts.store.put_metadata("remembered_login",JSON.stringify({"account":a.id,"credential":a.hash,"token_hash":token.sha256_text()}))
