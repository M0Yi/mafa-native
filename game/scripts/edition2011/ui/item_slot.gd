class_name EditionItemSlot
extends Button
var app
var container_id:="inventory"
var slot_index:=0
var item: Dictionary={}
var quick_slot:=-1
var paperdoll:=false
var empty_name:="空格"

func setup(host,container: String,index: int) -> void:
	app=host;container_id=container;slot_index=index
	custom_minimum_size=Vector2(36,32);size=custom_minimum_size
	add_theme_font_size_override("font_size",10)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.03,0.025,0.02,0.18);style.border_color=Color(0.55,0.45,0.25,0.4);style.set_border_width_all(1)
	add_theme_stylebox_override("normal",style)
	pressed.connect(func():
		if not item.is_empty():app.selected_item_uid=item.uid;app.pending_message=tooltip_text;app.play_sound_id(EditionRules.item_sound(item.type)))
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and not item.is_empty():
			if event.button_index==MOUSE_BUTTON_RIGHT or event.double_click:
				var ok:=false
				if container_id in ["equipment","warehouse"]:ok=app.rules.inventory_action("move",{"uid":item.uid,"container":"inventory","slot":EditionInventory.free_slot(app.rules.state.items,"inventory")})
				else:ok=app.gameplay.use_item_uid(item.uid)
				if container_id in ["equipment","warehouse"]:app.pending_message=app.rules.message
				accept_event())

func _process(_delta: float) -> void:
	if app==null:return
	item={}
	for candidate in app.rules.state.get("items",[]):
		if candidate.container==container_id and int(candidate.slot)==slot_index:item=candidate;break
	if item.is_empty():text="";tooltip_text=empty_name;queue_redraw();return
	var spec: Dictionary=EditionRules.ITEMS[item.type]
	text=""
	queue_redraw()
	tooltip_text=spec.name+"\n数量："+str(int(item.count))+"\n重量："+str(spec.weight)
	if item.type=="ref:135":tooltip_text+="\n"+str(spec.description)
	if item.type=="ref:87":tooltip_text+="\n22级可装备；废矿入口至废矿区南部面向矿壁使用攻击操作。每镐损耗1耐久，矿石需拾取；损坏后找铁匠修理。"
	if item.type=="ref:134":tooltip_text+="\n回到边界村出生点（当前单机规则）；成功后消耗一张。"
	if spec.has("skill_book"):tooltip_text+="\n"+app.rules.skill_book_brief(item.type)
	if spec.has("material_bundle"):tooltip_text+="\n"+EditionRules.material_bundle_text(item.type)
	if EditionRules.item_accuracy(item.type)>0:tooltip_text+="\n准确：+%d（装备且耐久大于零时生效）"%EditionRules.item_accuracy(item.type)
	if spec.has("slot") or int(spec.get("std_mode",-1))==43:tooltip_text+="\n"+EditionInventory.condition_text(item)
	tooltip_text+="\n拖拽移动 · 右键/双击取回背包" if container_id=="warehouse" else "\n拖拽移动 · 右键/双击使用或穿脱"

func _get_drag_data(_position: Vector2):
	if item.is_empty() or app.world.paused:return null
	var preview:=Label.new();preview.text=EditionRules.ITEMS[item.type].name;set_drag_preview(preview)
	return {"kind":"item","uid":item.uid,"character":app.rules.character.id}

func _can_drop_data(_position: Vector2,data) -> bool:
	return data is Dictionary and data.get("kind")=="item" and data.get("character")==app.rules.character.id and not app.world.paused

func _drop_data(_position: Vector2,data) -> void:
	if not _can_drop_data(_position,data):return
	var type: String=EditionInventory.find_item(app.rules.state,data.uid).get("type","")
	var ok: bool=app.rules.inventory_action("move",{"uid":data.uid,"container":container_id,"slot":slot_index})
	app.pending_message=app.rules.message

func _draw() -> void:
	if app==null or item.is_empty():return
	if item.uid==app.selected_item_uid:draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),Color.GOLD,false,1)
	if paperdoll:return
	var spec: Dictionary=EditionRules.ITEMS[item.type]
	if int(spec.icon)==0 and not spec.has("skill_book"):return
	var frame: Dictionary=app.resources.frame("items",int(spec.icon))
	if frame.is_empty():return
	var factor:=minf(1,minf(32.0/frame.size.x,26.0/frame.size.y))
	draw_texture_rect(frame.texture,Rect2((size-frame.size*factor)/2,frame.size*factor),false)
	if item.count>1:draw_string(app.font,Vector2(2,size.y-2),str(int(item.count)),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
