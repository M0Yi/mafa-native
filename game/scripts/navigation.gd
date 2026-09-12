class_name ClassicNavigation
extends RefCounted

const DIRECTIONS = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
var grid := AStarGrid2D.new()
var cells: Array = []
var size := Vector2i.ZERO
var occupied: Dictionary={}

static func npc_approach_cells(at: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for direction in DIRECTIONS:result.append(at+direction)
	# Match the four-cell interaction radius; nearby positions stay preferred.
	for y in range(-4,5):
		for x in range(-4,5):
			if x*x+y*y>2 and x*x+y*y<=16:result.append(at+Vector2i(x,y))
	return result

func configure(map: Dictionary) -> void:
	occupied.clear()
	cells = map.walkable
	size = Vector2i(int(map.size[0]), int(map.size[1]))
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in range(size.y):
		for x in range(size.x):
			grid.set_point_solid(Vector2i(x,y), not walkable(Vector2i(x,y)))

func walkable(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y and bool(cells[p.y][p.x]) and not occupied.has(p)

func set_occupied(points: Array[Vector2i]) -> void:
	var previous:=occupied.keys();occupied.clear()
	for point in points:
		if grid.is_in_boundsv(point):occupied[point]=true
	for point in previous: grid.set_point_solid(point,not walkable(point))
	for point in occupied:grid.set_point_solid(point,true)

func can_step(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if not walkable(a) or not walkable(b) or d == Vector2i.ZERO or absi(d.x) > 1 or absi(d.y) > 1:
		return false
	return d.x == 0 or d.y == 0 or (walkable(a + Vector2i(d.x,0)) and walkable(a + Vector2i(0,d.y)))

func path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if not walkable(a) or not walkable(b):
		return []
	return grid.get_id_path(a,b)

func path_avoiding(a: Vector2i,b: Vector2i,avoid: Array[Vector2i]) -> Array[Vector2i]:
	var changed: Array[Vector2i]=[]
	for point in avoid:
		if point!=a and point!=b and walkable(point) and not grid.is_point_solid(point):
			grid.set_point_solid(point,true);changed.append(point)
	var result:=path(a,b)
	for point in changed:grid.set_point_solid(point,not walkable(point))
	return result

func would_disconnect(p: Vector2i) -> bool:
	# A stationary NPC must not sever a narrow corridor. Compare the cardinal
	# neighbors with its tile temporarily solid, preserving previous occupancy.
	if not walkable(p):return true
	var neighbors: Array[Vector2i]=[]
	for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		if walkable(p+d):neighbors.append(p+d)
	if neighbors.size()<2:return false
	occupied[p]=true;grid.set_point_solid(p,true)
	var blocked:=false
	for next in neighbors.slice(1):
		if path(neighbors[0],next).is_empty():blocked=true;break
	occupied.erase(p);grid.set_point_solid(p,false)
	return blocked

func mobile(p: Vector2i) -> bool:
	for d in DIRECTIONS:
		if can_step(p,p+d):return true
	return false

func nearest_mobile(p: Vector2i,max_radius:=16) -> Vector2i:
	if mobile(p):return p
	for radius in range(1,max_radius+1):
		for y in range(p.y-radius,p.y+radius+1):
			for x in range(p.x-radius,p.x+radius+1):
				var candidate:=Vector2i(x,y)
				if mobile(candidate):return candidate
	return Vector2i(-1,-1)
