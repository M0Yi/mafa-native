extends VBoxContainer
# Shared compact journal. Lists and details scroll independently inside the original skin.
var entries:=VBoxContainer.new()
var details:=VBoxContainer.new()
var toolbar:=HBoxContainer.new()
func build() -> void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	add_child(toolbar)
	var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",14);add_child(columns)
	var left:=ScrollContainer.new();left.custom_minimum_size=Vector2(176,260);left.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(left)
	entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.add_child(entries)
	var right:=ScrollContainer.new();right.custom_minimum_size=Vector2(0,260);right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(right)
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",10);right.add_child(details)
func clear(box: Node) -> void:
	for child in box.get_children():box.remove_child(child);child.queue_free()
func line(box: Node,value: String,title:=false) -> Label:
	var label:=Label.new();label.text=value;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",16 if title else 13);label.modulate=Color("f3d28c" if title else "dfd1ae");label.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(label);return label
func action(box: Node,text: String,callback: Callable,enabled:=true) -> Button:
	var button:=Button.new();button.text=text;button.add_theme_font_size_override("font_size",13);button.custom_minimum_size.y=32;button.disabled=not enabled
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("302b22") if state=="normal" else Color("55452b") if state in ["hover","focus"] else Color("6c542e") if state=="pressed" else Color("211e19")
		style.border_color=Color("a88c52") if state in ["hover","pressed","focus"] else Color("554b36")
		style.set_border_width_all(1);style.set_corner_radius_all(3)
		style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=6;style.content_margin_bottom=6
		button.add_theme_stylebox_override(state,style)
	if box==entries:
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text=text.trim_prefix("◆ ")
		if text.begins_with("◆ "):button.add_theme_color_override("font_color",Color("ffe1a0"))
	box.add_child(button)
	button.pressed.connect(func():
		if not button.is_inside_tree() or button.is_queued_for_deletion() or button.disabled:return
		callback.call())
	return button
