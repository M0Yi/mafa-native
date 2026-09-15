extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/purchase-budget-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_mongchon_medicine_purchase")
	for controller in [false,true]:
		app.windows.close_all();app.start_character({"id":"budget-"+str(controller),"name":"购药计划","job":"战士","gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.gold=500;expect(app.rules.apply(next,"quest_budget_fixture"),"prepare quest and money")
		var npc: Dictionary=app.rules.story_npc("server:merchant:71")
		if controller:app.show_controller_story(npc)
		else:app.show_story(npc)
		await settle();var view=app.form.get_child(1)
		if controller:
			for i in range(view.rows.size()):
				if view.rows[i].id==q.id:view.cursor=i;break
			view.open_detail()
		else:view.selected=q.id;view.refresh()
		await settle()
		var expected: String=app.rules.story_materials_text(q,app.elapsed)
		expect(not expected.is_empty(),"initial purchase budget exists")
		expect(expected in view.text.text if controller else view.material_lines[0].label.text==expected,"initial budget visible")
		var exhausted: Dictionary=app.rules.state.duplicate(true)
		exhausted.merchant_stock={"server:merchant:71:potion":{"count":0,"at":app.elapsed}}
		expect(app.rules.apply(exhausted,"empty_stock_fixture"),"prepare sold-out medicine")
		await settle()
		var snapshot: Dictionary=app.rules.state.duplicate(true)
		var shown: String=view.text.text if controller else view.material_lines[0].label.text
		expect("当前库存 0" in shown and "秒游戏时间后补货" in shown,"sold-out status visible")
		await settle()
		expect((view.text.text if controller else view.material_lines[0].label.text)==shown,"no game time advancement leaves countdown fixed")
		expect(not app.rules.reference_trade(npc.id,"potion",true,app.elapsed),"sold-out purchase rejected")
		expect(app.rules.state==snapshot,"sold-out attempt leaves money items progress and stock unchanged")
		app.elapsed+=59;await settle()
		shown=view.text.text if controller else view.material_lines[0].label.text
		expect("约 1 秒游戏时间后补货" in shown and "当前库存 0" in shown,"countdown updates before restock boundary")
		expect(not app.rules.reference_trade(npc.id,"potion",true,app.elapsed) and app.rules.state==snapshot,"cannot purchase one second before restock")
		app.elapsed+=1;await settle()
		shown=view.text.text if controller else view.material_lines[0].label.text
		expect(not "当前库存 0" in shown and app.rules.state==snapshot,"elapsed restock shown without mutating stored stock")
		for item in ["potion","mana"]:
			expect(app.rules.reference_trade(npc.id,item,true,app.elapsed),"buy medicine through actual rule transaction")
			await settle();expected=app.rules.story_materials_text(q,app.elapsed)
			if controller:expect(expected in view.text.text if not expected.is_empty() else not "尚需购买：" in view.text.text,"controller budget follows purchases")
			else:expect(view.material_lines[0].label.text==expected,"mouse budget follows purchases")
		var text_before: String=view.text.text if controller else view.material_lines[0].label.text
		expect(app.rules.warehouse("potion",true),"unrelated later transaction")
		await settle()
		expect(view.text.text==text_before if controller else view.material_lines[0].label.text==text_before,"empty budget remains stable after unrelated change")
	var report:={"checks":checks,"failures":failures,"scope":"visible mouse/controller task nodes live-update through real purchase transactions; prepared task/funds, no physical input or travel"}
	FileAccess.open("res://../artifacts/world-story/purchase-budget-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
