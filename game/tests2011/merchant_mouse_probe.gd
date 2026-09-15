extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
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
	var npc: Dictionary=app.rules.story_npc("server:merchant:56")
	app.enter_map(npc.map,Vector2i(npc.cell[0]+1,npc.cell[1]),false);app.world.paused=false
	app.show_reference_npc(npc);root.title="商店鼠标验收 · 临时存档";await settle()
	var scroll=app.form.get_node("MerchantItems")
	var rows: Array=scroll.get_child(0).get_children().filter(func(n):return n is Button and n.text.begins_with("出售 "))
	expect(rows.size()==48,"all sellable instances in item scroller")
	expect(scroll.clip_contents and scroll.follow_focus,"clip overflow and follow focused row")
	expect(scroll.size.y<=171,"full inventory does not expand item viewport")
	expect(app.form.get_children().any(func(n):return n is Button and n.text=="修理装备"),"repair remains outside scrolling items")
	var initial: Dictionary=app.rules.state.duplicate(true)
	for frame in range(18000):
		await process_frame
		if app.rules.state.gold!=initial.gold:
			var missing: Array=[]
			for item in initial.items:
				if EditionInventory.find_item(app.rules.state,item.uid).is_empty():missing.append({"slot":int(item.slot),"purity":item.purity})
			var record:={"removed":missing,"gold_delta":app.rules.state.gold-initial.gold,"items_remaining":app.rules.state.items.size(),"input_source":"external computer-use mouse; probe never emits button signals"}
			FileAccess.open("res://../artifacts/world-story/merchant-mouse-result.json",FileAccess.WRITE).store_string(JSON.stringify(record,"  "));print(JSON.stringify(record))
			await create_timer(3).timeout;app.queue_free();await settle();quit();return
	app.queue_free();await settle();quit(2)
