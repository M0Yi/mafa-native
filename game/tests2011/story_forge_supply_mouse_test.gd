extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func click(button: Button) -> void:
	var ancestor: Node=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.position=button.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/forge-supply-mouse-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"forge_mouse","name":"炉边采购","gender":"男","job":"战士"})
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=20000
	expect(app.rules.apply(next,"purchase_budget_fixture"),"budget fixture")
	var npc: Dictionary=app.rules.story_npc("server:merchant:12")
	app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN);app.world.paused=false;app.save_world()
	app.approach_story_objective({"type":"collect","item":"ore","count":10});await settle()
	expect(app.windows.order.back()=="寻找材料商人","collection tracking opens supplier panel when no ground ore")
	expect(EditionRegion.material_suppliers("dragon_story_scale").is_empty(),"quest credential is not falsely advertised for sale")
	var supplier_button: Button=null
	for button in app.panel.navigation_buttons(app.panel.body):
		if button.text=="打开商店 · "+str(npc.name):supplier_button=button;break
	expect(supplier_button!=null,"nearby supplier has shop action")
	if supplier_button!=null:await click(supplier_button)
	expect(app.windows.order.back()==npc.name,"mouse opens actual supplier shop")
	var buy: Button=null
	for button in app.panel.navigation_buttons(app.panel.body):
		if button.text.begins_with("铁矿 · "):buy=button;break
	expect(buy!=null and not buy.disabled,"smith exposes usable ore purchase")
	if buy!=null:
		expect("单机补建" in buy.text,"merchant explicitly labels reconstructed supply")
		for i in range(10):await click(buy)
	expect(app.rules.state.inventory.get("ore",0)==10,"ten mouse purchases provide forge materials")
	expect(app.rules.state.gold==20000-10*int(EditionRules.ITEMS.ore.price),"mouse purchases charge exact catalog price")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"smith fits minimum window")
	var report:={"checks":checks,"failures":failures,"scope":"collection objective dispatch then real viewport mouse supplier opening and ore purchases at 800x600; budget and location fixtures; not mining or combat acceptance"}
	FileAccess.open("res://../artifacts/world-story/forge-supply-mouse-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
