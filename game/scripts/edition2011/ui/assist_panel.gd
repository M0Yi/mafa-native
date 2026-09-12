extends VBoxContainer
const TITLES=["补给保护","拾取过滤","战斗辅助","职业技能","活动设置"]
const ROWS=[
	[["hp","自动喝红药"],["hp_threshold","生命低于 %",50],["mp","自动喝蓝药"],["mp_threshold","魔法低于 %",30],["return","低血使用回城石"],["return_threshold","回城生命阈值 %",15]],
	[["pickup","自动拾取脚下物品"],["gold","金币"],["equipment","装备"],["materials","材料与药品"]],
	[["attack","自动攻击"],["skill","自动施放已学会技能"],["radius","活动半径（格）",6]],
	[["auto_shield","法师：自动补魔法盾"],["auto_thrust","战士：每次攻击使用刺杀"],["auto_heal","道士：低血自疗"],["auto_armor","道士：自动补神圣战甲术"]],
	[]]
var app
var page:=0
var cursor:=0
var tabs:=HBoxContainer.new()
var body:=VBoxContainer.new()
var hint:=Label.new()
var controls: Array[Control]=[]
func setup(host) -> void:
	app=host;size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_theme_constant_override("separation",16)
	add_child(tabs)
	for i in range(TITLES.size()):
		var b:=Button.new();b.text=TITLES[i];b.toggle_mode=true;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.custom_minimum_size.y=42;tabs.add_child(b);b.pressed.connect(func():select(i))
	add_child(body);body.add_theme_constant_override("separation",10)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_font_size_override("font_size",14);add_child(hint)
	select(0)
func select(index: int) -> void:
	page=posmod(index,TITLES.size());cursor=0;controls.clear()
	for child in body.get_children():body.remove_child(child);child.queue_free()
	for i in range(tabs.get_child_count()):tabs.get_child(i).set_pressed_no_signal(i==page)
	for row in ROWS[page]:
		var line:=HBoxContainer.new();body.add_child(line)
		var label:=Label.new();label.text=row[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",16);line.add_child(label)
		var control: Control
		if row.size()==2:
			var check:=CheckButton.new();control=check;check.text="开启";check.button_pressed=app.rules.state.get("assist",{}).get(row[0],row[0] in ["gold","equipment","materials"])
			check.toggled.connect(func(value):
				if not app.rules.set_assist(row[0],value):check.set_pressed_no_signal(not value)
				app.info(app.rules.message))
		else:
			var number:=SpinBox.new();number.focus_mode=Control.FOCUS_ALL;control=number;number.min_value=1;number.max_value=12 if row[0]=="radius" else 95;number.step=1;number.value=app.rules.state.get("assist",{}).get(row[0],row[2])
			number.value_changed.connect(func(value):
				if not app.rules.set_assist(row[0],value):number.set_value_no_signal(app.rules.state.get("assist",{}).get(row[0],row[2]))
				app.info(app.rules.message))
		control.custom_minimum_size=Vector2(160,42);line.add_child(control);controls.append(control)
	if page==4:
		add_action("将当前位置设为活动中心",func():app.gameplay.origin=app.world.player.cell;app.gameplay.origin_map=app.world.metadata.id;app.info("活动中心已更新"))
		add_action("加点与便利用品",app.gameplay.show_utilities)
		add_action("关闭设置",func():app.windows.close("内挂设置"))
	hint.text="LB / RB 切页 · 上下选择 · A 开关 · 左右调节数值 · B 关闭\n自动保存；暂停和死亡时停止辅助。"
	if page==3:hint.text+="\n职业辅助需要使用技能书学会技能，并满足等级、消耗与冷却。刺杀开启后替代普通攻击，不跳过冷却。"
	if page==1:hint.text+="\n只拾取角色所在格的物品，背包或负重不足时保留在地上。"
	if not controls.is_empty():controls[0].grab_focus()
func add_action(title: String,callback: Callable) -> void:
	var b:=Button.new();b.text=title;b.custom_minimum_size.y=42;body.add_child(b);b.pressed.connect(callback);controls.append(b)
func _process(_delta: float) -> void:
	if app==null or not app.windows.windows.has("内挂设置"):return
	var win=app.windows.windows["内挂设置"]
	var zoom:=EditionDisplay.ui_zoom(app.get_viewport_rect().size,app.windows.requested_scale,app.display_density)
	win.custom_minimum_size=app.get_viewport_rect().size/zoom-Vector2(24,24);win.size=win.custom_minimum_size;win.position=Vector2(12,12)
func _input(event: InputEvent) -> void:
	if app==null or app.windows.order.is_empty() or app.windows.order.back()!="内挂设置" or app.windows.has_modal():return
	if not event is InputEventJoypadButton or not event.pressed:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_LEFT_SHOULDER:select(page-1)
		JOY_BUTTON_RIGHT_SHOULDER:select(page+1)
		JOY_BUTTON_B:app.windows.close("内挂设置")
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			if not controls.is_empty():cursor=posmod(cursor+(-1 if event.button_index==JOY_BUTTON_DPAD_UP else 1),controls.size());controls[cursor].grab_focus()
		JOY_BUTTON_A:
			if controls.is_empty():return
			var c=controls[cursor]
			if c is CheckButton:c.button_pressed=not c.button_pressed
			elif c is Button:c.pressed.emit()
		JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT:
			if not controls.is_empty() and controls[cursor] is SpinBox:controls[cursor].value+=-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1
