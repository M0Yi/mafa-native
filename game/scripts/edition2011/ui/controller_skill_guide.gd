extends VBoxContainer
const Story=preload("res://scripts/edition2011/story.gd")
var app
var objective: Dictionary={}
var detail:=RichTextLabel.new()
var revision: int=-1
func setup(host,target: Dictionary) -> void:
	app=host;objective=target.duplicate(true)
	detail.custom_minimum_size=Vector2(0,250);detail.add_theme_font_size_override("normal_font_size",16);add_child(detail)
	var hint:=Label.new();hint.text="上下滚动 · Y 打开手柄背包 · B 返回任务\n技能书仍需在背包确认使用。";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(hint)
	refresh()
func refresh() -> void:
	detail.text=Story.skill_brief(app.rules.state,objective,app.rules.character.job)
	revision=int(app.rules.state.get("revision",0))
func _process(_delta: float) -> void:
	if app!=null and revision!=int(app.rules.state.get("revision",0)):refresh()
func _input(event: InputEvent) -> void:
	if app==null or app.mode!="game" or app.windows.has_modal() or app.windows.order.is_empty() or app.windows.order.back()!="手柄技能指引":return
	if not event is InputEventJoypadButton or not event.pressed:return
	get_viewport().set_input_as_handled()
	match event.button_index:
		JOY_BUTTON_B,JOY_BUTTON_BACK:app.windows.close("手柄技能指引")
		JOY_BUTTON_DPAD_UP:detail.get_v_scroll_bar().value-=48
		JOY_BUTTON_DPAD_DOWN:detail.get_v_scroll_bar().value+=48
		JOY_BUTTON_Y:
			if get_viewport().gui_is_dragging():return
			if app.windows.windows.has("手柄操作"):app.windows.activate("手柄操作")
			else:app.show_controller_panel()
			if not app.windows.windows.has("手柄操作"):return
			var panel=app.windows.windows["手柄操作"].body.get_child(1)
			panel.page=0;panel.cursor=0;panel.refresh()
			var skill: String=objective.get("skills_by_job",{}).get(app.rules.character.job,"")
			if not objective.has("skills_by_job"):skill=Story.skill_suggestion(app.rules.state,app.rules.character.job).get("skill","")
			for i in range(panel.rows.size()):
				if EditionRules.ITEMS.get(panel.rows[i].type,{}).get("skill_book","")==skill:
					panel.cursor=i;panel.list.select(i);panel.list.ensure_current_is_visible();panel.describe();break
