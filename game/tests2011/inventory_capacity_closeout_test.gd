extends SceneTree
func _initialize() -> void:
 var store:=EditionStore.new();store.path="/tmp/mafa-capacity-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 assert(store.open())
 var rules:=EditionRules.new();rules.store=store
 assert(rules.attach({"id":"capacity","name":"容量检查","job":"战士","gender":"女"}))
 for container in ["inventory","warehouse"]:
  var fixture:=rules.state.duplicate(true);fixture.items=[]
  var capacity:=48 if container=="inventory" else 50
  for slot in range(capacity):fixture.items.append(EditionInventory.make_item("potion",2,container,slot))
  EditionInventory.mirror(fixture)
  assert(rules.apply(fixture,"capacity_fixture"))
  var source: String=rules.state.items[0].uid
  var before:=rules.state.duplicate(true)
  assert(not rules.inventory_action("split",{"uid":source,"count":1}))
  assert(rules.state==before and rules.message.contains("没有空格"))
  var loaded:=store.load_world("capacity")
  assert(loaded.items==JSON.parse_string(JSON.stringify(before.items)))
  # Free one slot by moving its whole instance to the other container.
  var other: String="warehouse" if container=="inventory" else "inventory"
  assert(rules.inventory_action("move",{"uid":rules.state.items[-1].uid,"container":other,"slot":0}))
  var total: int=rules.state.inventory.get("potion",0)+rules.state.warehouse.get("potion",0)
  assert(rules.inventory_action("split",{"uid":source,"count":1}))
  assert(EditionInventory.find_item(rules.state,source).count==1)
  assert(rules.state.inventory.get("potion",0)+rules.state.warehouse.get("potion",0)==total)
  assert(EditionInventory.validate(rules.state))
 print("PASS: full inventory and warehouse reject split without mutation; freeing slot allows conserved split")
 var path:=store.path;store.close()
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
