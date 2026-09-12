class_name ClassicTrialUI
extends Control

var game: Node
var trial: ClassicTrial
var audio: ClassicAudio
var book: PanelContainer
var sound_panel: PanelContainer
var skill_grid: GridContainer
var detail: Label
var summary: Label
var class_buttons: Array[Button]=[]
var skill_buttons: Array[Button]=[]
var mute_button: CheckButton
var trial_button: Button
var poison_button: Button
var combat_toggle: CheckButton
var previous_message := ""
var book_box: VBoxContainer

func button(text: String,callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(callback);return b

func configure(app: Node,t: ClassicTrial,a: ClassicAudio) -> void:
	game=app;trial=t;audio=a;mouse_filter=Control.MOUSE_FILTER_IGNORE
	var controls:=HBoxContainer.new();controls.position=Vector2(22,114);add_child(controls)
	trial_button=button("进入技能试练",toggle_trial);controls.add_child(trial_button)
	controls.add_child(button("技能册 K",func():book.visible=not book.visible;sound_panel.hide()))
	controls.add_child(button("声音",func():sound_panel.visible=not sound_panel.visible;book.hide()))
	summary=game.make_label("",13);summary.position=Vector2(22,151);add_child(summary)
	book=PanelContainer.new();book.add_theme_stylebox_override("panel",game.panel_style());book.position=Vector2(22,181);book.custom_minimum_size=Vector2(370,0);add_child(book)
	book_box=VBoxContainer.new();book_box.add_theme_constant_override("separation",8);var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;book.add_child(scroll);scroll.add_child(book_box)
	var jobs:=HBoxContainer.new();book_box.add_child(jobs)
	for job in ["战士","法师","道士"]:
		var b:=button(job,func():trial.select_job(job);refresh_book())
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;jobs.add_child(b);class_buttons.append(b)
	skill_grid=GridContainer.new();skill_grid.columns=2;book_box.add_child(skill_grid)
	detail=game.make_label("",12);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(334,54);book_box.add_child(detail)
	poison_button=button("切换为红毒",func():trial.red_poison=not trial.red_poison;refresh_book());book_box.add_child(poison_button)
	var options:=HBoxContainer.new();book_box.add_child(options)
	options.add_child(button("重置陪练 R",func():trial.reset_targets()))
	options.add_child(button("收起技能册",func():book.hide()))
	combat_toggle=CheckButton.new();combat_toggle.text="陪练反击（用于试盾、隐身与治疗）";combat_toggle.focus_mode=Control.FOCUS_NONE;combat_toggle.toggled.connect(func(v):trial.hostile=v);book_box.add_child(combat_toggle)
	var magic_toggle:=CheckButton.new();magic_toggle.text="反击使用魔法伤害（试幽灵盾）";magic_toggle.focus_mode=Control.FOCUS_NONE;magic_toggle.toggled.connect(func(v):trial.hostile_magic=v);book_box.add_child(magic_toggle)
	book_box.add_child(game.make_label("全部开放 · 试练数值 · 不消耗技能书或材料",11,Color("a3ae96")))
	book.hide()
	sound_panel=PanelContainer.new();sound_panel.add_theme_stylebox_override("panel",game.panel_style());sound_panel.position=Vector2(22,181);sound_panel.custom_minimum_size=Vector2(370,0);add_child(sound_panel)
	var sounds:=VBoxContainer.new();sounds.add_theme_constant_override("separation",10);sound_panel.add_child(sounds)
	sounds.add_child(game.make_label("声音 · 玛法的回响",18))
	for spec in [["总音量","master"],["背景音乐","music_volume"],["动作与技能音效","effects_volume"]]:
		var row:=HBoxContainer.new();sounds.add_child(row)
		var label: Label=game.make_label(spec[0],13);label.custom_minimum_size=Vector2(125,0);row.add_child(label)
		var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.01;slider.value=audio.get(spec[1]);slider.custom_minimum_size=Vector2(160,20);row.add_child(slider)
		slider.value_changed.connect(func(value):audio.set(spec[1],value);audio.apply_volumes())
		slider.drag_ended.connect(func(_changed):persist_sound())
	mute_button=CheckButton.new();mute_button.text="全部静音 M";mute_button.button_pressed=audio.muted;mute_button.focus_mode=Control.FOCUS_NONE;mute_button.toggled.connect(func(value):audio.muted=value;audio.apply_volumes();persist_sound());sounds.add_child(mute_button)
	sounds.add_child(button("试听挥剑",func():audio.play_sound("01010034")))
	sounds.add_child(game.make_label("比奇背景曲 / 脚步 / 挥剑 / 受击 / 分阶段施法",11))
	sounds.add_child(button("完成",func():persist_sound();sound_panel.hide()))
	sound_panel.hide();refresh_book()

func persist_sound() -> void:
	if not audio.save_settings():game.notify_user("音量已改变，但设置保存失败。",5)

func toggle_trial() -> void:
	sound_panel.hide()
	trial.enabled=not trial.enabled
	if trial.enabled:trial.reset_targets();book.show()
	else:trial.actors.clear();trial.pending.clear();trial.effects.clear();trial.fields.clear();trial.buffs.clear();book.hide()
	trial_button.text="结束技能试练" if trial.enabled else "进入技能试练"
	refresh_book()

func refresh_book() -> void:
	for b in skill_buttons:b.queue_free()
	skill_buttons.clear()
	# Remove immediately so GridContainer does not keep stale cells until next frame.
	for child in skill_grid.get_children():skill_grid.remove_child(child)
	for i in range(trial.skills.size()):
		var s: Dictionary=trial.skills[i]
		var b:=button(s.name+(" · 被动" if s.kind in ["passive","empower"] else ""),func():trial.selected=i;refresh_book())
		b.custom_minimum_size=Vector2(163,29);b.modulate=Color("ffdc8c") if i==trial.selected else Color("bac5b1");skill_grid.add_child(b);skill_buttons.append(b)
	for b in class_buttons:b.modulate=Color("ffdc8c") if b.text==trial.job else Color("bac5b1")
	var skill: Dictionary=trial.skills[trial.selected]
	detail.text=skill.description+("\n专用声画缺失：功能可试，待补原始素材。" if skill.visual_status=="missing" else "\n鼠标指向目标，Q 施放；空格近战；E 下一技能。")
	poison_button.visible=skill.kind=="poison"
	poison_button.text="当前红毒 → 切换绿毒" if trial.red_poison else "当前绿毒 → 切换红毒"

func update_state() -> void:
	if trial.enabled:
		summary.text="%s  生命 %d/360  法力 %d/300  |  Q %s%s" % [trial.job,trial.hp,trial.mp,trial.skills[trial.selected].name," · 冷却" if trial.cooldown>0 else ""]
		if not trial.buffs.is_empty():summary.text+="\n"+" / ".join(trial.buffs.keys())
	else:summary.text="比奇的乐声与脚步 · M 静音"
	combat_toggle.set_pressed_no_signal(trial.hostile)
	if trial.message!=previous_message:
		previous_message=trial.message;game.notify_user(trial.message,6)

func covers(point: Vector2) -> bool:
	var local:=point/float(game.ui_scale)
	return (book.visible and book.get_rect().has_point(local)) or (sound_panel.visible and sound_panel.get_rect().has_point(local)) or Rect2(22,114,340,34).has_point(local)

func key(code: int) -> bool:
	match code:
		KEY_M:mute_button.button_pressed=not mute_button.button_pressed
		KEY_K:book.visible=not book.visible;sound_panel.hide()
		KEY_F2:toggle_trial()
		KEY_E:
			trial.selected=(trial.selected+1)%trial.skills.size();refresh_book()
		KEY_R:
			if trial.enabled:trial.reset_targets()
		KEY_Q,KEY_SPACE:
			if not trial.enabled:game.notify_user("先点击「进入技能试练」或按 F2。");return true
			if covers(game.pointer()):game.notify_user("把鼠标移到场景中的目标上再施放。");return true
			var target: Vector2i=game.world.aim_at_screen(game.pointer())
			if code==KEY_Q:trial.cast(target)
			else:trial.strike(target)
		_ : return false
	return true
