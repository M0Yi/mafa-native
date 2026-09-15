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
 app.store.path="/tmp/ground-pickup-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
 app.start_character({"id":"ground","name":"拾取测试","gender":"女","job":"战士"});app.world.paused=false
 var next: Dictionary=app.rules.state.duplicate(true)
 var cell: Vector2i=app.world.player.cell
 next.ground_loot=[{"uid":"underfoot","type":"chicken_meat","count":1,"map":"0","cell":[cell.x,cell.y]},{"uid":"gold","type":"gold","count":10,"map":"0","cell":[cell.x,cell.y]},{"uid":"adjacent","type":"chicken_meat","count":1,"map":"0","cell":[cell.x+1,cell.y]}]
 check(app.rules.apply(next,"ground_fixture"),"place isolated loot")
 var cfg: Dictionary={"pickup":true,"materials":true,"gold":false}
 var before: Dictionary=app.rules.state.duplicate(true)
 app.world.paused=true;app.gameplay.auto_pickup_underfoot(cfg)
 check(app.rules.state==before,"paused pickup blocked");app.world.paused=false
 app.gameplay.auto_pickup_underfoot({"pickup":false});check(app.rules.state==before,"disabled pickup blocked")
 app.gameplay.auto_pickup_underfoot(cfg)
 check(app.rules.state.inventory.get("chicken_meat")==1,"pick underfoot item")
 check(app.rules.state.ground_loot.size()==2 and app.world.player.route.is_empty(),"filtered gold and adjacent item stay, no auto walk")
 cfg.gold=true;app.gameplay.auto_pickup_underfoot(cfg)
 check(app.rules.state.gold==510 and app.rules.state.ground_loot.size()==1,"gold filter enabled")
 app.gameplay.auto_pickup_underfoot(cfg);check(app.rules.state.inventory.get("chicken_meat")==1,"adjacent item not picked")
 for zoom in [1,2,3]:
  app.world.preferred_zoom=zoom;app.world.update_world(0,Vector2(root.size),false);app.gameplay.queue_redraw();await settle();RenderingServer.force_draw()
  root.get_texture().get_image().save_png("res://../artifacts/world-story/ground-item-"+str(zoom)+"x.png")
 app.world.player.reset(cell+Vector2i(1,0));app.gameplay.auto_pickup_underfoot(cfg)
 check(app.rules.state.inventory.get("chicken_meat")==2 and app.rules.state.ground_loot.is_empty(),"stepping onto item allows pickup")
 print(JSON.stringify({"failures":failures,"scope":"same-cell pickup, filters, pause/off and no auto-walk; native item screenshots, isolated save"}))
 app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
