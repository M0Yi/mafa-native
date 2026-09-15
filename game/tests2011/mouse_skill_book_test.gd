extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func click(node: Control,button: int) -> void:
	var e:=InputEventMouseButton.new();e.position=node.get_global_rect().get_center();e.global_position=e.position;e.button_index=button;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mouse-skill-book-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_book")
	for job in ["战士","法师","道士"]:
		app.windows.close_all();app.start_character({"id":"mouse-book-"+job,"name":"书页操作","gender":"男","job":job});app.world.hide();app.world.paused=false
		var book: String={"战士":"ref:16","法师":"ref:14","道士":"ref:15"}[job]
		var skill: String=EditionRules.ITEMS[book].skill_book
		var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.gold=10000
		expect(app.rules.apply(next,"quest_money_fixture") and app.rules.shop(book,2),"prepare two profession books")
		app.show_bag();await settle()
		var bag=app.windows.windows["冒险面板"].body.get_child(1).content[0].get_child(0)
		var slot: Control=null
		for child in bag.cells.get_children():
			if child.item.get("type","")==book:slot=child;break
		expect(slot!=null,"book slot visible")
		if slot==null:continue
		expect("还差 6 级" in slot.tooltip_text and job in slot.tooltip_text,"tooltip states learning requirement")
		await click(slot,MOUSE_BUTTON_LEFT)
		expect(not "耐久" in bag.detail.text and "7 级学习" in bag.detail.text and "还差 6 级" in bag.detail.tooltip_text,"selected book summary and expanded detail are consistent")
		var before: Dictionary=app.rules.state.duplicate(true)
		await click(slot,MOUSE_BUTTON_RIGHT)
		expect(app.rules.state==before,"right click below level leaves book and task unchanged")
		next=app.rules.state.duplicate(true);next.level=7
		expect(app.rules.apply(next,"learning_level_fixture"),"prepare learning level");await settle()
		expect("可学习" in slot.tooltip_text,"tooltip follows changed learning level")
		await click(slot,MOUSE_BUTTON_RIGHT)
		expect(app.rules.state.skills.has(skill) and app.rules.state.inventory.get(book,0)==1 and EditionRules.Story.ready(app.rules.state,q),"right click learns once and satisfies task")
		expect("已学会" in slot.tooltip_text,"remaining copy tooltip follows learned status")
		before=app.rules.state.duplicate(true);await click(slot,MOUSE_BUTTON_RIGHT)
		expect(app.rules.state==before,"repeat use does not consume spare book")
		app.show_quest_entry(q.id);await settle()
		expect("已满足学习目标" in app.form.get_child(1).skill_lines[0].label.text,"task details show mouse learning outcome")
	var report:={"checks":checks,"failures":failures,"scope":"three professions Viewport mouse selection/right click, tooltip properties and task UI; funds/level/task fixtures, no physical mouse or tooltip screenshot"}
	FileAccess.open("res://../artifacts/world-story/mouse-skill-book-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
