extends VBoxContainer
const Craft=preload("res://scripts/edition2011/peach_crafting.gd")
var app
var npc: Dictionary={}
var rows: Array=[]
var cursor:=0
var phase:="list"
var revision:=-1
var list:=ItemList.new()
var detail:=RichTextLabel.new()
var hint:=Label.new()
var feedback:=""
func setup(host,person: Dictionary) -> void:
	app=host;npc=person.duplicate(true);rows=Craft.recipes()
	list.custom_minimum_size=Vector2(0,190);add_child(list)
	for row in rows:list.add_item(row.name+" · "+str(int(row.cost))+"金币")
	list.item_selected.connect(func(index):cursor=index;refresh())
	detail.custom_minimum_size=Vector2(0,110);detail.add_theme_font_size_override("normal_font_size",15);add_child(detail)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(hint);refresh()
func refresh() -> void:
	list.visible=phase=="list";list.select(cursor);list.ensure_current_is_visible()
	detail.custom_minimum_size.y=110 if phase=="list" else 290
	if phase=="list":detail.text=rows[cursor].name+"\n"+feedback;hint.text="上下选配方 · A 查看材料 · Y 材料来源 · B 返回任务"
	elif phase=="confirm":
		detail.text=Craft.confirmation_text(app.rules,rows[cursor]);revision=int(app.rules.state.revision)
		hint.text="A 确认制作 · B 取消 · 上下滚动\n确认后消耗上列材料及金币"
	else:
		var parts: PackedStringArray=[str(rows[cursor].name)+" · 材料来源"]
		for type in rows[cursor].materials:
			parts.append("%s ×%d · 背包%d / 仓库%d"%[EditionRules.ITEMS[type].name,int(rows[cursor].materials[type]),int(app.rules.state.inventory.get(type,0)),int(app.rules.state.warehouse.get(type,0))])
			for source in Craft.material_sources(type).slice(0,3):
				if source.has("exchange"):
					var banker: Dictionary=app.rules.story_npc(source.exchange)
					parts.append("%s · %s：1002000金币 → 金条×1"%[banker.name,app.resources.map_by_id[banker.map].name])
				else:
					var names: PackedStringArray=[]
					for mid in source.maps.slice(0,2):names.append(str(app.resources.map_by_id.get(mid,{}).get("name",mid)))
					parts.append("%s · %s · 基础%s"%[source.monster,"、".join(names),source.prob])
		parts.append("基础单次概率不保证掉落；掉落物需拾取，仓库材料需取回。")
		detail.text="\n".join(parts);hint.text="上下滚动 · B 返回配方"
	detail.scroll_to_line(0)
func _input(event: InputEvent) -> void:
	if not is_inside_tree() or is_queued_for_deletion():return
	if app==null or app.mode!="game" or app.windows.has_modal() or app.windows.order.is_empty() or app.windows.order.back()!="手柄桃源合成":return
	if not event is InputEventJoypadButton or not event.pressed:return
	if event.button_index==JOY_BUTTON_START:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_B,JOY_BUTTON_BACK:
			if phase=="list":app.windows.close("手柄桃源合成")
			else:phase="list";refresh()
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			var step:=1 if event.button_index==JOY_BUTTON_DPAD_DOWN else -1
			if phase=="list":cursor=posmod(cursor+step,rows.size());refresh()
			else:detail.get_v_scroll_bar().value+=step*48
		JOY_BUTTON_Y:
			if phase=="list":phase="sources";refresh()
		JOY_BUTTON_A:
			if phase=="sources":return
			if not app.near_reference_npc(npc):feedback="请回到合成师身边，并继续游戏后办理";phase="list";refresh();return
			if phase=="list":phase="confirm";refresh();return
			if Craft.craft(app.rules,app.world.metadata.id,app.world.player.cell,rows[cursor].product,revision):app.play_sound_id(106)
			feedback=app.rules.message;app.info(feedback);phase="list";refresh()
