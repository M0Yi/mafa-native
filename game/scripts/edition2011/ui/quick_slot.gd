class_name EditionQuickSlot
extends Button
var app
var index:=0
func _can_drop_data(_at: Vector2,data) -> bool:
	if not data is Dictionary or data.get("kind")!="item" or data.get("character")!=app.rules.character.id or app.world.paused or app.rules.state.hp<=0:return false
	var item:=EditionInventory.find_item(app.rules.state,str(data.get("uid","")))
	return item.get("container")=="inventory"
func _drop_data(at: Vector2,data) -> void:
	if _can_drop_data(at,data):
		app.rules.inventory_action("bind",{"uid":data.uid,"slot":index});app.pending_message=app.rules.message
func _process(_delta: float) -> void:
	if app==null or app.rules.state.is_empty():return
	var id: String=app.rules.state.get("quickbar",["","","","","",""])[index]
	text=str(index+1) if id.is_empty() else ""
	tooltip_text="快捷栏 %d · 拖入背包物品"%(index+1) if id.is_empty() else "%s ×%d · 按 %d 使用"%[EditionRules.ITEMS.get(id,{}).get("name",id),int(app.rules.state.inventory.get(id,0)),index+1]
	queue_redraw()
func _draw() -> void:
	if app==null or app.rules.state.is_empty():return
	var id: String=app.rules.state.get("quickbar",["","","","","",""])[index]
	if id.is_empty():return
	var spec: Dictionary=EditionRules.ITEMS.get(id,{})
	var f: Dictionary=app.resources.frame("items",int(spec.get("icon",0)))
	if not f.is_empty():
		var factor:=minf(1,minf(28.0/f.size.x,24.0/f.size.y))
		draw_texture_rect(f.texture,Rect2((size-f.size*factor)/2,f.size*factor),false,Color.WHITE if app.rules.state.inventory.get(id,0)>0 else Color(0.4,0.4,0.4))
	draw_string(app.font,Vector2(2,11),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.GOLD)
	draw_string(app.font,Vector2(18,30),str(int(app.rules.state.inventory.get(id,0))),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
