extends VBoxContainer
# One menu owns navigation; item slots continue to use the transactional inventory rules.
const TITLES=["行囊","装备","属性","技能","任务"]
var app
var current:=0
var tabs:=HBoxContainer.new()
var pages:=Control.new()
var content: Array[Control]=[]
func setup(host,index:=0) -> void:
	app=host;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6);add_child(tabs)
	for i in range(TITLES.size()):
		var button:=Button.new();button.text=TITLES[i];button.toggle_mode=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",14);tabs.add_child(button)
		button.pressed.connect(func():select(i))
	pages.custom_minimum_size=Vector2(568,398);add_child(pages)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",0);pages.add_child(row);content.append(row)
	var bag=load("res://scripts/edition2011/ui/item_panel.gd").new();row.add_child(bag);bag.setup(app,"inventory",true)
	var gear=load("res://scripts/edition2011/ui/equipment_panel.gd").new();row.add_child(gear);gear.setup(app,true)
	for i in [0,1]:
		var center:=CenterContainer.new();pages.add_child(center);content.append(center)
		var equipment=load("res://scripts/edition2011/ui/equipment_panel.gd").new();center.add_child(equipment);equipment.setup(app,true);equipment.page=i;equipment.update_page()
	var skills=load("res://scripts/edition2011/ui/skill_panel.gd").new();pages.add_child(skills);content.append(skills);skills.setup(app)
	var quests=load("res://scripts/edition2011/ui/quest_panel.gd").new();pages.add_child(quests);content.append(quests);quests.setup(app)
	for child in content:child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var navigation:=HBoxContainer.new();add_child(navigation)
	for spec in [["◀ 上一页",-1],["关闭 · Esc",0],["下一页 ▶",1]]:
		var button:=Button.new();button.text=spec[0];button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",13);navigation.add_child(button)
		button.pressed.connect(func():
			if int(spec[1])==0:app.windows.close("冒险面板")
			else:select(current+int(spec[1])))
	var help:=Label.new();help.text="B 背包 · ← → 切页 · 双击使用 / 穿脱 · 拖动整理 / 绑定快捷栏";help.add_theme_font_size_override("font_size",12);help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(help)
	select(index,false)
func select(index: int,sound:=true) -> void:
	if get_viewport().gui_is_dragging():return
	current=posmod(index,TITLES.size())
	for i in range(content.size()):content[i].visible=i==current;tabs.get_child(i).set_pressed_no_signal(i==current)
	if current in [3,4]:content[current].refresh()
	if sound:app.play_sound_id(105)
func _input(event: InputEvent) -> void:
	if app==null or app.mode!="game" or app.windows.order.is_empty() or app.windows.order.back()!="冒险面板" or app.windows.has_modal() or app.typing():return
	var step:=0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_LEFT:step=-1
		elif event.physical_keycode==KEY_RIGHT:step=1
		elif event.keycode==KEY_ESCAPE:get_viewport().set_input_as_handled();app.windows.close("冒险面板");return

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_LEFT_SHOULDER:step=-1
		elif event.button_index==JOY_BUTTON_RIGHT_SHOULDER:step=1
		elif event.button_index==JOY_BUTTON_B:get_viewport().set_input_as_handled();app.windows.close("冒险面板");return
	if step!=0:select(current+step);get_viewport().set_input_as_handled()
