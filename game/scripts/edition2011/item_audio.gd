class_name EditionItemAudio
extends RefCounted
static var catalog: Dictionary={}
static func data() -> Dictionary:
	if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/item-sounds.json"))
	return catalog
static func sound(type: String,event: String) -> int:
	var events: Dictionary=data().get("runtime",{}).get(type,{}).get("events",{})
	if events.has(event):return int(events[event]) if events[event]!=null else -1
	if EditionRules.ITEMS.has(type) and event in ["select","move","split","use","equip","unequip"]:
		for row in data().get("reference_items",[]):
			if row.name!=EditionRules.ITEMS[type].name:continue
			var id=row.get("use") if event=="use" else row.get("select")
			return int(id) if id!=null else -1
	return -1
