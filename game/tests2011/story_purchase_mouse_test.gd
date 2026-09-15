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
	app.store.path="/tmp/purchase-mouse-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"mouse","name":"柜台购药","gender":"男","job":"战士"})
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_moon_indoor_supplies="done";next.gold=10000
	expect(app.rules.apply(next,"purchase_prerequisite_fixture"),"prerequisite budget fixture")
	var q: Dictionary=Story.quest("story_moon_purchase");var giver: Dictionary=app.rules.story_npc(q.start_npc)
	expect(app.rules.story_action(q.id,"accept",giver.id,giver.map,Vector2i(giver.cell[0],giver.cell[1])),"accept fixture")
	var npc: Dictionary=app.rules.story_npc("server:merchant:116")
	app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN);app.world.paused=false;app.save_world()
	app.show_story(npc);await settle();var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var open: Button=null
	for child in view.details.get_children():
		if child is Button and child.text=="打开商店":open=child
	expect(open!=null,"task offers shop action")
	if open!=null:await click(open)
	expect(app.windows.order.back()==npc.name,"mouse opens named merchant")
	for item in ["potion","mana"]:
		var buy: Button=null
		for button in app.panel.navigation_buttons(app.panel.body):
			if button.text.begins_with(EditionRules.ITEMS[item].name+" · "):buy=button;break
		expect(buy!=null and not buy.disabled,"medicine has enabled purchase button")
		if buy==null:continue
		var gold: int=app.rules.state.gold;var count: int=app.rules.state.inventory.get(item,0)
		var price:=maxi(1,int(EditionRules.ITEMS[item].price)*int(EditionRegion.shop(npc.id).price_rate)/100)
		await click(buy)
		expect(app.rules.state.gold==gold-price and app.rules.state.inventory.get(item,0)==count+1,"mouse purchase changes exact price and count")
		expect(Story.progress(app.rules.state,q,0 if item=="potion" else 1)==1,"mouse purchase advances named objective")
	expect(Story.ready(app.rules.state,q),"two mouse purchases ready task")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"shop fits minimum window")
	RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://../artifacts/world-story/purchase-mouse.png")
	var report:={"checks":checks,"failures":failures,"scope":"native viewport mouse clicks from task to shop and both purchases at 800x600; acceptance, funds and location are fixtures, no travel or hardware controller"}
	FileAccess.open("res://../artifacts/world-story/purchase-mouse-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
