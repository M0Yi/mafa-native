class_name EditionConnections
extends RefCounted

var by_map: Dictionary={}
var current: Dictionary={}
var routes: Array=[]
var armed:=false
var last_step:=0
var arrivals: Dictionary={}
var arrival_target:=""
var landing_cells: Dictionary={}

func load_catalog(map_ids: Dictionary) -> String:
	var path:="res://content/2011/map-connections.json"
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("format_version")!=1:return "地图连接目录缺失或格式错误"
	arrivals=data.get("arrivals",{})
	for route in data.get("routes",[]):
		if not route is Dictionary or not map_ids.has(route.get("map")) or not map_ids.has(route.get("target_map")):return "地图连接引用未知地图"
		for key in ["cell","target_cell"]:
			var cell=route.get(key)
			if not cell is Array or cell.size()!=2:return "入口坐标错误："+str(route.get("id",""))
		if not by_map.has(route.map):by_map[route.map]=[]
		by_map[route.map].append(route)
		if not landing_cells.has(route.target_map):landing_cells[route.target_map]=[]
		landing_cells[route.target_map].append(Vector2i(route.target_cell[0],route.target_cell[1]))
	for id in map_ids:
		if not by_map.has(id):return "地图没有出口："+str(id)
	return ""

func enter(id: String,player: ClassicPlayer) -> void:
	routes=by_map.get(id,[]);current.clear();player.path_avoid.clear()
	for route in routes:
		var point:=Vector2i(route.cell[0],route.cell[1])
		current[point]=route;player.path_avoid.append(point)
	# Loading on an exit never fires it. Walk off all adjacent trigger cells to
	# rearm; this also protects saved positions and held run input after arrival.
	armed=not current.has(player.cell);last_step=player.completed_steps
	arrival_target=str(current.get(player.cell,{}).get("target_map",""))

func poll(player: ClassicPlayer) -> Dictionary:
	if player.completed_steps==last_step:return {}
	last_step=player.completed_steps
	if not current.has(player.cell):armed=true;return {}
	if not armed and current[player.cell].target_map==arrival_target:return {}
	armed=false
	return current[player.cell]

func approach_cells(target: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i]=[target]
	if not current.has(target):return candidates
	var selected: Dictionary=current[target]
	if not selected.has("target_component"):return candidates
	for point in current:
		var route: Dictionary=current[point]
		if point==target or point.distance_to(target)>2:continue
		if route.target_map!=selected.target_map or route.get("target_component",[])!=selected.get("target_component",[]):continue
		candidates.append(point)
	return candidates

func title(route: Dictionary,resources: EditionResources) -> String:
	return str(resources.map_by_id[route.target_map].name)+( " · 单机通路" if route.kind!="reference" else "")+(" · 需勘察凭证" if route.target_map==EditionFireDragon.MAP else "")

func nearby(cell: Vector2i,radius:=14) -> Array:
	var result: Array=[]
	for route in routes:
		var at:=Vector2i(route.cell[0],route.cell[1])
		if (at-cell).length()>radius:continue
		if result.any(func(r):return r.target_map==route.target_map and r.get("target_component",[])==route.get("target_component",[]) and (at-Vector2i(r.cell[0],r.cell[1])).length()<=2):continue
		result.append(route)
	return result
