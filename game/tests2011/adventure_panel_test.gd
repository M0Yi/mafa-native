extends SceneTree
var app
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func mouse(at: Vector2,press: int=-1,relative:=Vector2.ZERO) -> void:
	if press<0:
		var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=relative;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true)
	else:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=press==1;root.push_input(event,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mafa-journal-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(true)
	app.start_character({"id":"journal","name":"布局验收","gender":"男","job":"法师"});app.world.paused=true
	for dimensions in [Vector2i(800,600),Vector2i(1280,800)]:
		root.size=dimensions;app.windows.close_all();app.show_bag();await settle()
		var view=app.form.get_child(1)
		for index in range(5):
			view.select(index);await settle()
			expect(view.current==index,"selected tab")
			expect(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(app.panel.get_global_rect()),"window fits")
			for i in range(5):expect(view.content[i].visible==(i==index),"single visible page")
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/adventure-panel/page-%d-%d.png"%[index,dimensions.x]))
		view.select(0);app.world.paused=false;await settle()
		var bag=view.content[0].get_child(0)
		var source=bag.cells.get_child(0);var target=bag.cells.get_child(7)
		# Reset positions for the second window-size run without inventing items.
		if source.item.is_empty():source=bag.cells.get_child(7);target=bag.cells.get_child(0)
		var uid: String=source.item.uid
		var a: Vector2=source.get_global_rect().get_center();var b: Vector2=target.get_global_rect().get_center()
		await mouse(a,0);await mouse(a,-1);await mouse(a,1);await mouse(a+Vector2(32,0),-1,Vector2(32,0))
		expect(root.gui_is_dragging(),"native drag started")
		view.select(2);expect(view.current==0,"drag prevents page switch")
		await mouse(b,-1,b-a);await mouse(b,0)
		expect(EditionInventory.find_item(app.rules.state,uid).slot==target.slot_index,"drag moves exact item to target")
		app.world.paused=true
		view.select(0)
		var event:=InputEventKey.new();event.physical_keycode=KEY_LEFT;event.keycode=KEY_LEFT;event.pressed=true;root.push_input(event,true);await settle()
		expect(view.current==4,"left wraps to tasks")
		var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_RIGHT_SHOULDER;joy.pressed=true;root.push_input(joy,true);await settle()
		expect(view.current==0,"controller wraps to bag")
		app.show_character();await settle();expect(view.current==1 and app.windows.windows.size()==1,"existing menu reused")
		event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=true;root.push_input(event,true);await settle()
		expect(app.windows.windows.is_empty(),"Escape closes menu")
	var report:={"failures":failures,"sizes":["800x600","1280x800"],"panels":["inventory","equipment","attributes","skills","quests"]}
	FileAccess.open("res://../artifacts/adventure-panel/tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
