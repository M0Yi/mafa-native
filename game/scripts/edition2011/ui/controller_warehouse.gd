extends VBoxContainer
var app
var npc: Dictionary={}
var page:=0
var cursor:=0
var rows: Array=[]
var title:=Label.new()
var list:=ItemList.new()
var detail:=Label.new()
var result:=Label.new()
func setup(host,keeper: Dictionary) -> void:
	app=host;npc=keeper.duplicate(true);size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(title);list.custom_minimum_size=Vector2(0,220);add_child(list)
	for label in [detail,result]:label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(label)
	list.item_selected.connect(func(index):cursor=index;describe())
	refresh()
func refresh() -> void:
	rows.clear();list.clear()
	title.text=npc.name+" · "+("背包 → 仓库" if page==0 else "仓库 → 背包")
	for item in app.rules.state.items:
		if item.container!=("inventory" if page==0 else "warehouse"):continue
		rows.append(item.duplicate(true));list.add_item(EditionRules.ITEMS[item.type].name+" ×"+str(int(item.count)))
	cursor=clampi(cursor,0,maxi(0,rows.size()-1))
	if not rows.is_empty():list.select(cursor);list.ensure_current_is_visible()
	describe()
func describe() -> void:
	detail.text="LB/RB 切换背包与仓库 · 上下选择\nA "+("存入" if page==0 else "取回")+"选中整组物品 · B 关闭"
	if rows.is_empty():detail.text+="\n此页没有物品。"
func operate() -> void:
	if not app.near_reference_npc(npc):result.text="请回到保管员身边，并继续游戏后办理。";return
	if rows.is_empty():return
	var row: Dictionary=rows[cursor]
	var item:=EditionInventory.find_item(app.rules.state,row.uid)
	if item.is_empty() or item.container!=("inventory" if page==0 else "warehouse"):result.text="物品已变化，请重新选择。";refresh();return
	var target:="warehouse" if page==0 else "inventory"
	app.rules.inventory_action("move",{"uid":row.uid,"container":target,"slot":EditionInventory.free_slot(app.rules.state.items,target)})
	result.text=app.rules.message;app.pending_message=result.text;refresh()
func _input(event: InputEvent) -> void:
	if app==null or app.windows.order.is_empty() or app.windows.order.back()!="手柄仓库" or app.windows.has_modal():return
	if not event is InputEventJoypadButton or not event.pressed:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_B,JOY_BUTTON_BACK:app.windows.close("手柄仓库")
		JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER:page=1-page;cursor=0;refresh()
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			if rows.is_empty():return
			cursor=posmod(cursor+(-1 if event.button_index==JOY_BUTTON_DPAD_UP else 1),rows.size());list.select(cursor);list.ensure_current_is_visible();describe()
		JOY_BUTTON_A:operate()
