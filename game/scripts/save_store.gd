class_name ClassicSave
extends RefCounted

var directory := "user://"
var message := ""

func valid_integer(value, minimum: int, maximum: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum

func load_state(nav: ClassicNavigation, map_id: String, spawn: Vector2i) -> Dictionary:
	var fallback := {"cell": spawn, "zoom": 2, "direction": 4}
	var path := directory.path_join("save.json")
	if not FileAccess.file_exists(path):
		return fallback
	var json := JSON.new()
	var valid := json.parse(FileAccess.get_file_as_string(path)) == OK
	var data = json.data
	valid = valid and data is Dictionary
	if valid:
		valid = data.get("version",0) == 1 and data.get("map_id","") == map_id
		valid = valid and data.get("cell") is Array and data.get("cell",[]).size() == 2
	if valid:
		for v in data.cell:
			valid = valid and (v is float or v is int) and is_finite(float(v)) and float(v) == floorf(float(v))
	if valid:
		var p := Vector2i(int(data.cell[0]),int(data.cell[1]))
		valid = nav.walkable(p)
		valid = valid and valid_integer(data.get("zoom"),1,3) and valid_integer(data.get("direction"),0,7)
		if valid:
			return {"cell":p,"zoom":int(data.zoom),"direction":int(data.direction)}
	var backup := directory.path_join("save.corrupt-%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var error := DirAccess.copy_absolute(path,backup)
	message = "存档无效，已保留备份并返回出生点。" if error == OK else "存档无效，原文件已保留；无法创建备份。"
	return fallback

func save_state(map_id: String, cell: Vector2i, zoom: int, direction: int) -> bool:
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("save.json")
	var temp := directory.path_join("save.tmp")
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		message = "存档写入失败：" + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"version":1,"map_id":map_id,"cell":[cell.x,cell.y],"zoom":zoom,"direction":direction}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temp,path)
	if error != OK:
		message = "存档保存失败：" + error_string(error)
		return false
	return true
