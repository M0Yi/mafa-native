extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize() -> void:
	check(EditionItemAudio.sound("ref:135","select")==118,"oil selection retains reference click")
	check(EditionItemAudio.sound("ref:135","use")==-1,"oil has no reference independent use sound")
	check(EditionItemAudio.sound("potion","use")==108,"explicit medicine use mapping preserved")
	check(EditionItemAudio.sound("sword","use")==-1,"explicit null never falls through to selection")
	check(EditionItemAudio.sound("sword","equip")==111,"equipment category feedback retained")
	check(EditionItemAudio.sound("ref:193","use")==108,"reference medicine uses its own mapping")
	for row in EditionItemAudio.data().reference_items:
		for type in EditionRules.ITEMS:
			if EditionRules.ITEMS[type].name!=row.name or EditionItemAudio.data().runtime.has(type):continue
			check(EditionItemAudio.sound(type,"use")==(-1 if row.use==null else int(row.use)),"reference use mapping "+type)
	var report={"checks":checks,"failures":failures,"scope":"item event lookup against local reference catalog; no listening or playback timing acceptance"}
	FileAccess.open("res://../artifacts/world-story/item-use-audio-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
