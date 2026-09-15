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
	for i in range(8):await process_frame
func mouse(at: Vector2,press: int=-1,relative:=Vector2.ZERO,button:=MOUSE_BUTTON_LEFT,double:=false) -> void:
	if press<0:
		var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.relative=relative;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true)
	else:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=button;e.pressed=press==1;e.double_click=double;root.push_input(e,true)
	await settle()
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-warehouse-mouse-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"warehouse_mouse","name":"寄放操作","gender":"男","job":"战士"})
	var quest_id:=OS.get_environment("MAFA_WAREHOUSE_QUEST")
	if quest_id.is_empty():quest_id="story_seal_warehouse_practice"
	var q: Dictionary=Story.quest(quest_id)
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
	app.enter_map(npc.map,at);app.world.paused=false
	expect(app.save_world(),"persist actual loaded location fixture")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.requires[0]]="done"
	expect(app.rules.apply(next,"prerequisite_fixture"),"prerequisite fixture")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept fixture")
	app.show_story(npc);await settle()
	var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var open: Button=null
	for child in view.details.get_children():
		if child is Button and child.text=="打开仓库":open=child
	expect(open!=null,"task offers warehouse action")
	if open!=null:
		view.details.get_parent().ensure_control_visible(open);await settle()
		await mouse(open.get_global_rect().get_center(),1);await mouse(open.get_global_rect().get_center(),0)
	expect(app.windows.windows.has("个人仓库"),"mouse opens real warehouse")
	app.windows.close_all();app.show_warehouse(npc);await settle()
	var warehouse=app.form.get_child(1)
	var storage_window=app.panel
	var bag_window=app.windows.windows["冒险面板"]
	# Arrange independently from remembered user window positions.
	bag_window.placement=Vector2(0.03,0.1);storage_window.placement=Vector2(0.95,0.1);await settle()
	var bag=bag_window.body.get_child(1).content[0].get_child(0)
	var source=null
	for slot in bag.cells.get_children():
		if slot.item.get("type")=="potion":source=slot;break
	expect(source!=null,"potion visible")
	if source!=null:
		var uid: String=source.item.uid
		var target=warehouse.cells.get_child(0)
		var a: Vector2=source.get_global_rect().get_center();var b: Vector2=target.get_global_rect().get_center()
		print(JSON.stringify({"bag":str(bag_window.get_global_rect()),"warehouse":str(storage_window.get_global_rect()),"a":str(a),"b":str(b),"paused":app.world.paused,"scale":str(app.windows.scale)}))
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://../artifacts/world-story/warehouse-mouse-"+quest_id+".png")
		await mouse(a,0);await mouse(a);await mouse(a,1);await mouse(a+Vector2(30,0),-1,Vector2(30,0))
		expect(root.gui_is_dragging(),"real drag starts")
		await mouse(b,-1,b-a)
		print(JSON.stringify({"hit":storage_window.hit_test_global(b),"hover":str(root.gui_get_hovered_control()),"drop":target._can_drop_data(Vector2.ZERO,root.gui_get_drag_data())}))
		await mouse(b,0)
		print(JSON.stringify({"item_after":EditionInventory.find_item(app.rules.state,uid),"message":app.rules.message,"map":app.rules.state.map}))
		expect(EditionInventory.find_item(app.rules.state,uid).container=="warehouse" and Story.progress(app.rules.state,q,0)==1,"mouse deposit moves item and counts at money house")
		await mouse(b,1,Vector2.ZERO,MOUSE_BUTTON_LEFT,true);await mouse(b,0)
		expect(EditionInventory.find_item(app.rules.state,uid).container=="inventory" and Story.ready(app.rules.state,q),"double click withdraws and completes")
	var report:={"checks":checks,"failures":failures,"scope":"native viewport mouse button/motion events; map, prerequisite and window positions are fixtures; no hardware gamepad"}
	FileAccess.open("res://../artifacts/world-story/warehouse-mouse-"+quest_id+"-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
