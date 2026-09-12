extends Node
# Observe committed revisions only; keep row positions stable during a sale.
var app
var uid: String
var item_type: String
var original_slot: int
var revision:=-1
func setup(host,item: Dictionary) -> void:
	app=host;uid=item.uid;item_type=item.type;original_slot=int(item.slot)
	refresh()
func _process(_delta: float) -> void:
	if app!=null and revision!=int(app.rules.state.get("revision",0)):refresh()
func refresh() -> void:
	revision=int(app.rules.state.get("revision",0))
	var row: Button=get_parent()
	var item:=EditionInventory.find_item(app.rules.state,uid)
	var name: String=EditionRules.ITEMS[item_type].name
	row.disabled=item.is_empty() or item.get("container")!="inventory" or item.get("type")!=item_type
	if row.disabled:
		row.text="已无此背包物品 · %s · 原格%d"%[name,original_slot+1]
	else:
		row.text="出售 %s ×1 · %s · 格%d · 余%d"%[name,EditionInventory.condition_text(item),int(item.slot)+1,int(item.count)]
	row.tooltip_text=row.text
