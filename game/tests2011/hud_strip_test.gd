extends SceneTree
var app
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	if not ok:failures.append(note)
func settle() -> void:
	for i in range(8):await process_frame
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/hud-strip-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"hud-strip","name":"界面检查","job":"战士","gender":"女"})
	var hud=app.classic_hud
	check(app.resources.frame("prguse",7).size==Vector2(76,13),"original strip dimensions")
	for screen in [Vector2i(800,600),Vector2i(1280,800),Vector2i(2560,1600)]:
		app.windows.requested_scale=2 if screen.x==2560 else 1
		root.size=screen;await settle()
		for ratio in [0.0,0.5,1.0,1.5]:
			for y in [178,211]:
				var rect: Rect2=hud.strip_rect(ratio,y)
				check(rect.position==Vector2(hud.logical_width-134,y),"right anchored position")
				check(rect.size==Vector2(floorf(76*clampf(ratio,0,1)),13),"native source crop with clamped fill")
		# Render-only full gauges; do not persist the display fixture.
		app.rules.state.xp=100;app.rules.state.inventory={"potion":105}
		hud._process(0);await settle();RenderingServer.force_draw()
		check(hud.stats.text==str(app.world.metadata.name),"current map name shown")
		check(hud.coordinates.text=="坐标 %d, %d"%[app.world.player.cell.x,app.world.player.cell.y],"live player coordinates shown")
		check(hud.health_text.position.x<hud.mana_text.position.x and hud.health_text.position.y<200,"health and mana overlay corresponding orb halves")
		root.get_texture().get_image().save_png("res://../artifacts/world-story/hud-strips-"+str(screen.x)+".png")
	print(JSON.stringify({"failures":failures,"scope":"native HUD geometry and full-gauge screenshots at three resolutions; render-only state fixture"}))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
