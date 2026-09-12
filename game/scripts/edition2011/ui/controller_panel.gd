extends VBoxContainer
# Controller selection never simulates mouse dragging or bypasses inventory transactions.
var app
var page:=0
var cursor:=0
var quick:=0
var rows: Array=[]
var tabs:=Label.new()
var tab_buttons:=HBoxContainer.new()
var list:=ItemList.new()
var detail:=Label.new()
var hint:=Label.new()
func setup(host) -> void:
	app=host;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(tabs);tabs.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(tab_buttons)
	for i in range(4):
		var b:=Button.new();b.text=["背包","装备","技能","任务"][i];b.toggle_mode=true;b.custom_minimum_size.y=38;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab_buttons.add_child(b)
		b.pressed.connect(func():page=i;cursor=0;refresh())
	list.fixed_icon_size=Vector2i(28,28);list.add_theme_constant_override("v_separation",10)
	list.custom_minimum_size=Vector2(0,250);list.add_theme_font_size_override("font_size",18);add_child(list)
	list.item_selected.connect(func(index):cursor=index;describe())
	list.item_activated.connect(func(index):cursor=index;operate())
	for label in [detail,hint]:label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",14);add_child(label)
	refresh()
func refresh() -> void:
	rows.clear();list.clear()
	for i in range(tab_buttons.get_child_count()):tab_buttons.get_child(i).set_pressed_no_signal(i==page)
	tabs.text="LB  ◀   "+["背包","装备","技能","任务"][page]+"   ▶  RB"
	if page<2:
		for item in app.rules.state.items:
			if item.container!=("inventory" if page==0 else "equipment"):continue
			rows.append(item.duplicate(true))
			var art: Dictionary=app.resources.frame("items",int(EditionRules.ITEMS[item.type].get("icon",0)))
			list.add_item(EditionRules.ITEMS[item.type].name+" ×"+str(int(item.count)),art.get("texture"))
	elif page==2:
		for id in app.gameplay.usable_skills():rows.append({"skill":id});list.add_item(EditionSkills.DEFINITIONS[id].name)
	else:
		for q in EditionRules.Story.data().quests:
			if app.rules.state.quests.get(q.id)=="accepted":rows.append({"quest":q.id});list.add_item(q.title)
	cursor=clampi(cursor,0,maxi(0,rows.size()-1))
	if not rows.is_empty():list.select(cursor);list.ensure_current_is_visible()
	describe()
func describe() -> void:
	hint.text="方向键上下选择 · LB/RB 切页 · A 确认 · B 返回 · X 内挂\n"+("左右选择快捷栏 %d · Y 绑定选中物品"%(quick+1) if page==0 else "")
	if page==3 and rows.is_empty():detail.text="没有已接受的故事任务，请先与任务 NPC 对话。";return
	if rows.is_empty():detail.text="尚无已学会的主动技能；请在背包使用技能书。" if page==2 else "此页暂无物品";return
	var row: Dictionary=rows[cursor]
	if page==3:
		var q: Dictionary=EditionRules.Story.quest(row.quest)
		detail.text=q.title+" · "+("正在追踪" if app.rules.state.get("tracked_story","")==q.id else "未追踪")
		detail.text+="\n返回任务人物交付" if EditionRules.Story.ready(app.rules.state,q) else "\n"+str(EditionRules.Story.next_objective(app.rules.state,q).get("label","前往任务人物"))
		hint.text="上下选择 · A 追踪 · Y 取消所选追踪\nLB/RB 切页 · B 返回；关闭后左上角显示目标。"
		return
	if page==2:detail.text="A 设为当前技能；关闭面板后 Y 施放。";return
	var item:=EditionInventory.find_item(app.rules.state,str(row.uid))
	if item.is_empty():detail.text="物品已变化，请重新选择。";return
	if EditionRules.ITEMS[item.type].has("skill_book"):
		detail.text=EditionRules.ITEMS[item.type].name+" ×"+str(int(item.count))+"\n"+app.rules.skill_book_brief(item.type)
		hint.text="上下选择 · A 确认使用技能书 · B 返回\nLB/RB 切页"
		return
	detail.text=EditionRules.ITEMS[item.type].name+"\n"+EditionInventory.condition_text(item)+" · A "+("使用 / 穿戴" if page==0 else "脱下至背包")
	if not item.is_empty() and EditionRules.ITEMS[item.type].has("material_bundle"):detail.text+="\n"+EditionRules.material_bundle_text(item.type)
func operate(bind:=false) -> void:
	if rows.is_empty() or app.world.paused or app.rules.state.hp<=0:return
	var row: Dictionary=rows[cursor]
	if page==3:app.rules.track_story(row.quest);app.pending_message=app.rules.message
	elif page==2:app.gameplay.select_skill(row.skill)
	elif bind and page==0:app.rules.inventory_action("bind",{"uid":row.uid,"slot":quick});app.pending_message=app.rules.message
	elif page==1:app.rules.inventory_action("move",{"uid":row.uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")});app.pending_message=app.rules.message
	else:app.gameplay.use_item_uid(row.uid)
	refresh()
func _input(event: InputEvent) -> void:
	if app==null or app.mode!="game" or app.windows.order.is_empty() or app.windows.order.back()!="手柄操作" or app.windows.has_modal():return
	if not event is InputEventJoypadButton or not event.pressed:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_X:app.gameplay.show_assist()
		JOY_BUTTON_B,JOY_BUTTON_BACK:app.windows.close("手柄操作")
		JOY_BUTTON_LEFT_SHOULDER:page=posmod(page-1,4);cursor=0;app.play_sound_id(105);refresh()
		JOY_BUTTON_RIGHT_SHOULDER:page=posmod(page+1,4);cursor=0;app.play_sound_id(105);refresh()
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			if rows.is_empty():return
			cursor=posmod(cursor+(-1 if event.button_index==JOY_BUTTON_DPAD_UP else 1),rows.size());list.select(cursor);list.ensure_current_is_visible();describe()
		JOY_BUTTON_DPAD_LEFT:quick=posmod(quick-1,6);describe()
		JOY_BUTTON_DPAD_RIGHT:quick=posmod(quick+1,6);describe()
		JOY_BUTTON_A:operate()
		JOY_BUTTON_Y:
			if page==0:operate(true)
			elif page==3 and not rows.is_empty() and app.rules.state.get("tracked_story","")==rows[cursor].quest:
				app.rules.track_story("");app.pending_message=app.rules.message;refresh()
