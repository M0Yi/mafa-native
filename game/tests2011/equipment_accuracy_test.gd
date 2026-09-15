extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
 app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 app.store.path="/tmp/equipment-accuracy-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
 for i in range(5):await process_frame
 app.set_process(false);app.start_character({"id":"accuracy","name":"准确检查","gender":"男","job":"战士"})
 var next: Dictionary=app.rules.state.duplicate(true);next.level=30;next.gold=100000;app.rules.apply(next,"level_budget_fixture")
 var base: int=app.rules.melee_accuracy()
 expect(EditionRules.item_accuracy("bracelet")==1 and EditionRules.item_accuracy("ref:145")==2,"source bracelet accuracy mapping")
 expect(EditionRules.item_accuracy("robe")==0,"armor defense is not accuracy")
 expect(app.rules.shop("ref:145",1),"purchase real sharp bracelet")
 expect(app.rules.melee_accuracy()==base,"inventory gear grants no accuracy")
 expect(app.rules.use_item("ref:145") and app.rules.melee_accuracy()==base+2,"wearing bracelet adds exact accuracy")
 var uid:=""
 for item in app.rules.state.items:
  if item.type=="ref:145":uid=item.uid
 var before: Dictionary=app.rules.state.duplicate(true)
 app.store.db.query("PRAGMA query_only=ON;")
 expect(not app.rules.inventory_action("move",{"uid":uid,"container":"warehouse","slot":0}) and app.rules.state==before and app.rules.melee_accuracy()==base+2,"failed unequip keeps accuracy")
 app.store.db.query("PRAGMA query_only=OFF;")
 expect(app.rules.inventory_action("move",{"uid":uid,"container":"warehouse","slot":0}) and app.rules.melee_accuracy()==base,"warehouse gear grants no accuracy")
 expect(app.rules.inventory_action("move",{"uid":uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")}) and app.rules.use_item("ref:145"),"re-equip same instance")
 next=app.rules.state.duplicate(true);EditionInventory.find_item(next,uid).durability=0;app.rules.apply(next,"broken_fixture")
 expect(app.rules.melee_accuracy()==base,"broken equipment grants no accuracy")
 next=app.rules.state.duplicate(true);EditionInventory.find_item(next,uid).durability=1;app.rules.apply(next,"durability_fixture")
 expect(app.rules.melee_accuracy()==base+2,"one durability restores source accuracy")
 expect(app.rules.shop("bracelet",1) and app.rules.use_item("bracelet"),"equip second bracelet")
 expect(app.rules.melee_accuracy()==base+3,"both independently equipped bracelets contribute")
 var disk: Dictionary=app.store.load_world(app.rules.character.id)
 expect(EditionInventory.find_item(disk,uid).durability==1,"equipped instance durability persisted")
 var report:={"checks":checks,"failures":failures,"scope":"real item source accuracy, purchase/equip/move transactions, readonly rollback, broken and partial durability, two slots; level and budget fixtures, no physical input or complete equipment combat balance"}
 FileAccess.open("res://../artifacts/world-story/equipment-accuracy-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
 for i in range(3):await process_frame
 quit(0 if failures.is_empty() else 1)
