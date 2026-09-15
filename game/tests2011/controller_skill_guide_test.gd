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
func press(button: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/controller-skill-guide-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_book")
	for job in ["战士","法师","道士"]:
		app.windows.close_all();app.start_character({"id":"guide-"+job,"name":"修炼指引","gender":"男","job":job});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.gold=100000;next.quests[q.id]="accepted"
		expect(app.rules.apply(next,"accepted_task_level_fixture"),"prepare accepted task and level")
		var skill: String={"战士":"flame","法师":"shield","道士":"spirit"}[job]
		var book:=""
		for id in EditionRules.ITEMS:
			if EditionRules.ITEMS[id].get("skill_book","")==skill:book=id;break
		expect(app.rules.shop(book,1),"purchase profession book")
		app.show_controller_story(app.rules.story_npc(q.start_npc));await settle()
		var view=app.form.get_child(1)
		for i in range(view.rows.size()):
			if view.rows[i].id==q.id:view.cursor=i;break
		await press(JOY_BUTTON_A)
		expect(view.reading and "L3 技能指引" in view.hint.text,"generic task shows controller shortcut")
		var before: Dictionary=app.rules.state.duplicate(true)
		await press(JOY_BUTTON_LEFT_STICK)
		expect(app.windows.order.back()=="手柄技能指引","L3 opens independent guide")
		var guide=app.windows.windows["手柄技能指引"].body.get_child(1)
		expect(EditionSkills.DEFINITIONS[skill].name in guide.detail.text,"guide suggests owned usable book")
		await press(JOY_BUTTON_Y)
		expect(app.windows.order.back()=="手柄操作","Y opens controller inventory")
		var panel=app.windows.windows["手柄操作"].body.get_child(1)
		expect(panel.page==0 and panel.rows[panel.cursor].type==book,"inventory focuses recommended book")
		expect("可学习" in panel.detail.text and job in panel.detail.text and not "耐久" in panel.detail.text,"book detail shows learning conditions rather than equipment wear")
		await press(JOY_BUTTON_B)
		expect(app.windows.order.back()=="手柄技能指引","B returns to guide")
		await press(JOY_BUTTON_B)
		expect(app.windows.order.back()=="手柄人物委托" and view.reading and view.rows[view.cursor].id==q.id,"B restores original task detail")
		expect(app.rules.state==before,"navigation does not learn consume or change quest")
		expect(app.rules.shop(book,1),"second book supports duplicate-use check")
		await press(JOY_BUTTON_LEFT_STICK);await press(JOY_BUTTON_Y)
		panel=app.windows.windows["手柄操作"].body.get_child(1)
		var low: Dictionary=app.rules.state.duplicate(true);low.level=1
		expect(app.rules.apply(low,"low_level_fixture"),"prepare insufficient learning level")
		before=app.rules.state.duplicate(true);await press(JOY_BUTTON_A)
		expect(app.rules.state==before and not app.rules.state.skills.has(skill),"A cannot consume book below learning level")
		expect("还差" in panel.detail.text and "当前 1 级" in panel.detail.text,"failed low-level use explains exact level gap")
		low=app.rules.state.duplicate(true);low.level=60
		expect(app.rules.apply(low,"restore_learning_level_fixture"),"restore learning level")
		before=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;");await press(JOY_BUTTON_A);app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.state==before,"failed save leaves book skills and quest unchanged")
		await press(JOY_BUTTON_A)
		expect(app.rules.state.skills.has(skill) and int(app.rules.state.inventory.get(book,0))==int(before.inventory[book])-1,"A learns skill and consumes exactly one book")
		expect(EditionRules.Story.ready(app.rules.state,q),"learning actual book satisfies generic task")
		before=app.rules.state.duplicate(true)
		# Refresh may move the cursor if an item slot disappeared; select the remaining copy.
		for i in range(panel.rows.size()):
			if panel.rows[i].type==book:panel.cursor=i;panel.list.select(i);break
		await press(JOY_BUTTON_A)
		expect(app.rules.state==before,"duplicate learning preserves remaining book")
		expect("已学会" in panel.detail.text and "不会消耗" in panel.detail.text,"remaining copy explains already learned status")
		await press(JOY_BUTTON_B)
		guide=app.windows.windows["手柄技能指引"].body.get_child(1)
		expect("已满足学习目标" in guide.detail.text,"guide updates after learning")
		await press(JOY_BUTTON_B)
		expect(view.reading and view.rows[view.cursor].id==q.id and "已满足学习目标" in view.text.text,"task detail updates without losing selected task")
		var saved: Dictionary=app.store.load_world(app.rules.character.id)
		expect(saved.skills.has(skill) and saved.inventory.get(book,0)==app.rules.state.inventory.get(book,0) and EditionRules.Story.ready(saved,q),"stored skill book count and ready task agree")
	var report:={"checks":checks,"failures":failures,"scope":"three jobs with Viewport joypad input through task guide bag and back; task/level/funds fixtures, actual book purchase/use, insufficient level, save failure and duplicate-use checks, no hardware controller"}
	FileAccess.open("res://../artifacts/world-story/controller-skill-guide-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));var fixture_path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:
		var file: String=fixture_path+suffix
		if FileAccess.file_exists(file) and DirAccess.remove_absolute(file)!=OK:failures.append("Cannot clean test database: "+file)
	quit(0 if failures.is_empty() else 1)
