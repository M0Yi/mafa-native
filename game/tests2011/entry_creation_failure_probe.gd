extends SceneTree
class RejectWorld extends EditionRules:
 var reject:=true
 var presets: Array=[]
 func attach(_profile: Dictionary,_preset: String="easy") -> bool:
  presets.append(_preset)
  if reject:message="测试：世界存档初始化失败";return false
  return super.attach(_profile,_preset)
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-create-probe-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.accounts.data={"version":1,"accounts":[{"id":"f".repeat(32),"username":"fixture","salt":"0".repeat(32),"hash":"0".repeat(64),"iterations":LocalAccounts.ITERATIONS,"characters":[]}]}
 app.accounts.current_id="f".repeat(32)
 app.rules=RejectWorld.new();app.rules.store=app.store
 app.entry.show_page("create");app.entry.fields.name.text="重试角色"
 app.entry.create_character()
 assert(app.accounts.characters().size()==1)
 assert(app.pending_message.contains("初始化失败"))
 app.entry.create_character()
 assert(app.accounts.characters().size()==1 and app.pending_message.contains("初始化失败"))
 app.entry.difficulty="classic"
 app.rules.reject=false
 app.entry.create_character()
 assert(app.accounts.characters().size()==1 and app.entry.pending_creation.is_empty())
 assert(app.entry.page=="roster" and app.rules.state.preset=="easy")
 assert(app.rules.presets==["easy","easy","easy"])
 # Persist another identity without a world, then reload accounts as on restart.
 var pending: Dictionary=app.accounts.create_character("经典恢复",LocalAccounts.JOBS[0],LocalAccounts.GENDERS[1],false,"classic")
 assert(not pending.is_empty())
 var restored:=EditionAccounts.new();restored.store=app.store
 assert(restored.load_database());restored.current_id="f".repeat(32)
 var recovered:=EditionRules.new();recovered.store=app.store
 assert(recovered.attach(restored.character(pending.id)))
 assert(recovered.state.preset=="classic" and restored.characters().size()==2)
 assert(recovered.attach(restored.character(pending.id),"easy"))
 assert(recovered.state.preset=="classic")
 print("PASS: persisted creation preset survives account reload and later attach")
 print("PASS: failed world creation preserves identity; retries initialize once with original preset")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
