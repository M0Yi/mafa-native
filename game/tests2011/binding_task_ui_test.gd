extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func mouse(at: Vector2,press: int=-1,relative:=Vector2.ZERO,button:=MOUSE_BUTTON_LEFT,double:=false) -> void:
	if press<0:
		var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.relative=relative;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true)
	else:
		var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=button;e.pressed=press==1;e.double_click=double;root.push_input(e,true)
	await settle()
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/binding-task-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"warehouse_mouse","name":"寄放操作","gender":"男","job":"战士"})
	var quest_id:=OS.get_environment("MAFA_BINDING_QUEST")
	if quest_id.is_empty():quest_id="story_palace_medicine"
	var q: Dictionary=Story.quest(quest_id)
	var ingredient: String=EditionRules.MEDICINE_BUNDLES.merged(EditionRules.SCROLL_BUNDLES)[q.objectives[0].item]
	var npc: Dictionary=app.rules.story_npc(q.start_npc)
	var at:=Vector2i(npc.cell[0],npc.cell[1])+Vector2i.DOWN
	app.enter_map(npc.map,at);app.world.paused=false
	expect(app.save_world(),"persist actual loaded location fixture")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.requires[0]]="done"
	expect(app.rules.apply(next,"prerequisite_fixture"),"prerequisite fixture")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept fixture")
	var before_open: Dictionary=app.rules.state.duplicate(true)
	app.show_story(npc);await settle()
	var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var brief:=Story.binding_brief(app.rules.state,q.objectives[0],EditionRules.ITEMS)
	expect(view.details.get_children().any(func(c):return c is Label and c.text==brief),"mouse details show current supplies")
	var missing: Dictionary=app.rules.state.duplicate(true);missing.inventory[ingredient]=2;missing.gold=30;missing.warehouse[ingredient]=100
	var missing_text:=Story.binding_brief(missing,q.objectives[0],EditionRules.ITEMS)
	expect("2 / 6（还缺 4）" in missing_text and "当前 30（还缺 70）" in missing_text,"missing quantities exclude warehouse stock")
	expect(app.rules.shop(ingredient,1),"purchase supply while detail remains open")
	await settle();brief=Story.binding_brief(app.rules.state,q.objectives[0],EditionRules.ITEMS)
	expect(view.details.get_children().any(func(c):return c is Label and c.text==brief),"mouse supplies update without reopening")
	before_open=app.rules.state.duplicate(true)
	var open: Button=null
	for child in view.details.get_children():
		if child is Button and child.text=="打开捆扎服务":open=child
	expect(open!=null,"task offers binding action")
	if open!=null:
		view.details.get_parent().ensure_control_visible(open);await settle()
		await mouse(open.get_global_rect().get_center(),1);await mouse(open.get_global_rect().get_center(),0)
	expect(app.panel.navigation_buttons(app.panel.body).any(func(b):return b.text.begins_with("捆扎 ")),"mouse opens binding services without executing a recipe")
	expect(not Story.ready(app.rules.state,q),"opening service does not finish commission")
	expect(app.rules.state==before_open,"viewing service does not modify items")
	app.windows.close_all();app.controller_interact(npc);await settle()
	var controller=app.form.get_child(1)
	for i in range(controller.rows.size()):
		if controller.rows[i].id==q.id:controller.cursor=i;break
	controller.open_detail()
	expect(brief in controller.text.text,"controller details share identical supplies")
	expect(app.rules.warehouse(ingredient,true),"deposit while controller detail remains open")
	await settle();brief=Story.binding_brief(app.rules.state,q.objectives[0],EditionRules.ITEMS)
	expect(controller.reading and brief in controller.text.text,"controller supplies update without leaving reading mode")
	# Keep the reader open while the actual service commits its completion event.
	next=app.rules.state.duplicate(true);next.gold=100;next.items=[];next.inventory={ingredient:6};next.warehouse={}
	expect(app.rules.apply(next,"binding_completion_supplies"),"prepare exact recipe supplies")
	await settle()
	expect(app.rules.bind_bundle(npc.id,npc.map,at,q.objectives[0].item),"actual service completes selected task")
	await settle()
	expect(controller.reading and "捆扎已完成" in controller.text.text and not "还缺" in controller.text.text,"reader stops requesting supplies after completion")
	expect(Story.objective_text(app.rules.state,q,0) in controller.text.text,"binding objective count refreshes with completion")
	expect(q.title+" · 可交付" in controller.text.text,"controller status agrees with completed goals")
	app.windows.close_all();app.show_story(npc);await settle()
	view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var submit: Button=view.submit_control
	expect(submit!=null and not submit.disabled,"completed task has enabled submit")
	next=app.rules.state.duplicate(true);next.story_progress.erase(q.id);next.gold=100;next.items=[];next.inventory={ingredient:6};next.warehouse={}
	expect(app.rules.apply(next,"unfulfilled_objective_fixture"),"restore accepted incomplete task fixture")
	await settle();expect(submit.disabled,"submit disables while objective is incomplete")
	expect(app.rules.bind_bundle(npc.id,npc.map,at,q.objectives[0].item),"complete actual recipe with mouse page open")
	await settle();expect(not submit.disabled and view.details.get_children().any(func(c):return c is Label and c.text=="待交付"),"mouse status and submit update without reopening")
	view.details.get_parent().ensure_control_visible(submit);await settle()
	await mouse(submit.get_global_rect().get_center(),1);await mouse(submit.get_global_rect().get_center(),0)
	expect(app.rules.state.quests[q.id]=="done","mouse submits completed binding task")
	expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","completed binding task saved")
	app.windows.close_all();app.start_character({"id":"lifecycle","name":"委托刷新","gender":"男","job":"战士"});app.enter_map(npc.map,at);app.world.paused=false
	next=app.rules.state.duplicate(true);next.quests[q.requires[0]]="done"
	expect(app.rules.apply(next,"unaccepted_lifecycle_fixture"),"prepare unaccepted lifecycle fixture")
	app.show_story(npc);await settle();view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	expect(view.selected==q.id and view.submit_control.text=="接受委托","external reset refreshes accepted action structure")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"accept through separate rule operation")
	await settle()
	expect(view.selected==q.id and view.submit_control.text=="交付委托" and view.submit_control.disabled,"external accept refreshes submit action")
	expect(app.rules.abandon_story(q.id),"abandon through separate rule operation")
	await settle()
	expect(view.submit_control.text=="接受委托" and not view.submit_control.disabled,"external abandon restores accept action")
	var current: Button=view.submit_control
	view.details.get_parent().ensure_control_visible(current);await settle()
	await mouse(current.get_global_rect().get_center(),1);await mouse(current.get_global_rect().get_center(),0)
	expect(app.rules.state.quests[q.id]=="accepted","refreshed mouse action accepts rather than submitting stale operation")
	app.windows.close_all();app.controller_interact(npc);await settle();controller=app.form.get_child(1)
	for i in range(controller.rows.size()):
		if controller.rows[i].id==q.id:controller.cursor=i;break
	controller.open_detail()
	expect(app.rules.abandon_story(q.id),"external abandon while controller reading")
	await settle()
	expect(controller.reading and controller.rows[controller.cursor].id==q.id and q.title+" · 可接取" in controller.text.text,"controller preserves task reading after external abandon")
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,at),"external accept while controller reading")
	await settle()
	expect(controller.reading and q.title+" · 进行中" in controller.text.text,"controller refreshes accepted task structure")
	app.windows.close_all();app.show_story(npc);await settle();view=app.form.get_child(1)
	view.search.text=q.title;view.status_filter="待交付";view.refresh();await settle()
	expect(view.visible_quest_ids.is_empty(),"unfinished task excluded from ready filter")
	next=app.rules.state.duplicate(true);next.gold=100;next.items=[];next.inventory={ingredient:6};next.warehouse={}
	expect(app.rules.apply(next,"filtered_recipe_fixture") and app.rules.bind_bundle(npc.id,npc.map,at,q.objectives[0].item),"finish task while ready filter is empty")
	await settle()
	expect(view.visible_quest_ids==[q.id] and view.submit_control!=null and not view.submit_control.disabled,"completed objective enters ready filter automatically")
	expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,at),"deliver filtered task externally")
	await settle()
	expect(view.visible_quest_ids.is_empty() and view.submit_control==null,"delivered task leaves ready filter without stale controls")
	var report:={"quest":q.id,"checks":checks,"failures":failures,"scope":"native mouse task detail opens binding services; positions and acceptance fixtures, no hardware input"}
	FileAccess.open("res://../artifacts/world-story/binding-task-ui-"+q.id+"-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
