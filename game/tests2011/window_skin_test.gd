extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func click(at: Vector2,double:=false) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.double_click=double and pressed;root.push_input(event,true)
	await settle()
func drag(from: Vector2,to: Vector2) -> void:
	var press:=InputEventMouseButton.new();press.position=from;press.global_position=from;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true)
	for i in range(1,11):
		var at:=from.lerp(to,i/10.0)
		var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;motion.relative=(to-from)/10;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await process_frame
	var release:=InputEventMouseButton.new();release.position=to;release.global_position=to;release.button_index=MOUSE_BUTTON_LEFT;root.push_input(release,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-window-skin-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"window-skin","name":"面板测试","job":"战士","gender":"男"});app.world.paused=true
	app.rules.novice_quest("nv_arrival");app.rules.novice_quest("nv_arrival")
	for screen in [Vector2i(800,600),Vector2i(1280,800),Vector2i(2560,1600)]:
		root.size=screen;app.display_density=2 if screen.x==2560 else 1
		for kind in ["bag","gear","warehouse"]:
			app.windows.close_all()
			if kind=="bag":app.show_bag()
			elif kind=="gear":app.show_character()
			else:open_fixture_warehouse()
			await settle()
			var win: EditionWindow=app.panel
			var panel: Control=win.body.get_child(1)
			var dimensions:=Vector2(232,325) if kind=="gear" else Vector2(336,270)
			expect(win.size==dimensions and panel.size==dimensions and win.body.size==dimensions,"native panel has no invisible outer area: "+kind+str(screen))
			expect(win.native_mode and not win.background.visible and not win.scroll.visible and not win.title_label.visible,"no generic frame/title/scroll around "+kind)
			expect(panel.position==Vector2.ZERO and win.body.position==Vector2.ZERO,"native art starts at window origin")
			expect(Rect2(Vector2.ZERO,Vector2(screen)).encloses(win.get_global_rect()),"native panel fits screen")
			for at in [Vector2(-1,0),Vector2(dimensions.x,10),Vector2(20,dimensions.y),dimensions,dimensions+Vector2.ONE,Vector2(400,350)]:
				expect(not win._has_point(at) and not win.hit_test_global(win.get_global_transform_with_canvas()*at),"bitmap safely rejects edge "+kind+str(at))
			for at in [Vector2(100,100),Vector2(120,160)]:
				expect(win.hit_test_global(win.get_global_transform_with_canvas()*at),"opaque panel blocks map at scaled point")
			expect(not win._has_point(Vector2.ZERO),"transparent native corner does not intercept map")
			if kind=="gear":
				for child in panel.get_children():
					if child is EditionSkinButton and child.tooltip_text.begins_with("下一页"):
						await click(child.get_global_rect().get_center());break
				expect(panel.page==1 and panel.stats.visible,"native arrow opens attributes")
				expect(panel.slots.all(func(slot):return not slot.visible),"hidden equipment cannot intercept attribute page")
			else:
				for child in panel.get_children():
					if child is Button and child.text=="翻页":await click(child.get_global_rect().get_center());break
				expect(panel.page==1 and panel.cells.get_child_count()==(8 if kind=="bag" else 10),"native page button preserves capacity")
				for child in panel.get_children():
					if child is BaseButton or child is Label:expect(Rect2(Vector2.ZERO,dimensions).encloses(child.get_rect()),"native text and button stay inside art")
			var old:=win.position
			win.window_origin=old;win.pointer_origin=win.header.get_global_rect().get_center();win.dragging=true;win.drag_to(win.pointer_origin+Vector2(20,10)*app.windows.scale);win.dragging=false
			await settle();expect(win.position.distance_to(old+Vector2(20,10))<2,"drag uses UI scale")
			var anchor:=win.placement;var id:=win.window_id
			var native_close: BaseButton
			for child in panel.get_children():
				if child is BaseButton and (child.tooltip_text=="关闭人物面板" or child.position==Vector2(309,205)):native_close=child
			expect(native_close!=null,"native close target exists")
			await click(native_close.get_global_rect().get_center());expect(not app.windows.windows.has(id),"baked X closes native window")
			var saved: Dictionary=JSON.parse_string(app.store.read_metadata("window:"+id))
			expect(Vector2(saved.anchor[0],saved.anchor[1]).is_equal_approx(anchor),"native position stored without changing saves")
	app.windows.close_all();root.size=Vector2i(1280,800);app.display_density=1
	for method in ["show_quests","show_shop","show_settings","show_skills","show_social","show_hero","show_training","show_village_map","show_travel"]:
		app.call(method);await settle()
		var win: EditionWindow=app.panel
		expect(not win.native_mode and win.background.visible and win.background.texture==app.resources.frame("prguse",384).texture,"single original border: "+method)
		expect(win.scroll.size.x>=win.body.size.x-1,"no horizontal content overflow: "+method)
		expect(win.size==Vector2(416,360),"generic content does not enlarge frame: "+method)
		await click(win.close_button.get_global_rect().get_center());expect(app.windows.windows.is_empty(),"original X closes "+method)
	open_fixture_warehouse();await settle()
	var warehouse: EditionWindow=app.panel
	warehouse.placement=Vector2(0.9,0.4);app.windows.windows["背包"].placement=Vector2(0.1,0.4);await settle()
	var item: Dictionary=app.rules.state.items.filter(func(i):return i.container=="inventory")[0]
	var uid: String=item.uid
	expect(app.rules.inventory_action("move",{"uid":uid,"container":"warehouse","slot":0}),"put unique item into warehouse fixture")
	app.selected_item_uid=uid;await settle()
	var grid: EditionItemPanel=warehouse.body.get_child(1)
	var withdraw: EditionSkinButton
	for child in grid.get_children():
		if child is EditionSkinButton and child.tooltip_text=="将选中物品取回背包":withdraw=child;await click(child.get_global_rect().get_center());break
	expect(EditionInventory.find_item(app.rules.state,uid).container=="inventory","native warehouse USE withdraws same item UID")
	await click(withdraw.get_global_rect().get_center())
	expect(app.pending_message=="请先选择本面板中的物品" and grid.detail.text.begins_with("双击"),"warehouse does not act on a selection from another panel")
	app.windows.confirm("测试确认",func():pass)
	expect(app.windows.modal.theme.get_stylebox("panel","AcceptDialog") is StyleBoxTexture,"confirmation shares classic border")
	app.windows.modal.hide()
	app.windows.close_all();app.world.paused=false;app.show_bag();app.show_character();await settle()
	var bag: EditionItemPanel=app.windows.windows["背包"].body.get_child(1)
	var gear: Control=app.windows.windows["人物属性"].body.get_child(1)
	app.windows.windows["背包"].placement=Vector2(0.1,0.4);app.windows.windows["人物属性"].placement=Vector2(0.9,0.4);await settle()
	var sword: EditionItemSlot
	for slot in bag.cells.get_children():
		if slot.item.get("type")=="wood_sword":sword=slot
	expect(sword!=null,"starter sword available for real viewport drag")
	if sword!=null:
		var sword_uid: String=sword.item.uid
		await drag(sword.get_global_rect().get_center(),gear.slots[0].get_global_rect().get_center())
		expect(EditionInventory.find_item(app.rules.state,sword_uid).container=="equipment","viewport drag equips unique sword")
	expect(app.resources.errors.is_empty(),"all referenced skin frames readable")
	var result:={"checks":checks,"failures":failures}
	FileAccess.open("res://../artifacts/window-skins-0.8.0/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

# Layout fixture supplies the same service context as an NPC interaction.
func open_fixture_warehouse() -> void:
	var was_paused: bool=app.world.paused
	app.world.paused=false
	app.show_warehouse({"id":"layout-keeper","map":app.world.metadata.id,"cell":[app.world.player.cell.x,app.world.player.cell.y]})
	app.world.paused=was_paused
