extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://edition2011.tscn").instantiate()
 app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-beam-capture-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 root.size=Vector2i(1280,800)
 app.start_character({"id":"beam_capture","name":"特效核对","job":"法师","gender":"女"})
 app.world.paused=true
 var effects=app.gameplay.skill_effects
 var result:=OK
 for direction in range(16):
  effects.clear()
  effects.events.append({"id":"beam","at":app.world.player.anchor,"time":app.elapsed-0.24,"map":app.world.metadata.id,"direction":direction})
  for i in range(2):await process_frame
  await RenderingServer.frame_post_draw
  var code:=root.get_texture().get_image().save_png("res://../artifacts/skill-beam-direction-%02d.png"%direction)
  if code!=OK:result=code
 print("CAPTURE_RESULT ",result," directions=16")
 app.queue_free();await process_frame;await create_timer(0.3).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit(result)
