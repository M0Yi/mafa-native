extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/world-story"))!=OK:
		printerr("无法创建测试报告目录");quit(1);return
	call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	root.size=Vector2i(800,600)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/merchant-scroll-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"scroll","name":"满包商店","job":"战士","gender":"男"});app.world.hide()
	var next: Dictionary=app.rules.state.duplicate(true);next.items=[];next.level=100
	for slot in range(48):
		var item:=EditionInventory.make_item("ref:132",1,"inventory",slot);item.purity=slot%20+1;next.items.append(item)
	EditionInventory.mirror(next);expect(app.rules.apply(next,"full_ore_bag"),"prepare 48 ore instances")
	app.show_reference_npc(app.rules.story_npc("server:merchant:56"));await settle()
	var scroll=app.form.get_node("MerchantItems")
	var rows: Array=scroll.get_child(0).get_children().filter(func(n):return n is Button and n.text.begins_with("出售 "))
	expect(rows.size()==48,"all sellable instances in item scroller")
	expect(scroll.clip_contents and scroll.follow_focus,"clip overflow and follow focused row")
	expect(scroll.size.y<=171,"full inventory does not expand item viewport")
	expect(app.form.get_children().any(func(n):return n is Button and n.text=="修理装备"),"repair remains outside scrolling items")
	rows[-1].grab_focus();scroll.ensure_control_visible(rows[-1]);await settle()
	expect(scroll.scroll_vertical>0,"last inventory row reachable by focus scrolling")
	var offset: int=scroll.scroll_vertical
	var list_origin: Vector2=scroll.global_position
	var item: Dictionary=app.rules.state.items[-1]
	expect(app.rules.reference_trade("server:merchant:56",item.type,false,0,item.uid),"sell final displayed instance")
	app.info(app.rules.message)
	await settle()
	expect(scroll.global_position==list_origin,"trade feedback does not shift item list")
	expect(app.panel.notice.visible and app.panel.notice.get_global_rect().end.y<=app.panel.get_global_rect().end.y,"trade feedback visible inside window")
	expect(rows[-1].disabled and rows[-1].text.begins_with("已无此背包物品"),"sold row disabled after committed revision")
	expect(scroll.scroll_vertical==offset and rows.size()==48,"sale retains viewport and row positions")
	expect(not rows[-2].disabled and rows[-2].text.contains("余1"),"neighbor remains saleable with quantity")
	var report:={"display_backend":DisplayServer.get_name(),"physical_input":false,"capture_enabled":DisplayServer.get_name()!="headless","checks":checks,"failures":failures,"scope":"48 instance scroll layout and programmatic focus, 800x600 viewport; no physical mouse or gamepad"}
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/merchant-scroll.png")
	FileAccess.open("res://../artifacts/world-story/merchant-scroll-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	var fixture: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		if FileAccess.file_exists(fixture+suffix) and DirAccess.remove_absolute(fixture+suffix)!=OK:failures.append("fixture cleanup failed")
	quit(0 if failures.is_empty() else 1)
