class_name EditionItemPanel
extends Control
var app
var embedded_mode:=false
var container_id:="inventory"
var bank_index:=3
var page:=0
var cells:=Control.new()
var caption:=Label.new()
var detail:=Label.new()

func setup(host,container: String,embedded:=false) -> void:
	embedded_mode=embedded;app=host;container_id=container;mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(336,270);size=custom_minimum_size
	add_child(cells)
	caption.position=Vector2(64,212);caption.size=Vector2(236,18);caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_font_size_override("font_size",12);add_child(caption)
	detail.position=Vector2(64,230);detail.size=Vector2(236,34);detail.clip_text=true;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",12);detail.add_theme_constant_override("line_spacing",-3);detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(detail)
	caption.set_deferred("size",Vector2(236,18));detail.set_deferred("size",Vector2(236,34))
	var sort:=Button.new();sort.text="整理";sort.visible=container_id=="inventory";sort.position=Vector2(60,181);add_child(sort)
	sort.pressed.connect(func():app.rules.inventory_action("sort",{});app.pending_message=app.rules.message)
	var split:=Button.new();split.text="拆分";split.position=Vector2(119,181);add_child(split)
	split.pressed.connect(split_prompt)
	var next:=Button.new();next.text="翻页";next.position=Vector2(178,181);add_child(next)
	next.pressed.connect(func():
		page=(page+1)%2;rebuild())
	var use:=EditionSkinButton.new();use.resources=app.resources;use.position=Vector2(250,180);use.size=Vector2(50,21);use.tooltip_text="使用选中物品";add_child(use)
	use.pressed.connect(func():
		if app.selected_item_uid.is_empty():app.pending_message="请先选择一个物品";return
		var item:=EditionInventory.find_item(app.rules.state,app.selected_item_uid)
		if item.get("container")!=container_id:app.pending_message="请先选择本面板中的物品";return
		var ok: bool=app.rules.inventory_action("move",{"uid":app.selected_item_uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")}) if container_id=="warehouse" else app.gameplay.use_item_uid(app.selected_item_uid)
		app.pending_message=app.rules.message)
	var close:=EditionSkinButton.new();close.resources=app.resources;close.position=Vector2(309,205);close.size=Vector2(18,20);add_child(close)
	close.visible=not embedded
	close.pressed.connect(func():
		var node: Node=get_parent()
		while node!=null and not node is EditionWindow:node=node.get_parent()
		if node is EditionWindow:node.closed.emit(node))
	for button in [sort,split,next]:
		button.custom_minimum_size=Vector2.ZERO;button.size=Vector2(56,19);button.add_theme_font_size_override("font_size",12)
		for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.add_theme_color_override("font_color",Color("e8d9b2"))
		button.add_theme_color_override("font_hover_color",Color("fff0c0"))
		button.set_deferred("size",Vector2(56,19))
	if embedded:use.text="使用"
	if container_id=="warehouse":use.text="取出";use.tooltip_text="将选中物品取回背包"
	rebuild()

func rebuild() -> void:
	for c in cells.get_children():cells.remove_child(c);c.queue_free()
	for index in range(mini(40,(48 if container_id=="inventory" else 50)-page*40)):
		var slot:=EditionItemSlot.new();slot.setup(app,container_id,index+page*40)
		slot.position=Vector2(18+(index%8)*36,14+(index/8)*32);cells.add_child(slot)

func split_prompt() -> void:
	var candidates: Array=app.rules.state.items.filter(func(i):return i.container==container_id and i.count>1)
	if candidates.is_empty():app.pending_message="没有可以拆分的物品";return
	var dialog:=ConfirmationDialog.new();dialog.title="拆分物品";dialog.ok_button_text="拆分";dialog.cancel_button_text="取消"
	var layout:=VBoxContainer.new();dialog.add_child(layout)
	var choice:=OptionButton.new();layout.add_child(choice)
	for item in candidates:choice.add_item(EditionRules.ITEMS[item.type].name+" ×"+str(item.count))
	var count:=SpinBox.new();count.min_value=1;count.max_value=candidates[0].count-1;count.value=1;layout.add_child(count)
	choice.item_selected.connect(func(i):count.max_value=candidates[i].count-1)
	dialog.confirmed.connect(func():app.rules.inventory_action("split",{"uid":candidates[choice.selected].uid,"count":int(count.value)});app.pending_message=app.rules.message;dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);add_child(dialog);dialog.add_to_group("edition_blocking_dialog");app.windows.style_dialog(dialog);dialog.content_scale_factor=app.windows.scale.x;dialog.popup_centered(Vector2i(Vector2(320,180)*app.windows.scale.x))

func _process(_delta: float) -> void:
	var used: int=app.rules.state.items.filter(func(item):return item.container==container_id).size()
	caption.text=("仓库" if container_id=="warehouse" else "背包")+" %d/%d · 第%d/2页 · 金 %d"%[used,48 if container_id=="inventory" else 50,page+1,app.rules.state.gold]
	caption.tooltip_text="金币 %d · 负重 %d/%d"%[app.rules.state.gold,app.rules.weight(app.rules.state),100+int(app.rules.state.level)*5]
	var item:=EditionInventory.find_item(app.rules.state,app.selected_item_uid)
	if item.get("container")!=container_id:item={}
	detail.text=("双击取回背包 · 拖动存取\n负重 %d/%d" if container_id=="warehouse" else "双击使用 / 穿脱 · 拖动移动\n负重 %d/%d")%[app.rules.weight(app.rules.state),100+int(app.rules.state.level)*5] if item.is_empty() else EditionRules.ITEMS[item.type].name+" ×%d\n"%int(item.count)+EditionInventory.condition_text(item)
	detail.tooltip_text=""
	if not item.is_empty() and EditionRules.ITEMS[item.type].has("skill_book"):
		var learning: String=app.rules.skill_book_brief(item.type)
		detail.text=EditionRules.ITEMS[item.type].name+" ×%d\n"%int(item.count)+learning.get_slice("\n",0)
		detail.tooltip_text=learning
	if not item.is_empty() and EditionRules.ITEMS[item.type].has("material_bundle"):detail.text+="\n"+EditionRules.material_bundle_text(item.type)
	queue_redraw()

func _draw() -> void:
	if app==null:return
	var image: Dictionary=app.resources.frame("prguse",bank_index)
	if not image.is_empty() and not embedded_mode:draw_texture(image.texture,Vector2.ZERO)
	draw_rect(Rect2(60,182,174,17),Color("181612"))
	if container_id=="warehouse":draw_rect(Rect2(251,183,49,16),Color("181612"))
