extends SceneTree
var app
var failures: Array=[]
func check(ok: bool,note: String) -> void:
 if not ok:failures.append(note)
func settle() -> void:
 for i in range(8):await process_frame
func _initialize():call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,800)
 app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 app.store.path="/tmp/minimap-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
 app.start_character({"id":"mini","name":"地图测试","job":"战士","gender":"女"});await settle()
 var mini=app.classic_hud.minimap
 for expected in [0,1,2]:
  check(mini.style==expected,"click cycles display style")
  check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(mini.get_global_rect()),"minimap fits viewport")
  RenderingServer.force_draw();root.get_texture().get_image().save_png("res://../artifacts/world-story/minimap-"+str(expected)+".png")
  var point: Vector2=mini.get_global_rect().position+Vector2(90,15)
  for pressed in [true,false]:
   var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.pressed=pressed;event.button_index=MOUSE_BUTTON_LEFT;root.push_input(event,true)
  await settle()
 check(mini.style==0 and app.store.read_metadata("minimap_style")=="0","cycle wraps and persists")
 app.world.player.reset(app.world.player.cell+Vector2i(1,0));await settle()
 check(mini.center==app.world.player.cell,"nearby map follows player")
 root.size=Vector2i(800,600);await settle()
 check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(mini.get_global_rect()),"small viewport fits")
 print(JSON.stringify({"failures":failures,"scope":"native viewport mouse style cycle, persistence, following and small window; isolated save"}))
 app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
