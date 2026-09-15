extends SceneTree
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():
	var items: Array=[]
	for grade in [30,17,18,-1,19]:
		var item:=EditionInventory.make_item("ref:132",2,"inventory",items.size())
		if grade>=0:item.purity=grade
		items.append(item)
	var stored:=EditionInventory.make_item("ref:132",50,"warehouse",0);stored.purity=18;items.append(stored)
	var state:={"items":items,"inventory":{},"warehouse":{},"equipment":{},"durability":{}}
	EditionInventory.mirror(state)
	var before:=state.duplicate(true)
	expect(not EditionInventory.consume_graded_ore(state,"ref:132",7,18) and state==before,"insufficient qualifying inventory is atomic; warehouse excluded")
	expect(not EditionInventory.consume_graded_ore(state,"ref:132",0,18) and state==before,"zero amount rejected")
	expect(not EditionInventory.consume_graded_ore(state,"potion",1,18) and state==before,"non ore rejected")
	expect(EditionInventory.consume_graded_ore(state,"ref:132",3,18),"consume qualifying ore")
	expect(state.items.filter(func(i):return i.container=="inventory" and i.get("purity",-1)==18).is_empty(),"lowest qualifying grade exhausted first")
	var grade19: Array=state.items.filter(func(i):return i.get("purity",-1)==19)
	expect(grade19.size()==1 and grade19[0].count==1,"next grade partial stack retained")
	for grade in [30,17,-1]:
		var kept: Array=state.items.filter(func(i):return i.container=="inventory" and i.get("purity",-1)==grade)
		expect(kept.size()==1 and kept[0].count==2,"preserve unselected grade "+str(grade))
	expect(state.warehouse["ref:132"]==50 and state.inventory["ref:132"]==7,"aggregate mirrors instances")
	expect(EditionInventory.validate(state),"result remains valid")
	before=state.duplicate(true)
	expect(not EditionInventory.consume_graded_ore(state,"ref:132",4,18) and state==before,"failed retry preserves partial stacks and mirrors")
	var Books=preload("res://scripts/edition2011/mystery_books.gd")
	for job in Books.WEAPONS:
		var info: String=Books.material_summary(state,job)
		expect(info.contains("背包合格金矿 3/%d"%int(Books.WEAPONS[job].count)) and info.contains("未知纯度 2"),"profession recipe uses inventory instances "+job)
		expect(info.contains(EditionRules.ITEMS[Books.WEAPONS[job].product].name),"profession weapon name "+job)
	var report:={"checks":checks,"failures":failures,"scope":"graded ore recipe material selection only, prepared instances; no natural mining, merchant crafting, SQLite or UI"}
	FileAccess.open("res://../artifacts/world-story/ore-material-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
