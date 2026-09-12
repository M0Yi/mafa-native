class_name ClassicResources
extends RefCounted

var map: Dictionary
var skills: Dictionary
var hero: Dictionary
var manifest: Dictionary
var atlases: Array[Texture2D] = []
var error_message := ""

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		error_message = "缺少资源文件：" + path
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		error_message = "资源格式错误：" + path
		return {}
	return parser.data

func load_all(base: String = "res://assets/generated") -> bool:
	manifest = read_json(base + "/manifest.json")
	if manifest.get("format_version", 0) != 1:
		if error_message.is_empty():
			error_message = "不支持的资源清单版本"
		return false
	# JSON is loaded directly; PNG integrity was verified at conversion/build time.
	for entry in manifest.get("outputs", []):
		if str(entry.path).ends_with(".json"):
			if FileAccess.get_sha256(base + "/" + entry.path) != entry.sha256:
				error_message = "资源校验失败：" + entry.path
				return false
	map = read_json(base + "/map.json")
	hero = read_json(base + "/hero.json")
	skills = read_json(base + "/skills.json")
	if not error_message.is_empty():
		return false
	if map.get("format_version", 0) != 1 or hero.get("format_version", 0) != 1:
		error_message = "不支持的地图或人物格式版本"
		return false
	if skills.get("format_version",0) != 1 or skills.get("skills",[]).size() != 33 or skills.get("actors",{}).size() != 4:
		error_message = "技能清单或陪练动作不完整：skills.json"
		return false
	var size_data: Array = map.get("size", [])
	if size_data.size() != 2 or map.get("walkable", []).size() != int(size_data[1]):
		error_message = "地图尺寸或通行数据无效"
		return false
	for row in map.walkable:
		if row.size() != int(size_data[0]):
			error_message = "地图通行数据行长度无效"
			return false
	for action in ["stand", "walk", "run"]:
		if hero.get("actions", {}).get(action, []).size() != 8:
			error_message = "缺少八方向人物动作：" + action
			return false
	for i in range(int(manifest.get("atlas_count", 0))):
		var path := base + "/atlas_%d.png" % i
		if not ResourceLoader.exists(path):
			error_message = "缺少图集：" + path
			return false
		var texture := load(path) as Texture2D
		if texture == null:
			error_message = "无法读取图集：" + path
			return false
		atlases.append(texture)
	if atlases.is_empty():
		error_message = "资源清单没有图集"
		return false
	return true
