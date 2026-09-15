extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var failures: Array=[]
var checks:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-receipts-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	var q: Dictionary=Story.quest("story_supplies");var npc: Dictionary=app.rules.story_npc(q.start_npc)
	for preset in ["classic","easy"]:
		app.preset=preset;app.start_character({"id":preset,"name":"收据验收","gender":"男","job":"战士"});app.world.paused=true
		var next: Dictionary=app.rules.state.duplicate(true);next.quests.story_letter="done"
		expect(app.rules.apply(next,"old_completion_fixture"),"old completed save accepted without receipts")
		expect("旧任务" in app.rules.quest_receipt_text("story_letter"),"old rewards not fabricated")
		var at:=Vector2i(npc.cell[0],npc.cell[1])
		expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept receipt task")
		var witness: Dictionary=app.rules.story_npc(q.objectives[0].npc)
		app.rules.story_talk(witness.id,witness.map,Vector2i(witness.cell[0],witness.cell[1]))
		var original_potions: int=app.rules.state.inventory.get("potion",0)
		for i in range(original_potions):expect(app.rules.warehouse("potion",true),"deposit actual task material")
		expect(not Story.ready(app.rules.state,q),"warehouse contents do not satisfy task")
		var stored: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==stored,"submission cannot consume from warehouse")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.warehouse("potion",false) and app.rules.state==stored,"failed withdrawal retains warehouse material")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.warehouse("potion",false),"first material withdrawal")
		expect(not Story.ready(app.rules.state,q),"partial withdrawal still insufficient")
		expect(app.rules.warehouse("potion",false) and Story.ready(app.rules.state,q),"second withdrawal enables submission")
		expect(app.rules.state.warehouse.get("potion",0)==original_potions-2,"only withdrawn quantity leaves warehouse")
		var combined: Dictionary=q.duplicate(true)
		combined.objectives=[{"type":"collect","item":"potion","count":2,"label":"第一份"},{"type":"collect","item":"potion","count":2,"label":"第二份"}]
		var supply: Dictionary=app.rules.state.duplicate(true);supply.inventory.potion=3
		expect(not Story.ready(supply,combined),"same material objectives require summed quantity")
		expect(Story.progress(supply,combined,0)==2 and Story.progress(supply,combined,1)==1,"same stack allocated once across objectives")
		expect(Story.next_objective(supply,combined).label=="第二份","next objective points at remaining material request")
		expect("1/2" in Story.objective_text(supply,combined,1),"objective text exposes remaining material")
		supply.inventory.potion=0
		expect(Story.progress(supply,combined,0)==0 and Story.progress(supply,combined,1)==0,"missing material never gives negative progress")

		supply.inventory.potion=4
		expect(Story.ready(supply,combined),"aggregate requirement can be satisfied")
		expect((str(EditionRules.ITEMS.potion.name)+" ×4") in app.rules.story_materials_text(combined),"material summary combines duplicate item goals")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"failure creates neither receipt nor reward")
		app.store.db.query("PRAGMA query_only=OFF;")
		app.enter_map(npc.map,at+Vector2i(1,0));app.world.paused=false;app.show_story(npc);await settle()
		var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
		var submit: Button=null
		for child in view.details.get_children():
			if child is Button and child.text=="交付委托":submit=child
		expect(submit!=null and not submit.disabled,"mouse delivery available")
		if submit!=null:
			view.details.get_parent().ensure_control_visible(submit);await settle()
			var e:=InputEventMouseButton.new();e.position=submit.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
		var receipt: Dictionary=app.rules.state.get("quest_receipts",{}).get(q.id,{})
		expect(not receipt.is_empty(),"mouse completion produces receipt")
		if receipt.is_empty():continue
		expect(receipt.gold==q.rewards.gold*(2 if preset=="easy" else 1) and receipt.xp==q.rewards.xp*(3 if preset=="easy" else 1),"actual preset rewards recorded")
		expect(receipt.consumed=={"potion":2},"exact consumed materials recorded")
		var preview: String=app.rules.quest_reward_text(int(q.rewards.gold),int(q.rewards.xp))
		expect(("金币 %d / 经验 %d"%[receipt.gold,receipt.xp]) in preview,"preview matches committed reward receipt")
		expect("物品奖励数量不翻倍" in preview,"preview distinguishes item quantities")
		expect(view.details.get_children().any(func(child):return child is Label and preview in child.text),"actual story panel shows current preset reward")

		for index in range(q.objectives.size()):
			var history:=Story.objective_text(app.rules.state,q,index)
			expect(history=="已完成 · "+str(q.objectives[index].label),"completed objective displays history rather than current inventory")
			expect(view.details.get_children().any(func(child):return child is Label and child.text==history),"mouse history renders completed objective")
		var active: Dictionary=app.rules.state.duplicate(true);active.quests[q.id]="accepted";active.inventory.erase("potion")
		for index in range(q.objectives.size()):
			if q.objectives[index].type=="collect":expect("0/2" in Story.objective_text(active,q,index),"active collection still reflects missing items")

		expect(app.chat_history.any(func(line):return q.title in line and "实际获得" in line and "交付消耗" in line),"mouse delivery posts readable chat receipt")
		expect(app.store.load_world(preset).quest_receipts[q.id]==JSON.parse_string(JSON.stringify(receipt)),"receipt durable in reward transaction")
		expect(app.rules.valid(app.store.load_world(preset)),"JSON numeric receipt remains valid after reload")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,at) and app.rules.state==before,"duplicate submit cannot change receipt")
		expect(app.save_world(),"save chat after delivery")
		expect(app.store.load_world(preset).chat_log.any(func(line):return "实际获得" in line),"chat retained on normal save")
		var invalid: Dictionary=app.rules.state.duplicate(true);invalid.quest_receipts[q.id].gold=-1
		expect(not app.rules.valid(invalid),"invalid receipt rejected")
		# Legacy regional commissions share the same atomic receipt, including tokens.
		expect(app.rules.quest("0"),"accept legacy regional commission")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.quest("0") and app.rules.state==before,"insufficient ore does not consume or record")
		next=app.rules.state.duplicate(true);next.inventory.ore=3
		expect(app.rules.apply(next,"ore_material_fixture"),"provide legacy ore")
		before=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.quest("0") and app.rules.state==before,"legacy failed save retains ore and all rewards")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.quest("0"),"retry legacy commission")
		app.info(app.rules.message)
		var legacy: Dictionary=app.rules.state.quest_receipts["ore:0"]
		expect(legacy.gold==100*(2 if preset=="easy" else 1) and legacy.xp==60*(3 if preset=="easy" else 1),"legacy exact preset receipt")
		expect(legacy.tokens==3 and app.rules.state.tokens==before.tokens+3,"tokens are not multiplied")
		expect(legacy.consumed=={"ore":3} and not app.rules.state.inventory.has("ore"),"exact legacy ore consumed")
		expect(app.rules.state.gold==before.gold+legacy.gold,"legacy receipt matches wealth delta")
		expect(app.store.load_world(preset).quest_receipts["ore:0"]==JSON.parse_string(JSON.stringify(legacy)),"legacy receipt committed with rewards")
		expect(app.chat_history.any(func(line):return "区域委托完成" in line and "探索徽记 ×3" in line and "铁矿 ×3" in line),"legacy receipt includes tokens and ore in chat")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.quest("0") and app.rules.state==before and "实际获得" in app.rules.message,"legacy duplicate reports receipt without rewards")
		invalid=app.rules.state.duplicate(true);invalid.quest_receipts["ore:0"].tokens=-1
		expect(not app.rules.valid(invalid),"negative token receipt rejected")
		invalid.quest_receipts["ore:0"].tokens=1.5
		expect(not app.rules.valid(invalid),"fractional token receipt rejected")
		next=app.rules.state.duplicate(true);next.quests["ore:1"]="done"
		expect(app.rules.apply(next,"legacy_no_receipt_fixture"),"old regional completion loads without receipt")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.quest("1") and app.rules.state==before and "旧任务" in app.rules.message,"old regional completion never backfilled or repaid")
		var alive: Dictionary=app.rules.state.duplicate(true)
		next=alive.duplicate(true);next.hp=0
		next.quests["ore:dead-ready"]="accepted";next.inventory.ore=3
		expect(app.rules.apply(next,"death_fixture"),"seed dead state")
		before=app.rules.state.duplicate(true)
		expect(not app.rules.novice_quest("nv_arrival"),"dead character cannot accept novice quest")
		expect(not app.rules.quest("death-test"),"dead character cannot accept regional quest")
		expect(not app.rules.exploration("death-test"),"dead character cannot gain exploration rewards")
		expect(not app.rules.quest("dead-ready"),"dead character cannot submit stocked regional quest")
		expect(app.rules.state==before and "死亡" in app.rules.message,"dead operations preserve state and explain refusal")
		alive.revision=app.rules.state.revision
		expect(app.rules.apply(alive,"restore_alive_fixture"),"restore living fixture")
		app.windows.close_all()
	var report:={"checks":checks,"failures":failures,"scope":"classic/easy story and legacy ore receipts including tokens, mouse story delivery and chat, atomic save failure, duplicate prevention and old-save compatibility; earlier objectives are fixtures"}
	FileAccess.open("res://../artifacts/world-story/receipts-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
