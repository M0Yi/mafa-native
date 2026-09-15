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
 app.store.path="/tmp/guaranteed-drop-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
 for i in range(5):await process_frame
 app.set_process(false);app.start_character({"id":"drop","name":"掉落检查","gender":"男","job":"战士"})
 var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/regional-data.json"))
 var guaranteed: Array=raw.monsters["触龙神"].drops.filter(func(row):return row.prob=="1/1")
 expect(guaranteed.size()==33,"source contains one guaranteed gold entry and 32 medicine entries")
 var results: Array=[]
 for preset in ["classic","easy"]:
  var next: Dictionary=app.rules.state.duplicate(true);next.preset=preset;next.ground_loot=[];app.rules.apply(next,"preset_fixture")
  var wallet: int=app.rules.state.gold;var inventory: Dictionary=app.rules.state.inventory.duplicate(true)
  var monster:={"id":"guaranteed-"+preset,"spawn_id":"guaranteed-"+preset,"name":"触龙神","reference_name":"触龙神","map":"d606","cell":[69,154],"exp":0,"respawn_seconds":3600,"drops":guaranteed}
  expect(app.rules.reward_kill("kill-"+preset,"",monster,1),"guaranteed source rewards commit")
  var loot: Array=app.rules.state.ground_loot;var gold:=0;var medicines:=0
  for row in loot:
   if row.type=="gold":gold+=int(row.count)
   else:medicines+=int(row.count)
  expect(gold==(28000 if preset=="easy" else 14000),"gold multiplier applies exactly once")
  expect(medicines==32 and loot.size()==33,"guaranteed medicine rows preserved once in both modes")
  expect(app.rules.state.gold==wallet and app.rules.state.inventory==inventory,"rewards stay on ground")
  var before: Dictionary=app.rules.state.duplicate(true)
  expect(not app.rules.reward_kill("repeat-"+preset,"",monster,1) and app.rules.state==before,"same spawn kill cannot duplicate guaranteed rewards")
  results.append({"preset":preset,"gold":gold,"medicine_count":medicines,"ground_rows":loot.size()})
 # Reproduce the RNG calls independently to verify easy mode still rolls ordinary drops twice.
 for preset in ["classic","easy"]:
  var next: Dictionary=app.rules.state.duplicate(true);next.preset=preset;next.ground_loot=[];app.rules.apply(next,"chance_fixture")
  var expected:=0;seed(775)
  for trial in range(2 if preset=="easy" else 1):
   for row in range(20):
    if randi_range(1,2)==1:expected+=1
  var drops: Array=[]
  for row in range(20):drops.append({"prob":"1/2","name":"铁矿"})
  var monster:={"id":"chance-"+preset,"spawn_id":"chance-"+preset,"name":"概率夹具","map":"d606","cell":[69,154],"exp":0,"respawn_seconds":3600,"drops":drops}
  seed(775);expect(app.rules.reward_kill("chance-"+preset,"",monster,1),"ordinary chance rewards commit")
  expect(app.rules.state.ground_loot.size()==expected,"ordinary probabilities retain independent preset trial count")
 # Random gold has one probability trial in either mode, with only the amount doubled.
 for preset in ["classic","easy"]:
  var next: Dictionary=app.rules.state.duplicate(true);next.preset=preset;next.ground_loot=[];app.rules.apply(next,"random_gold_fixture")
  var expected:=0;seed(809)
  for row in range(20):
   if randi_range(1,2)==1:expected+=1
  var drops: Array=[]
  for row in range(20):drops.append({"prob":"1/2","name":"金币","count":100})
  var monster:={"id":"gold-"+preset,"spawn_id":"gold-"+preset,"name":"金币概率夹具","map":"d606","cell":[69,154],"exp":0,"respawn_seconds":3600,"drops":drops}
  seed(809);expect(app.rules.reward_kill("gold-"+preset,"",monster,1),"random gold commits")
  var amount:=0
  for row in app.rules.state.ground_loot:amount+=int(row.count)
  expect(app.rules.state.ground_loot.size()==expected and amount==expected*(200 if preset=="easy" else 100),"random gold gets one trial and one amount multiplier")
 var report:={"checks":checks,"failures":failures,"results":results,"scope":"real boss guaranteed rows isolated from random rows; fixed-seed ordinary 1/2 fixtures; original source unmodified, no statistical balance or full combat claim"}
 FileAccess.open("res://../artifacts/world-story/guaranteed-drop-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
 for i in range(3):await process_frame
 quit(0 if failures.is_empty() else 1)
