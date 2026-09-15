extends SceneTree
func _initialize() -> void:
 var store:=EditionStore.new();store.path="/tmp/mafa-bundle-instance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 assert(store.open())
 var rules:=EditionRules.new();rules.store=store
 assert(rules.attach({"id":"packet","name":"材料包检查","job":"道士","gender":"女"}))
 for amount in [1,2]:
  var fixture:=rules.state.duplicate(true);fixture.items=[];fixture.level=60
  fixture.items.append(EditionInventory.make_item("ref:44",amount,"inventory",0))
  fixture.items.append(EditionInventory.make_item("ref:44",2,"inventory",5))
  EditionInventory.mirror(fixture);assert(rules.apply(fixture,"packet_fixture"))
  var before:=rules.state.duplicate(true)
  var selected: String=before.items[0].uid
  assert(store.db.query("PRAGMA query_only=ON;"))
  assert(not rules.inventory_action("use",{"uid":selected}) and rules.state==before)
  assert(store.db.query("PRAGMA query_only=OFF;"))
  var full:=rules.state.duplicate(true)
  for _i in range(46):full.items.append(EditionInventory.make_item("wood_sword",1,"inventory",EditionInventory.free_slot(full.items,"inventory")))
  EditionInventory.mirror(full);assert(rules.apply(full,"full_packet_fixture"))
  if amount==2:
   var full_before:=rules.state.duplicate(true)
   assert(not rules.inventory_action("use",{"uid":selected}))
   assert(rules.state==full_before and rules.message.contains("空格"))
   assert(rules.inventory_action("move",{"uid":rules.state.items[-1].uid,"container":"warehouse","slot":0}))
  assert(rules.inventory_action("use",{"uid":selected}))
  assert(EditionInventory.find_item(rules.state,before.items[1].uid)==before.items[1])
  var remaining:=EditionInventory.find_item(rules.state,selected)
  assert(remaining.is_empty() if amount==1 else remaining.count==amount-1 and remaining.slot==0)
  assert(rules.state.inventory.get("poison",0)==50)
  assert(rules.state.inventory.get("ref:44",0)==amount+1)
  assert(store.load_world("packet").items==JSON.parse_string(JSON.stringify(rules.state.items)))
 print("PASS: unpack consumes selected packet instance; other stack and failed-write retry preserved")
 var path:=store.path;store.close()
 for suffix in ["","-wal","-shm"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 quit()
