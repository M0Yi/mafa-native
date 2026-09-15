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
func find_button(node: Node,title: String):
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found=find_button(child,title)
		if found!=null:return found
	return null
func click(button: Control) -> void:
	var parent=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.global_position=e.position;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-repair-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"repair-ui","name":"修理验收","gender":"男","job":"战士"})
	var quest_id:=OS.get_environment("MAFA_REPAIR_QUEST")
	if quest_id.is_empty():quest_id="story_home_repair"
	var q: Dictionary=Story.quest(quest_id)
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.gold=10000
	var slot: int=EditionInventory.SLOTS.find("weapon")
	next.items=next.items.filter(func(item):return item.container!="equipment" or int(item.slot)!=slot)
	next.items.append(EditionInventory.make_item("wood_sword",1,"equipment",slot,50));EditionInventory.mirror(next)
	expect(app.rules.apply(next,"repair_ui_wear_fixture"),"prepare accepted task and worn weapon")
	expect(app.rules.shop("wood_sword",1),"buy spare sword for sale entry")
	var smith: Dictionary=app.rules.story_npc(q.objectives[0].npc)
	next=app.rules.state.duplicate(true)
	for item in next.items:
		if item.container=="inventory" and item.type=="wood_sword":item.durability=20
	var armor_slot:=EditionInventory.SLOTS.find("armor")
	next.items=next.items.filter(func(item):return item.container!="equipment" or int(item.slot)!=armor_slot)
	next.items.append(EditionInventory.make_item("robe",1,"equipment",armor_slot,30));EditionInventory.mirror(next)
	expect(app.rules.apply(next,"unrelated_wear_fixture"),"prepare worn spare and unrelated armor")
	var unquoted: Array=[]
	for item in app.rules.state.items:
		if item.container=="inventory" and item.type=="wood_sword" or item.container=="equipment" and item.type=="robe":unquoted.append(item.duplicate(true))

	expect(app.enter_map(smith.map,Vector2i(smith.cell[0],smith.cell[1])+Vector2i(1,0)),"load actual smith map")
	app.world.paused=false;app.show_story(smith);await settle()
	var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	var service=find_button(view,"打开修理服务")
	expect(service!=null,"named smith task exposes original repair service")
	if service!=null:
		var unchanged: Dictionary=app.rules.state.duplicate(true)
		app.world.player.cell+=Vector2i(20,20);await click(service)
		expect(is_instance_valid(view) and app.rules.state==unchanged,"distant task service entry refused")
		app.world.player.cell=Vector2i(smith.cell[0],smith.cell[1])+Vector2i(1,0)
		app.world.paused=true;await click(service)
		expect(is_instance_valid(view) and app.rules.state==unchanged,"paused task service entry refused")
		app.world.paused=false;await click(service)
		expect(find_button(app.form,"修理装备")!=null and app.rules.state==unchanged,"mouse opens original service without automatic repair or fee")

	expect(find_button(app.form,"出售 "+str(EditionRules.ITEMS.wood_sword.name)+" ×1")!=null,"supported weapon sale appears in merchant UI")
	var quote: Dictionary=app.rules.reference_repair_quote(smith.id)
	expect(quote.items.size()==1 and int(quote.cost)>0,"quote covers worn equipped weapon only")
	expect("耐久 50%" in app.rules.story_repair_brief(smith.id),"task explains wear and cost")
	var repair=find_button(app.form,"修理装备")
	expect(repair!=null,"repair control available")
	if repair!=null:
		var before: Dictionary=app.rules.state.duplicate(true)
		app.world.player.cell+=Vector2i(20,20);await click(repair)
		expect(app.rules.state==before,"stale remote repair window cannot progress task")
		app.world.player.cell=Vector2i(smith.cell[0],smith.cell[1])+Vector2i(1,0)
		app.store.db.query("PRAGMA query_only=ON;");await click(repair)
		expect(app.rules.state==before,"mouse repair save failure preserves all state")
		app.store.db.query("PRAGMA query_only=OFF;");await click(repair)
		expect(Story.ready(app.rules.state,q),"actual mouse repair advances service objective")
		expect(app.rules.state.gold==before.gold-int(quote.cost),"actual repair matches quote")
		for untouched in unquoted:expect(EditionInventory.find_item(app.rules.state,untouched.uid)==untouched,"repair leaves spare weapon and armor unchanged")
		expect(app.rules.reference_repair_quote(smith.id).items.is_empty(),"healthy weapon has no quote despite other damaged items")
		expect("不必故意损坏装备" in app.rules.story_repair_brief(smith.id),"no eligible repair explains that damage is not required")
		expect(int(app.store.load_world(app.rules.character.id).get("story_progress",{}).get(q.id,{}).get("0",0))==1,"service progress persists")
		before=app.rules.state.duplicate(true);await click(repair)
		expect(app.rules.state==before,"healthy equipment repeat click has no cost or progress")
	for mode in ["mouse","controller"]:
		app.windows.close_all();app.start_character({"id":"repair-live-"+mode,"name":"修理提示","gender":"男","job":"战士"})
		app.enter_map(smith.map,Vector2i(smith.cell[0],smith.cell[1])+Vector2i.RIGHT);app.world.paused=false
		next=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.gold=1000
		next.items=next.items.filter(func(item):return item.container!="equipment" or int(item.slot)!=slot)
		next.items.append(EditionInventory.make_item("wood_sword",1,"equipment",slot,50));EditionInventory.mirror(next)
		expect(app.rules.apply(next,"live_repair_fixture"),"prepare live repair detail")
		if mode=="mouse":
			app.show_story(smith);await settle();view=app.form.get_child(1);view.selected=q.id;view.refresh()
		else:
			app.controller_interact(smith);await settle();view=app.form.get_child(1)
			for i in range(view.rows.size()):
				if view.rows[i].id==q.id:view.cursor=i;break
			view.open_detail()
		await settle()
		next=app.rules.state.duplicate(true);next.gold=0
		expect(app.rules.apply(next,"empty_budget_fixture"),"change budget while detail remains open")
		await settle()
		var brief: String=app.rules.story_repair_brief(smith.id)
		expect(view.details.get_children().any(func(c):return c is Label and c.text==brief) if mode=="mouse" else brief in view.text.text,"live quote updates budget gap")
		next=app.rules.state.duplicate(true);next.gold=1000;app.rules.apply(next,"restore_repair_budget")
		expect(app.rules.reference_repair(smith.id),"repair while task reading remains open")
		await settle()
		expect(view.details.get_children().any(func(c):return c is Label and c.text=="修理目标已完成。") if mode=="mouse" else view.reading and "修理目标已完成。" in view.text.text,"completed repair removes obsolete quote")
	var report:={"checks":checks,"failures":failures,"scope":"native mouse merchant repair, sale entry visibility, stale distance and save failure; task acceptance, travel and equipment wear are fixtures"}
	FileAccess.open("res://../artifacts/world-story/repair-ui-"+q.id+"-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
