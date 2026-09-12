class_name EditionSkinButton
extends BaseButton

var text: String="":
	set(value):
		text=value;queue_redraw()

var resources: EditionResources
var bank := "prguse"
var normal_frame := -1
var pressed_frame := -1
var selected := false
var highlight := true
# Canvas draw commands keep a RID, not an owning texture reference. Keep the
# displayed frame alive when map loading clears or evicts the shared cache.
var displayed_texture: Texture2D

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	displayed_texture=null
	var index := pressed_frame if (is_pressed() or selected) and pressed_frame>=0 else normal_frame
	if resources!=null and index>=0:
		var frame:=resources.frame(bank,index)
		if not frame.is_empty():
			displayed_texture=frame.texture
			draw_texture(displayed_texture,Vector2.ZERO,Color(0.5,0.5,0.5) if disabled else Color.WHITE)
	if highlight and is_pressed() and pressed_frame<0:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.3))
	if disabled and index<0:draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.45))
	if not text.is_empty():
		var font:=get_theme_font("font","Button");var font_size:=get_theme_font_size("font_size","Button")
		var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,Vector2((size.x-width)/2,(size.y-font.get_height(font_size))/2+font.get_ascent(font_size)),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0.5,0.5,0.5) if disabled else Color("e8d9b2"))
	if highlight and has_focus():draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color(0.9,0.72,0.3,0.75),false)
	# Hover tint is an explicitly reconstructed state; baked buttons have no hover frames.
	if highlight and is_hovered() and not disabled:draw_rect(Rect2(Vector2.ZERO,size),Color(1,0.8,0.4,0.09))
