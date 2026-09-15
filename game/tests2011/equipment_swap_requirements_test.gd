extends SceneTree
func _initialize() -> void:
 var store:=EditionStore.new();store.path="/tmp/mafa-equip-swap-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 assert(store.open())
 var rules:=EditionRules.new();rules.store=store
 assert(rules.attach({"id":"swap","name":"交换检查","job":"战士","gender":"女"}))
 var male:=""
 var high:=""
 for id in EditionRules.ITEMS:
  var spec: Dictionary=EditionRules.ITEMS[id]
  if spec.get("slot")=="armor" and spec.get("gender")=="男":male=id
  if spec.get("slot")=="armor" and spec.get("gender","女")=="女" and int(spec.get("need",0))==0 and int(spec.get("need_level",0))>1:high=id
 assert(not male.is_empty() and not high.is_empty())
 for container in ["inventory","warehouse"]:
  for blocked in [male,high]:
   var fixture:=rules.state.duplicate(true);fixture.items=[];fixture.level=1
   fixture.items.append(EditionInventory.make_item("ref:5",1,"equipment",EditionInventory.SLOTS.find("armor"),73))
   fixture.items.append(EditionInventory.make_item(blocked,1,container,0,52))
   EditionInventory.mirror(fixture);assert(rules.apply(fixture,"swap_fixture"))
   var before:=rules.state.duplicate(true)
   assert(not rules.inventory_action("move",{"uid":before.items[0].uid,"container":container,"slot":0}))
   assert(rules.state==before)
   assert(rules.message.contains("性别") if blocked==male else rules.message.contains("需求"))
   assert(store.load_world("swap").items==JSON.parse_string(JSON.stringify(before.items)))
   # A free destination remains a valid unequip operation.
   assert(rules.inventory_action("move",{"uid":before.items[0].uid,"container":container,"slot":1}))
   assert(EditionInventory.find_item(rules.state,before.items[0].uid).durability==73)
 var valid:=rules.state.duplicate(true);valid.items=[]
 valid.items.append(EditionInventory.make_item("ref:5",1,"equipment",EditionInventory.SLOTS.find("armor"),73))
 valid.items.append(EditionInventory.make_item("ref:5",1,"inventory",0,52))
 EditionInventory.mirror(valid);assert(rules.apply(valid,"valid_swap_fixture"))
 var worn: String=rules.state.items[0].uid
 var replacement: String=rules.state.items[1].uid
 assert(rules.inventory_action("move",{"uid":worn,"container":"inventory","slot":0}))
 assert(EditionInventory.find_item(rules.state,worn).container=="inventory")
 assert(EditionInventory.find_item(rules.state,replacement).container=="equipment")
 assert(EditionInventory.find_item(rules.state,worn).durability==73 and EditionInventory.find_item(rules.state,replacement).durability==52)
 print("PASS: reverse equipment swaps enforce gender and level in bag and warehouse; failed swaps preserve saved instances")
 var path:=store.path;store.close()
 for suffix in ["","-wal","-shm"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 quit()
