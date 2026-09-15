extends SceneTree
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize():call_deferred("run")
func run() -> void:
	for container in ["inventory","warehouse"]:
		var capacity:=48 if container=="inventory" else 50
		var state: Dictionary={"items":[],"inventory":{},"warehouse":{},"equipment":{},"durability":{}}
		for slot in range(capacity):state.items.append(EditionInventory.make_item("wood_sword",1,container,slot,50+slot%20))
		EditionInventory.mirror(state)
		var retained: Array=state.items.slice(0,capacity-1).duplicate(true)
		state[container].wood_sword-=1;state[container].potion=3
		expect(EditionInventory.reconcile(state),"full container exchange uses consumed slot "+container)
		expect(state.items.size()==capacity and state[container].potion==3,"reward stack occupies exactly one freed slot")
		expect(state.items.slice(0,capacity-1)==retained,"other equipment IDs durability and slots unchanged")
		expect(EditionInventory.validate(state),"result validates")
		state[container].mana=1
		expect(not EditionInventory.reconcile(state),"extra unearned slot still refused")
	var report:={"checks":checks,"failures":failures,"scope":"full inventory and warehouse aggregate exchange, freed-slot admission, retained item identity/durability, real overflow refused"}
	FileAccess.open("res://../artifacts/world-story/exchange-order-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
