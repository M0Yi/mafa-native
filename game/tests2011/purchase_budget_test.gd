extends SceneTree
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	var store:=EditionStore.new();store.path="/tmp/purchase-budget-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";expect(store.open(),"isolated database")
	var rules:=EditionRules.new();rules.store=store;expect(rules.attach({"id":"budget","name":"采购预算","job":"战士","gender":"男"}),"character")
	var q: Dictionary=EditionRules.Story.quest("story_mongchon_medicine_purchase")
	var next:=rules.state.duplicate(true);next.quests[q.id]="accepted";next.gold=0;expect(rules.apply(next,"budget_fixture"),"prepare empty wallet")
	var shop: Dictionary=EditionRegion.shop("server:merchant:71")
	var red:=maxi(1,int(EditionRules.ITEMS.potion.price)*int(shop.price_rate)/100)
	var blue:=maxi(1,int(EditionRules.ITEMS.mana.price)*int(shop.price_rate)/100)
	var text:=rules.story_materials_text(q)
	expect("预计合计 %d 金币"%(red+blue) in text and "还缺 %d"%(red+blue) in text,"both medicines budgeted despite starting inventory")
	next=rules.state.duplicate(true);next.gold=500;expect(rules.apply(next,"funds_fixture"),"fund purchase")
	expect(rules.reference_trade("server:merchant:71","potion",true,0),"actual first purchase")
	text=rules.story_materials_text(q)
	expect("预计合计 %d 金币"%blue in text and not "金创药 ×" in text,"budget excludes already purchased medicine")
	expect(rules.reference_trade("server:merchant:71","mana",true,0),"actual second purchase")
	expect(rules.story_materials_text(q).is_empty(),"no remaining shopping budget after both purchases")
	var report:={"checks":checks,"failures":failures,"scope":"purchase budget against actual trade calculation and purchase records; prepared quest/funds, no UI/travel"}
	FileAccess.open("res://../artifacts/world-story/purchase-budget-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));store.close();quit(0 if failures.is_empty() else 1)
