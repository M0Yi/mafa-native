extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():
	var a:=EditionInventory.make_item("ref:132",3,"inventory",0);a.purity=18
	var b:=EditionInventory.make_item("ref:132",2,"inventory",1);b.purity=19
	var state:={"items":[a,b],"inventory":{},"warehouse":{},"equipment":{},"durability":{}}
	EditionInventory.mirror(state)
	expect(EditionInventory.validate(state),"optional graded ore valid")
	expect(EditionInventory.operate(state,"move",{"uid":a.uid,"container":"inventory","slot":1}).is_empty(),"move between different grades")
	expect(state.items.size()==2 and a.purity==18 and b.purity==19,"different purity swaps rather than merges")
	expect(EditionInventory.operate(state,"split",{"uid":a.uid,"count":1}).is_empty(),"split graded ore")
	var parts: Array=state.items.filter(func(i):return i.get("purity",0)==18)
	expect(parts.size()==2 and int(parts[0].count)+int(parts[1].count)==3,"split preserves grade and quantity")
	EditionInventory.mirror(state);state.inventory["ref:132"]+=1
	expect(EditionInventory.reconcile(state),"legacy ore addition fits")
	var unknown: Array=state.items.filter(func(i):return not i.has("purity"))
	expect(unknown.size()==1 and int(unknown[0].count)==1,"unknown ore never inherits existing high grade")
	expect(EditionInventory.validate(JSON.parse_string(JSON.stringify(state))),"JSON roundtrip keeps valid purity")
	expect(EditionInventory.condition_text(a)=="纯度：18","graded ore description")
	expect(EditionInventory.condition_text(unknown[0])=="纯度：未知","unknown grade is explicit")
	expect(EditionInventory.condition_text(EditionInventory.make_item("sword",1,"inventory",4,37))=="耐久：37/100","equipment keeps durability")
	expect(EditionInventory.condition_text(EditionInventory.make_item("potion",3,"inventory",5))=="数量：3","consumable has no invented durability")
	a.purity=-1
	expect(not EditionInventory.validate(state),"invalid purity rejected")
	var report:={"checks":checks,"failures":failures,"scope":"inventory instance split, move, aggregate addition and JSON schema only; graded ore fixtures, no live acquisition, ground drops or crafting"}
	FileAccess.open("res://../artifacts/world-story/ore-purity-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
