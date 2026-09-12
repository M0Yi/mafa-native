class_name EditionWindows
extends Control
var app
var windows: Dictionary={}
var order: Array[String]=[]
var requested_scale:=0
var modal: ConfirmationDialog
var pause_reason:=""

func setup(host) -> void:
	app=host;oversampling_with_scale=CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED;mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=Theme.new();theme.default_font=app.font;theme.default_font_size=16
	modal=ConfirmationDialog.new();modal.title="玛法";modal.ok_button_text="确认";modal.cancel_button_text="取消"
	add_child(modal);modal.add_to_group("edition_blocking_dialog")
	modal.canceled.connect(func():
		if pause_reason=="focus":pause_reason="";app.pending_message="世界已暂停，按 P 继续")

func open(id: String,title: String,dimensions:=Vector2(416,360)) -> EditionWindow:
	if windows.has(id):close(id)
	var win:=EditionWindow.new();win.configure(id,title,app.resources,dimensions)
	add_child(win);windows[id]=win;order.append(id)
	var raw: String=app.store.read_metadata("window:"+id)
	var saved=JSON.parse_string(raw) if not raw.is_empty() else null
	win.position=Vector2(saved[0],saved[1]) if saved is Array and saved.size()==2 else Vector2(80+order.size()*24,120+order.size()*16)
	if saved is Dictionary and saved.get("anchor") is Array and saved.anchor.size()==2:win.placement=Vector2(saved.anchor[0],saved.anchor[1])
	win.closed.connect(func(w):close(w.window_id))
	win.activated.connect(func(w):activate(w.window_id))
	return win

func activate(id: String) -> void:
	if not windows.has(id):return
	move_child(windows[id],get_child_count()-1);order.erase(id);order.append(id)
	app.panel=windows[id];app.form=windows[id].body;app.notice=windows[id].notice;app.overlay=id

func close(id: String) -> void:
	if not windows.has(id):return
	var win: EditionWindow=windows[id]
	app.store.put_metadata("window:"+id,JSON.stringify({"version":2,"anchor":[win.placement.x,win.placement.y]}))
	remove_child(win);win.queue_free();windows.erase(id);order.erase(id)
	if id=="设置与操作" and pause_reason=="settings":pause_reason="";app.world.paused=false
	if order.is_empty():app.panel=null;app.form=null;app.notice=null;app.overlay=""
	else:activate(order.back())

func close_top() -> void:
	if not order.is_empty():close(order.back())

func close_all() -> void:
	for id in order.duplicate():close(id)

func blocks_pointer() -> bool:
	if has_modal():return true
	var point:=get_global_mouse_position()
	for window in windows.values():
		if window.hit_test_global(point):return true
	return false

func style_dialog(dialog: AcceptDialog) -> void:
	var theme:=Theme.new();theme.default_font=app.font;theme.default_font_size=14
	theme.set_stylebox("panel","AcceptDialog",EditionWindow.skin_style(app.resources))
	dialog.theme=theme

func confirm(text: String,callback: Callable) -> void:
	if modal.visible:return
	style_dialog(modal)
	for connection in modal.confirmed.get_connections():modal.confirmed.disconnect(connection.callable)
	modal.get_cancel_button().show();modal.dialog_text=text;modal.confirmed.connect(callback,CONNECT_ONE_SHOT);modal.content_scale_factor=scale.x;modal.popup_centered(Vector2i(Vector2(400,160)*scale.x))

func pause(reason: String) -> void:
	app.world.paused=true;pause_reason=reason
	if reason=="focus":
		if modal.visible:modal.hide()
		confirm("世界已暂停。准备好后继续冒险。",func():pause_reason="";app.world.paused=false)
		modal.get_cancel_button().hide()

func _process(_delta: float) -> void:
	var screen:=get_viewport_rect().size
	var zoom:=EditionDisplay.ui_zoom(screen,requested_scale,app.display_density)
	scale=Vector2.ONE*zoom

func has_modal() -> bool:
	for node in get_tree().get_nodes_in_group("edition_blocking_dialog"):
		if is_instance_valid(node) and node.visible:return true
	return false
