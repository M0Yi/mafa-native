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
 app.store.path="/tmp/return-scroll-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
 for i in range(8):await process_frame
 app.set_process(false);app.start_character({"id":"scroll","name":"回程检查","gender":"男","job":"战士"})
 expect(EditionRules.ITEMS["ref:134"].utility=="return","source scroll uses existing local return rule")
 var next: Dictionary=app.rules.state.duplicate(true);next.gold=10000;app.rules.apply(next,"budget_fixture")
 expect(app.rules.shop("ref:134",6),"buy original return scroll")
 app.enter_map("0126",Vector2i(9,10));app.world.paused=false;app.save_world()
 var npc: Dictionary=app.rules.story_npc("server:merchant:105")
 next=app.rules.state.duplicate(true);next.quests.story_palace_medicine="done"
 expect(app.rules.apply(next,"return_supplies_prerequisite"),"prepare prerequisite")
 expect(app.rules.story_action("story_palace_return_supplies","accept",npc.id,npc.map,app.world.player.cell),"accept return supplies quest")
 var accepted: Dictionary=app.rules.state.duplicate(true)
 app.store.db.query("PRAGMA query_only=ON;")
 expect(not app.rules.bind_bundle(npc.id,npc.map,app.world.player.cell,"ref:262") and app.rules.state==accepted,"failed binding preserves supplies and quest progress")
 app.store.db.query("PRAGMA query_only=OFF;")
 var coins: int=app.rules.state.gold
 expect(app.rules.bind_bundle(npc.id,npc.map,app.world.player.cell,"ref:262"),"bind six scrolls")
 expect(app.rules.state.gold==coins-100 and app.rules.state.inventory.get("ref:262",0)==1 and not app.rules.state.inventory.has("ref:134"),"bundle consumes exact scrolls and fee")
 expect(app.rules.story_action("story_palace_return_supplies","submit",npc.id,npc.map,app.world.player.cell),"successful scroll binding satisfies quest")
 var rewarded: Dictionary=app.rules.state.duplicate(true)
 expect(not app.rules.story_action("story_palace_return_supplies","submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==rewarded,"duplicate return supplies reward refused")
 var packed: Dictionary=app.rules.state.duplicate(true)
 expect(not app.rules.shop("ref:262",1) and app.rules.state==packed,"generic purchase cannot bypass recipe")
 app.store.db.query("PRAGMA query_only=ON;")
 expect(not app.gameplay.use_type("ref:262") and app.rules.state==packed and app.world.metadata.id=="0126","failed unpack preserves bundle and scene")
 app.store.db.query("PRAGMA query_only=OFF;")
 expect(app.gameplay.use_type("ref:262") and app.world.metadata.id=="0126" and app.rules.state.inventory.get("ref:134",0)==6 and not app.rules.state.inventory.has("ref:262"),"unpack produces six scrolls without teleport")
 var before: Dictionary=app.rules.state.duplicate(true)
 app.world.paused=true;expect(not app.gameplay.use_type("ref:134") and app.rules.state==before,"pause preserves scroll")
 app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;")
 expect(not app.gameplay.use_type("ref:134") and app.rules.state==before and app.world.metadata.id=="0126","failed save preserves scroll and restores map")
 app.store.db.query("PRAGMA query_only=OFF;")
 expect(app.gameplay.use_type("ref:134"),"use return scroll")
 expect(app.world.metadata.id=="0" and app.world.player.cell==EditionVillage.SPAWN,"actual scene returns to local spawn")
 expect(app.rules.state.inventory.get("ref:134",0)==5,"consume exactly one scroll")
 var disk: Dictionary=app.store.load_world(app.rules.character.id)
 expect(disk.map=="0" and disk.inventory.get("ref:134",0)==5,"location and consumption saved")
 var report:={"checks":checks,"failures":failures,"scope":"original return scroll catalog item, local village destination, actual map loading and consumption, pause/read-only rollback; positions/budget fixtures, no original PK prison or hardware input"}
 FileAccess.open("res://../artifacts/world-story/return-scroll-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
 for i in range(3):await process_frame
 quit(0 if failures.is_empty() else 1)
