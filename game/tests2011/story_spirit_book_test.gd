extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
 checks+=1
 if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
 app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 app.store.path="/tmp/story-spirit-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
 for i in range(5):await process_frame
 app.set_process(false);app.start_character({"id":"tao","name":"心法学徒","gender":"女","job":"道士"})
 var next: Dictionary=app.rules.state.duplicate(true);next.level=8;next.gold=10000;next.quests.story_apprentice_book="done";app.rules.apply(next,"level_budget_prerequisite_fixture")
 var q: Dictionary=Story.quest("story_tao_spirit_book");var follow: Dictionary=Story.quest("story_tao_spirit_return");var npc: Dictionary=app.rules.story_npc(q.start_npc)
 app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN);app.world.paused=false
 expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,app.world.player.cell),"accept mentor branch")
 expect(not Story.ready(app.rules.state,q),"missing healing knowledge blocks reward")
 expect(app.rules.shop("ref:15",1) and app.rules.use_item("ref:15"),"learn healing through actual book")
 expect(Story.ready(app.rules.state,q),"learned healing readies book commission")
 expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell),"mentor grants spirit book")
 expect(app.rules.state.inventory.get("ref:19",0)==1 and not app.rules.state.skills.has("spirit"),"reward grants book without automatic learning")
 expect(app.rules.story_action(follow.id,"accept",npc.id,npc.map,app.world.player.cell),"accept learning return")
 var before: Dictionary=app.rules.state.duplicate(true)
 expect(not app.rules.use_item("ref:19") and app.rules.state==before,"below level nine preserves book")
 expect(not Story.ready(app.rules.state,follow),"carrying book does not complete return")
 next=app.rules.state.duplicate(true);next.level=9;app.rules.apply(next,"level_nine_fixture")
 var keys: Dictionary=app.rules.state.skill_keys.duplicate(true)
 expect(app.rules.melee_accuracy()==5,"unlearned base accuracy follows reference")
 before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
 expect(not app.rules.use_item("ref:19") and app.rules.state==before,"failed learning preserves book and skill state")
 app.store.db.query("PRAGMA query_only=OFF;")
 expect(app.rules.use_item("ref:19"),"learn spirit with book after level requirement")
 expect(not app.rules.state.inventory.has("ref:19") and app.rules.state.skills.has("spirit"),"exactly one book consumed")
 expect(app.rules.state.skill_keys==keys,"passive skill does not occupy active shortcut")
 expect(app.rules.melee_accuracy()==7,"learned spirit improves melee accuracy by local two points")
 var actual:=0;var expected:=0;seed(882)
 for i in range(200):
  if randi_range(0,9)<=7:expected+=1
 seed(882)
 for i in range(200):
  if app.rules.melee_hits(10):actual+=1
 expect(actual==expected and actual>0 and actual<200,"reference accuracy versus evasion roll is used")
 expect(app.rules.melee_hits(0) and app.rules.melee_hits(1),"zero and one evasion always hit")
 expect(Story.ready(app.rules.state,follow),"actual learning completes passive objective without casts")
 expect(app.rules.story_action(follow.id,"submit",npc.id,npc.map,app.world.player.cell),"return commission delivers")
 before=app.rules.state.duplicate(true)
 expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==before,"book reward cannot be claimed twice")
 expect(not app.rules.story_action(follow.id,"submit",npc.id,npc.map,app.world.player.cell) and app.rules.state==before,"return reward cannot be claimed twice")
 var disk: Dictionary=app.store.load_world(app.rules.character.id)
 expect(disk.quests[q.id]=="done" and disk.quests[follow.id]=="done" and disk.skills.has("spirit"),"learned skill and commissions persist")
 for job in ["战士","法师"]:
  app.start_character({"id":job,"name":"其他职业","gender":"男","job":job})
  next=app.rules.state.duplicate(true);next.quests.story_apprentice_book="done";app.rules.apply(next,"other_job_fixture")
  before=app.rules.state.duplicate(true)
  expect(not app.rules.story_action(q.id,"accept",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])) and app.rules.state==before,"other professions cannot receive tao branch")
 var report:={"checks":checks,"failures":failures,"scope":"actual book purchase/use and mentor quest transactions, level8/9 boundary, passive shortcut exclusion, write rollback, duplicate rewards, profession restriction and SQLite; level/budget/prerequisite/NPC position fixtures, not physical input or natural journey"}
 FileAccess.open("res://../artifacts/world-story/spirit-book-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
 for i in range(3):await process_frame
 quit(0 if failures.is_empty() else 1)
