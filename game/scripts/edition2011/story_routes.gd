extends RefCounted
# Route nodes are walkable components, not just map IDs: disconnected islands
# in the same MAP must never be silently joined by a route preview.
static func plan(by_map: Dictionary,start_map: String,target_map: String,cell: Vector2i,navigation,target_components: Array=[]) -> Array:
	if start_map==target_map and target_components.is_empty():return []
	var incoming: Dictionary={};var targets: Dictionary={}
	for map_id in by_map:
		for route in by_map[map_id]:
			if not route.has("component") or not route.has("target_component"):continue
			var source: String=JSON.stringify(route.component);var target: String=JSON.stringify(route.target_component)
			if not incoming.has(target):incoming[target]=[]
			incoming[target].append(route)
			if route.target_map==target_map and (target_components.is_empty() or route.target_component in target_components):targets[target]=true
	var queue: Array=targets.keys();var distance: Dictionary={};var next_step: Dictionary={}
	for node in queue:distance[node]=0
	var head:=0
	while head<queue.size():
		var node: String=queue[head];head+=1
		for route in incoming.get(node,[]):
			var source: String=JSON.stringify(route.component)
			if distance.has(source):continue
			distance[source]=int(distance[node])+1;next_step[source]=route;queue.append(source)
	var avoid: Array[Vector2i]=[]
	for gate in by_map.get(start_map,[]):avoid.append(Vector2i(gate.cell[0],gate.cell[1]))
	var candidates: Array=[]
	for route in by_map.get(start_map,[]):
		var target: String=JSON.stringify(route.target_component)
		if distance.has(target):candidates.append(route)
	candidates.sort_custom(func(a,b):
		var da: int=distance[JSON.stringify(a.target_component)];var db: int=distance[JSON.stringify(b.target_component)]
		if da!=db:return da<db
		return Vector2(Vector2i(a.cell[0],a.cell[1])-cell).length_squared()<Vector2(Vector2i(b.cell[0],b.cell[1])-cell).length_squared())
	for first in candidates:
		var at:=Vector2i(first.cell[0],first.cell[1])
		if cell!=at and navigation.path_avoiding(cell,at,avoid).is_empty():continue
		var result: Array=[first];var node: String=JSON.stringify(first.target_component)
		while not targets.has(node):
			if not next_step.has(node):return []
			var route: Dictionary=next_step[node];result.append(route);node=JSON.stringify(route.target_component)
		return result
	return []

static func npc_components(resources,npc: Dictionary) -> Array:
	var meta: Dictionary=resources.map_by_id.get(npc.map,{})
	if meta.is_empty():return []
	var w:=int(meta.width);var h:=int(meta.height)
	var mask:=FileAccess.get_file_as_bytes(EditionResources.BASE+"maps/"+str(npc.map)+".walk")
	if mask.size()!=w*h:return []
	var rows: Array=[]
	for y in range(h):rows.append(mask.slice(y*w,(y+1)*w))
	var nav:=ClassicNavigation.new();nav.configure({"size":[w,h],"walkable":rows})
	var occupied: Array[Vector2i]=[]
	for person in resources.npcs_by_map.get(npc.map,[]):occupied.append(Vector2i(person.cell[0],person.cell[1]))
	nav.set_occupied(occupied)
	var approaches: Array[Vector2i]=[];var at:=Vector2i(npc.cell[0],npc.cell[1])
	for candidate in ClassicNavigation.npc_approach_cells(at):
		if nav.walkable(candidate):approaches.append(candidate)
	var result: Array=[]
	for routes in resources.connections.by_map.values():
		for route in routes:
			if route.target_map!=npc.map or route.target_component in result:continue
			var landing:=Vector2i(route.target_cell[0],route.target_cell[1])
			for approach in approaches:
				if landing==approach or not nav.path(landing,approach).is_empty():result.append(route.target_component);break
	return result
