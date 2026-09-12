extends Control
var app
var embedded_mode:=false
var page:=0
var stats:=Label.new()
var details:=Label.new()
var title:=Label.new()
var slots: Array[EditionItemSlot]=[]
# Coordinates measured against Prguse 376/377, not the older Delphi layout.
const BODY_ORIGIN=Vector2(36,52)
const LAYER_ORIGIN=BODY_ORIGIN-Vector2(7,-44)
const POSITIONS=[Rect2(68,108,32,61),Rect2(104,124,48,115),Rect2(111,94,24,24),Rect2(166,87,36,32),Rect2(166,176,36,32),Rect2(40,176,36,32),Rect2(166,215,36,32),Rect2(40,215,36,32),Rect2(42,280,32,30),Rect2(83,280,32,30),Rect2(124,280,32,30),Rect2(166,126,36,32),Rect2(165,280,32,30)]
var extra_labels: Array[Label]=[]
func setup(host,embedded:=false) -> void:
	embedded_mode=embedded;app=host;mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(232,325);size=custom_minimum_size
	for i in range(EditionInventory.SLOTS.size()):
		var slot:=EditionItemSlot.new();slot.setup(app,"equipment",i)
		var rect: Rect2=POSITIONS[i]
		slot.paperdoll=i in [0,1,2]
		# Original body artwork already contains the accessory borders.
		for state_name in ["normal","hover","pressed","focus","disabled"]:slot.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
		slot.position=rect.position;slot.custom_minimum_size=rect.size;slot.size=rect.size
		if i in [8,9,10,12]:
			var name_label:=Label.new();name_label.text=EditionInventory.SLOT_NAMES[i];name_label.position=Vector2(rect.position.x-3,265);name_label.size=Vector2(38,14);name_label.add_theme_font_size_override("font_size",10);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(name_label);extra_labels.append(name_label)
			name_label.set_deferred("size",Vector2(38,14))
		slot.empty_name=EditionInventory.SLOT_NAMES[i];add_child(slot);slots.append(slot)
		# Apply after the inherited bag minimum size has been invalidated.
		slot.set_deferred("size",rect.size)
	title.position=Vector2(55,12);title.size=Vector2(140,20);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",12);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(title)
	stats.position=Vector2(43,61);stats.size=Vector2(154,185);stats.add_theme_font_size_override("font_size",13);stats.mouse_filter=Control.MOUSE_FILTER_IGNORE;stats.clip_text=true;add_child(stats)
	details.position=Vector2(30,274);details.size=Vector2(182,42);details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.clip_text=true;details.add_theme_font_size_override("font_size",12);details.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(details)
	for spec in [[Rect2(7,40,17,23),"关闭人物面板",0],[Rect2(4,130,28,30),"上一页：装备 / 属性",-1],[Rect2(4,190,28,30),"下一页：装备 / 属性",1]]:
		var button:=EditionSkinButton.new();button.resources=app.resources;button.position=spec[0].position;button.size=spec[0].size;button.tooltip_text=spec[1];add_child(button)
		button.visible=not embedded
		button.pressed.connect(func():
			if spec[2]==0:app.windows.close("人物属性")
			else:page=posmod(page+int(spec[2]),2);app.play_sound_id(105);update_page())
	update_page()
func update_page() -> void:
	for slot in slots:slot.visible=page==0
	stats.visible=page==1;details.visible=page==1
	for item_label in extra_labels:item_label.visible=page==0
	title.text=("装备" if page==0 else "属性") if embedded_mode else ("装备  1/2" if page==0 else "属性  2/2");queue_redraw()
func _process(_delta: float) -> void:
	if app==null:return
	stats.text="%s · %s\n等级 %d\n\n攻击 %d　防御 %d\n生命 %d/%d\n魔法 %d/%d\n负重 %d/%d\n金币 %d"%[app.rules.character.name,app.rules.character.job,app.rules.state.level,app.rules.attack(),app.rules.defense(),app.rules.state.hp,app.rules.max_hp(),app.rules.state.mp,app.rules.max_mp(),app.rules.weight(app.rules.state),100+int(app.rules.state.level)*5,app.rules.state.gold]
	stats.tooltip_text=stats.text
	var item:=EditionInventory.find_item(app.rules.state,app.selected_item_uid)
	if item.get("container")!="equipment":item={}
	details.text="%s  Lv.%d\n攻击 %d  防御 %d"%[app.rules.character.name,app.rules.state.level,app.rules.attack(),app.rules.defense()] if item.is_empty() else "%s · 耐久 %d\n攻击 +%d  防御 +%d"%[EditionRules.ITEMS[item.type].name,item.durability,EditionRules.ITEMS[item.type].get("attack",0),EditionRules.ITEMS[item.type].get("defense",0)]
	details.tooltip_text=details.text;queue_redraw()
func sprite(bank: String,index: int,at: Vector2,offsets:=false) -> void:
	var image: Dictionary=app.resources.frame(bank,index)
	if not image.is_empty():draw_texture(image.texture,at+(image.offset if offsets else Vector2.ZERO))
func _draw() -> void:
	if app==null:return
	var sex:=1 if app.rules.character.gender=="女" else 0
	if not embedded_mode:sprite("prguse",370,Vector2.ZERO)
	if page==1:sprite("prguse",382,BODY_ORIGIN);return
	sprite("prguse",376+sex,BODY_ORIGIN)
	for slot in ["armor","weapon","helmet"]:
		var type: String=app.rules.state.equipment.get(slot,"")
		if type.is_empty():continue
		var icon:=int(EditionRules.ITEMS[type].icon)
		if type=="robe" and sex==1:icon=80
		sprite("stateitem",icon,LAYER_ORIGIN,true)

	for i in [8,9,10,12]:draw_rect(POSITIONS[i],Color("80704b"),false,1)
