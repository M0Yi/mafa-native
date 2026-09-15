class_name EditionWindow
extends Control
signal closed(window: EditionWindow)
signal activated(window: EditionWindow)
var window_id: String
var body:=VBoxContainer.new()
var notice: Label
var dragging:=false
var pointer_origin:=Vector2.ZERO
var window_origin:=Vector2.ZERO
var placement:=Vector2(-1,-1)
var resources: EditionResources
var background_frame:=384
var header:=Control.new()
var title_label:=Label.new()
var background:=NinePatchRect.new()
var close_button:=EditionSkinButton.new()
var scroll:=ScrollContainer.new()
var native_mode:=false
var surface_mask: BitMap
var preferred_size:=Vector2.ZERO
var reserved_bottom:=0.0
var fixed_notice:=false

func pin_notice() -> void:
	if fixed_notice:return
	fixed_notice=true;body.remove_child(notice);add_child(notice)

static func skin_style(res: EditionResources,index:=380) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new();var frame:=res.frame("prguse",index)
	if not frame.is_empty():style.texture=frame.texture
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		style.set_texture_margin(side,8);style.set_content_margin(side,14)
	style.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style

func configure(id: String,title: String,res: EditionResources,dimensions:=Vector2(416,360)) -> void:
	window_id=id;resources=res;size=dimensions;custom_minimum_size=dimensions;preferred_size=dimensions
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var skin:=res.frame("prguse",384)
	if not skin.is_empty():background.texture=skin.texture
	background.patch_margin_left=8;background.patch_margin_right=24;background.patch_margin_top=24;background.patch_margin_bottom=8
	background.axis_stretch_horizontal=NinePatchRect.AXIS_STRETCH_MODE_STRETCH;background.axis_stretch_vertical=NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
	header.mouse_default_cursor_shape=Control.CURSOR_MOVE;add_child(header)
	title_label.text=title;title_label.add_theme_font_size_override("font_size",14);title_label.modulate=Color("e8d9b2");title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(title_label)
	close_button.resources=res;close_button.tooltip_text="关闭";close_button.size=Vector2(16,23);add_child(close_button)
	close_button.pressed.connect(func():closed.emit(self))
	header.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:dragging=true;pointer_origin=event.global_position;window_origin=position;activated.emit(self)
			else:
				if dragging:drag_to(event.global_position)
				dragging=false
			accept_event()
		elif event is InputEventMouseMotion and dragging:drag_to(event.global_position);accept_event())
	add_child(scroll);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_theme_constant_override("separation",6);scroll.add_child(body)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.add_theme_font_size_override("font_size",13);notice.modulate=Color("e8ca84");notice.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(notice)
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:activated.emit(self))
	layout_skin()

func use_native(frame: int,drag_area: Rect2) -> void:
	native_mode=true;background_frame=frame
	var image:=resources.frame("prguse",frame)
	if image.is_empty():return
	custom_minimum_size=image.size;size=image.size
	surface_mask=BitMap.new();surface_mask.create_from_image_alpha(image.texture.get_image())
	background.hide();close_button.hide();title_label.hide();scroll.hide();notice.hide()
	scroll.remove_child(body);add_child(body);body.position=Vector2.ZERO;body.size=size;body.add_theme_constant_override("separation",0)
	header.position=drag_area.position;header.size=drag_area.size;header.tooltip_text="拖动面板";move_child(header,get_child_count()-1)

func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO,size).has_point(point):return false
	if surface_mask!=null:
		var pixel:=Vector2i(point.floor())
		if not Rect2i(Vector2i.ZERO,surface_mask.get_size()).has_point(pixel):return false
		return surface_mask.get_bitv(pixel)
	return true

func hit_test_global(point: Vector2) -> bool:
	return _has_point(get_global_transform_with_canvas().affine_inverse()*point)

func layout_skin() -> void:
	if native_mode:return
	background.size=size
	header.position=Vector2(12,10);header.size=Vector2(size.x-46,23)
	title_label.size=header.size;title_label.clip_text=true
	close_button.position=Vector2(size.x-17,1)
	scroll.position=Vector2(12,38);scroll.size=size-Vector2(42,51)
	notice.custom_minimum_size.x=0;notice.visible=not notice.text.is_empty()
	if fixed_notice and notice.visible:
		notice.size.x=scroll.size.x
		var height:=notice.get_combined_minimum_size().y
		notice.position=Vector2(scroll.position.x,size.y-13-height)
		notice.size.y=height
		scroll.size.y=maxf(40,notice.position.y-scroll.position.y-8)

func _process(_delta: float) -> void:
	var bounds: Vector2=get_viewport_rect().size/get_parent().scale
	bounds.y=maxf(120,bounds.y-reserved_bottom)
	if reserved_bottom>0 and not native_mode:
		custom_minimum_size=Vector2(minf(preferred_size.x,bounds.x),minf(preferred_size.y,bounds.y))
		size=custom_minimum_size
	layout_skin()
	var available:=(bounds-size).max(Vector2.ZERO)
	if placement.x<0:placement=position.clamp(Vector2.ZERO,available)/available.max(Vector2.ONE)
	if not dragging:position=EditionDisplay.restore_position(placement,bounds,size)

func drag_to(pointer: Vector2) -> void:
	var bounds: Vector2=get_viewport_rect().size/get_parent().scale
	bounds.y=maxf(120,bounds.y-reserved_bottom)
	var available: Vector2=(bounds-size).max(Vector2.ZERO)
	position=(window_origin+(pointer-pointer_origin)/get_parent().scale).round().clamp(Vector2.ZERO,available)
	placement=position/available.max(Vector2.ONE)

var button_navigation:=false
func enable_button_navigation() -> void:
	# Arm after the opening event so one press cannot activate two windows.
	set_deferred("button_navigation",true)
	var hint:=Label.new();hint.text="手柄 ↑↓ 选择 · A 确认 · B 关闭"
	hint.add_theme_font_size_override("font_size",12);hint.modulate=Color("e8ca84");body.add_child(hint)

func navigation_buttons(node: Node) -> Array[Button]:
	var result: Array[Button]=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled:result.append(child)
		else:result.append_array(navigation_buttons(child))
	return result

func _input(event: InputEvent) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not button_navigation or not event is InputEventJoypadButton or not event.pressed:return
	var manager=get_parent()
	if manager.order.is_empty() or manager.order.back()!=window_id or manager.has_modal():return
	if event.button_index not in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:return
	var focus:=get_viewport().gui_get_focus_owner()
	if event.button_index!=JOY_BUTTON_B and (focus is LineEdit or focus is TextEdit):return
	get_viewport().set_input_as_handled()
	if event.button_index==JOY_BUTTON_B:manager.close(window_id);return
	if not manager.app.gameplay.available():return
	var choices:=navigation_buttons(body)
	if choices.is_empty():return
	var current: int=choices.find(get_viewport().gui_get_focus_owner())
	if event.button_index==JOY_BUTTON_A:
		if current<0:current=0
		choices[current].pressed.emit();return
	current=posmod(current+(1 if event.button_index==JOY_BUTTON_DPAD_DOWN else -1),choices.size()) if current>=0 else (0 if event.button_index==JOY_BUTTON_DPAD_DOWN else choices.size()-1)
	var chosen: Button=choices[current]
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.65,0.5,0.2,0.3)
	chosen.add_theme_stylebox_override("focus",style);chosen.grab_focus()
	var ancestor=chosen.get_parent()
	while ancestor!=self:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(chosen)
		ancestor=ancestor.get_parent()
