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
	app.store.path="/tmp/intro-skill-panel-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var objective: Dictionary=EditionRules.Story.quest("story_book").objectives[0]
	for job in ["战士","法师","道士"]:
		app.windows.close_all();app.start_character({"id":"panel-"+job,"name":"书页指引","gender":"男","job":job});app.world.hide()
		app.show_quest_entry("story_book");await settle()
		var view=app.form.get_child(1)
		expect(view.details.get_children().any(func(c):return c is Button and c.text=="打开当前推荐技能"),"generic quest exposes skill action")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.show_story_skill(objective);await settle()
		var journal=app.windows.windows["冒险面板"].body.get_child(1)
		expect(journal.content[3].selected=={"战士":"basic","法师":"fireball","道士":"heal"}[job],"initial action selects profession starter")
		expect(app.rules.state==before,"viewing skill does not learn consume or pay")
		var other: String={"战士":"flame","法师":"shield","道士":"spirit"}[job]
		var book:=""
		for id in EditionRules.ITEMS:
			if EditionRules.ITEMS[id].get("skill_book","")==other:book=id;break
		var next: Dictionary=app.rules.state.duplicate(true);next.level=60;next.gold=100000
		expect(app.rules.apply(next,"level_funds_fixture") and app.rules.shop(book,1),"prepare usable book through purchase")
		before=app.rules.state.duplicate(true);app.show_story_skill(objective);await settle()
		expect(journal.content[3].selected==other and app.rules.state==before,"reopened skill uses newly owned book without learning")
	var report:={"checks":checks,"failures":failures,"scope":"three-job visible action presence and skill navigation API with prepared level/funds and real book purchase; no physical input"}
	FileAccess.open("res://../artifacts/world-story/intro-skill-panel-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
