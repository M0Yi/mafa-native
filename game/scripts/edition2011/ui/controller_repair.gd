extends VBoxContainer
var app
var npc: Dictionary={}
var detail:=RichTextLabel.new()
var result:=Label.new()
var revision: int=-1
func setup(host,person: Dictionary) -> void:
	app=host;npc=person.duplicate(true)
	detail.custom_minimum_size=Vector2(0,140);detail.add_theme_font_size_override("normal_font_size",16);add_child(detail)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(result)
	var hint:=Label.new();hint.text="A 确认修理 · B 返回任务 · 上下滚动\n仅修理已装备且属于该店类别的物品。";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(hint)
	refresh()
func refresh() -> void:
	detail.text=str(npc.name)+"\n\n"+app.rules.story_repair_brief(npc.id)
	revision=int(app.rules.state.get("revision",0))
func _process(_delta: float) -> void:
	if app!=null and revision!=int(app.rules.state.get("revision",0)):refresh()
func _input(event: InputEvent) -> void:
	if not is_inside_tree() or is_queued_for_deletion():return
	if app==null or app.mode!="game" or app.windows.has_modal() or app.windows.order.is_empty() or app.windows.order.back()!="手柄修理":return
	if not event is InputEventJoypadButton or not event.pressed:return
	if event.button_index==JOY_BUTTON_START:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_B,JOY_BUTTON_BACK:app.windows.close("手柄修理")
		JOY_BUTTON_DPAD_UP:detail.get_v_scroll_bar().value-=48
		JOY_BUTTON_DPAD_DOWN:detail.get_v_scroll_bar().value+=48
		JOY_BUTTON_A:
			if not app.near_reference_npc(npc):result.text="请在存活状态回到商人身边，并继续游戏后办理。";return
			if app.rules.reference_repair(npc.id):app.play_sound_id(106)
			result.text=app.rules.message;app.info(app.rules.message);refresh()
