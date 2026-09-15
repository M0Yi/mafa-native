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
	app.store.path="/tmp/demon-return-mouse-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"return_mouse","name":"魔龙归程","gender":"男","job":"战士"})
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=2000
	expect(app.rules.apply(next,"purchase_budget_fixture"),"budget fixture")
	var npc: Dictionary=app.rules.story_npc("server:merchant:156")
	expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN),"merchant location fixture")
	app.world.paused=false;app.save_world();app.show_reference_npc(npc);await settle()
	var buy: Button=null
	for button in app.panel.navigation_buttons(app.panel.body):
		if button.text.begins_with("回城石 · "):buy=button;break
	expect(buy!=null and not buy.disabled,"return stone can be purchased from merchant UI")
	if buy!=null:await click(buy)
	expect(app.rules.state.inventory.get("return_stone",0)==1 and app.rules.state.gold==1500,"mouse buys one stone for catalog price")
	app.windows.close_all()
	expect(app.gameplay.use_type("return_stone"),"purchased stone actually activates")
	expect(app.world.metadata.id=="0" and app.world.player.cell==EditionVillage.SPAWN,"returns to supported village spawn")
	expect(app.rules.state.inventory.get("return_stone",0)==0,"stone consumed once")
	var saved: Dictionary=app.store.load_world(app.rules.character.id)
	expect(saved.map=="0" and saved.inventory.get("return_stone",0)==0,"destination and consumed stone persist")
	expect(not app.gameplay.use_type("return_stone"),"cannot reuse consumed stone")
	var report:={"checks":checks,"failures":failures,"scope":"800x600 viewport mouse merchant purchase and actual utility activation/persistence; initial budget and position fixtures, utility use via gameplay API, not original scroll implementation or full travel"}
	FileAccess.open("res://../artifacts/world-story/demon-return-mouse-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
