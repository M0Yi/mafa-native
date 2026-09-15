extends SceneTree
var characters: Dictionary={}
func collect(value: Variant) -> void:
	if value is String:
		for i in range(value.length()):
			var code: int=value.unicode_at(i)
			if (code>=0x3400 and code<=0x9fff) or (code>=0x20000 and code<=0x3134f):characters[code]=true
	elif value is Dictionary:
		for key in value:collect(key);collect(value[key])
	elif value is Array:
		for entry in value:collect(entry)
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/world-text-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(6):await process_frame
	app.set_process(false)
	collect(EditionRules.Story.data().chapters);collect(EditionRules.Story.data().quests)
	var npc_count:=0
	for npc in EditionRegion.data().npcs:
		if npc.get("enabled",false):collect(npc.name);npc_count+=1
	for name in EditionRegion.data().monsters:collect(name)
	for map in app.resources.map_by_id.values():collect(map.name)
	var missing: Array=[]
	for code in characters:
		if not app.font.has_char(code):missing.append(String.chr(code))
	var failures: Array=[]
	if app.world.font!=app.font:failures.append("world and windows do not share configured Chinese font")
	if not missing.is_empty():failures.append("catalog has missing Chinese glyphs")
	app.start_character({"id":"font-layout","name":"远山","job":"战士","gender":"男"});app.world.paused=true
	var layout_checks:=0
	var monsters: Array=app.world.entities.filter(func(e):return e.kind=="monster")
	if monsters.is_empty():failures.append("no live monster labels checked")
	for density in [1.0,2.0]:
		app.world.display_density=density
		for zoom in [1.0,2.0,3.0]:
			app.world.zoom=zoom
			for monster in monsters:
				var shape: Dictionary=app.world.labels.layout(monster)
				layout_checks+=3
				if shape.name_rect.size.x>ClassicPlayer.CELL.x*zoom+1:failures.append("name exceeds one map cell")
				if shape.health_rect.size.x>ClassicPlayer.CELL.x*zoom:failures.append("health bar exceeds one map cell")
				if absf(shape.name_rect.get_center().x-shape.head.x)>1:failures.append("name not centered above head")
	var report:={"checks":characters.size()+1+layout_checks,"label_layout_checks":layout_checks,"failures":failures,"unique_han_characters":characters.size(),"enabled_npcs":npc_count,"missing":missing,"scope":"Chinese glyph availability in current quest/chapter text, enabled NPC names, monster catalog names and map names; shared world/UI font; not all glyph rendering or layout acceptance"}
	FileAccess.open("res://../artifacts/world-story/world-text-coverage-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(4):await process_frame
	quit(0 if failures.is_empty() else 1)
