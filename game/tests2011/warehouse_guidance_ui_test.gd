extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/warehouse-guidance-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_mongchon_storage")
	for controller in [false,true]:
		app.windows.close_all();app.start_character({"id":"warehouse-guidance-"+str(controller),"name":"存取准备","job":"战士","gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted"
		expect(app.rules.apply(next,"accepted_fixture"),"prepare task")
		# Move starter supply away before entering the required warehouse.
		for i in range(5):expect(app.rules.warehouse("potion",true),"prepare existing stored medicine")
		if controller:app.show_controller_story(app.rules.story_npc(q.start_npc))
		else:app.show_quest_entry(q.id)
		await settle();var view=app.form.get_child(1)
		if controller:
			for i in range(view.rows.size()):
				if view.rows[i].id==q.id:view.cursor=i;break
			view.open_detail();await settle()
		var shown: String=view.text.text if controller else view.material_lines[0].label.text
		expect("背包 0 · 仓库 5" in shown and "先从仓库取回" in shown,"stored-only guidance visible")
		expect(app.rules.save_location("0145",Vector2i(10,12),app.elapsed),"prepare required warehouse map")
		expect(app.rules.warehouse("potion",false),"retrieve old medicine first");await settle()
		shown=view.text.text if controller else view.material_lines[0].label.text
		expect("背包 1 · 仓库 4" in shown and "下一步：到指定仓库存入" in shown,"old withdrawal still requires deposit")
		expect(app.rules.warehouse("potion",true),"deposit required medicine");await settle()
		shown=view.text.text if controller else view.material_lines[0].label.text
		expect("下一步：在指定仓库取回" in shown,"committed deposit advances guidance")
		expect(app.rules.warehouse("potion",false),"withdraw required medicine");await settle()
		shown=view.text.text if controller else view.material_lines[0].label.text
		expect(not "存取准备" in shown,"completed warehouse objectives clear preparation text")
	var report:={"checks":checks,"failures":failures,"scope":"mouse and controller visible task text updated by warehouse transactions; task/map fixtures, no physical input or travel"}
	FileAccess.open("res://../artifacts/world-story/warehouse-guidance-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
