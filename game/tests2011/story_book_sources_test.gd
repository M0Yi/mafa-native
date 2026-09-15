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
	app.store.path="/tmp/story-book-sources-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"sources-"+job,"name":"书本指引","gender":"男","job":job});app.world.paused=true
		for q in Story.data().quests:
			if q.has("jobs") and job not in q.jobs:continue
			for o in q.objectives:
				if o.type!="skill":continue
				var sources: Array=Story.skill_book_sources(app.rules.state,o,EditionRules.ITEMS,job)
				expect(not sources.is_empty() or not Story.skill_book_merchants(app.rules.state,o,EditionRules.ITEMS,job).is_empty() or not Story.skill_book_drops(o,EditionRules.ITEMS,job).is_empty(),"authored skill objective has a obtainable book source "+job+q.id)
				for merchant in Story.skill_book_merchants(app.rules.state,o,EditionRules.ITEMS,job):
					expect(EditionRegion.data().npcs.any(func(n):return n.id==merchant.npc and n.enabled),"book merchant is enabled in world")
					for book in merchant.books:
						var skill: String=EditionRules.ITEMS[book.id].skill_book
						expect(EditionSkills.DEFINITIONS[skill].job==job,"merchant book matches profession")
						if o.has("skills_by_job"):expect(skill==o.skills_by_job[job],"merchant book matches exact objective")
						expect(EditionRegion.shop(merchant.npc).goods.any(func(row):return row.type==book.id and int(row.count)>0),"merchant really stocks book")
				for drop in Story.skill_book_drops(o,EditionRules.ITEMS,job):
					expect(EditionRules.ITEMS[drop.book].skill_book==o.skills_by_job[job],"drop book matches required profession skill")
					var monster: Dictionary=EditionRegion.data().monsters[drop.monster]
					expect(monster.enabled and monster.drops.any(func(row):return row.name==drop.name and str(row.prob)==drop.prob),"drop probability comes from enabled monster table")
					for mid in drop.maps:
						expect(EditionRegion.data().populations[mid].any(func(row):return EditionRegion.data().spawns[int(row[0])].name==drop.monster),"drop source actually populated in map")
				for source in sources:
					var skill: String=EditionRules.ITEMS[source.book].skill_book
					expect(EditionSkills.DEFINITIONS[skill].job==job,"source only grants current profession book")
					if o.has("skills_by_job"):expect(skill==o.skills_by_job[job],"source matches exact required skill")
					var done: Dictionary=app.rules.state.duplicate(true);done.quests[source.quest]="done"
					expect(Story.skill_book_sources(done,o,EditionRules.ITEMS,job).any(func(row):return row.quest==source.quest and "不会重复" in row.status),"completed source says no duplicate reward")
		var required: Dictionary=Story.quest("story_field_book").objectives[0]
		var required_skill: String=required.skills_by_job[job]
		var book_id:=""
		for item_id in EditionRules.ITEMS:
			if EditionRules.ITEMS[item_id].get("skill_book","")==required_skill:book_id=item_id;break
		var guide_state: Dictionary=app.rules.state.duplicate(true);guide_state.skills={};guide_state.inventory={};guide_state.warehouse={};guide_state.level=1
		expect("尚无对应技能书" in Story.skill_brief(guide_state,required,job),"missing book guidance")
		guide_state.warehouse[book_id]=1
		expect("先取回背包" in Story.skill_brief(guide_state,required,job),"stored book must be retrieved")
		guide_state.inventory[book_id]=1
		var guidance:=Story.skill_brief(guide_state,required,job)
		expect("背包 1 · 仓库 1" in guidance and "不会替你自动学习" in guidance and "还需提升" in guidance,"owned book and level gap are explicit")
		guide_state.skills[required_skill]={"rank":1,"proficiency":0}
		expect(Story.skill_brief(guide_state,required,job).begins_with("已学会") and not "还需提升" in Story.skill_brief(guide_state,required,job),"learned skill no longer requests book")
		app.windows.close_all();app.show_story();await settle()
		var view=app.form.get_child(1);view.selected="story_field_book";view.refresh();await settle()
		var link=find_button(view,"查看领书委托：书页与行装")
		expect(link!=null,"mouse detail exposes entry book route")
		var sellers: Array=Story.skill_book_merchants(app.rules.state,Story.quest("story_field_book").objectives[0],EditionRules.ITEMS,job)
		expect(not sellers.is_empty(),"entry book has actual merchant fallback")
		if not sellers.is_empty():
			var merchant: Dictionary=sellers[0]
			var label: String="寻找书商："+str(merchant.name)+" · "+str(app.resources.map_by_id.get(merchant.map,{}).get("name",merchant.map))
			expect(find_button(view,label)!=null,"merchant navigation visible in skill task detail")
		var funded: Dictionary=app.rules.state.duplicate(true);funded.gold=10000;funded.level=int(EditionSkills.DEFINITIONS[required_skill].level)
		expect(app.rules.apply(funded,"live_book_budget_fixture") and app.rules.shop(book_id,1),"purchase while task detail stays open")
		await settle()
		var live_brief:=Story.skill_brief(app.rules.state,required,job)
		expect(view.details.get_children().any(func(c):return c is Label and c.text==live_brief),"mouse book quantities refresh after purchase")
		expect(app.rules.warehouse(book_id,true),"store book while detail stays open")
		await settle();live_brief=Story.skill_brief(app.rules.state,required,job)
		expect("先取回背包" in live_brief and view.details.get_children().any(func(c):return c is Label and c.text==live_brief),"mouse shows stored book without reopening")
		var before: Dictionary=app.rules.state.duplicate(true)
		if link!=null:await click(link)
		expect(view.selected=="story_apprentice_book" and app.rules.state==before,"mouse reads source without accepting or granting a book")
		app.windows.close_all();app.game_panel("手柄人物委托",Vector2(520,430))
		view=load("res://scripts/edition2011/ui/controller_npc.gd").new();app.form.add_child(view);view.setup(app,app.rules.story_npc("server:merchant:9"));await settle()
		for i in range(view.rows.size()):
			if view.rows[i].id=="story_field_book":view.cursor=i
		view.open_detail()
		expect("技能书委托：书页与行装" in view.text.text,"controller detail displays same source")
		expect("售书人物：" in view.text.text,"controller also lists merchant fallback")
		expect(app.rules.warehouse(book_id,false),"retrieve book while controller reads task")
		await settle();live_brief=Story.skill_brief(app.rules.state,required,job)
		expect(view.reading and live_brief in view.text.text,"controller refreshes retrieved book guidance")
		expect(app.rules.use_item(book_id),"learn by using actual book")
		await settle();live_brief=Story.skill_brief(app.rules.state,required,job)
		expect(view.reading and live_brief.begins_with("已学会") and live_brief in view.text.text,"controller shows learned skill without reopening")
		expect(Story.objective_text(app.rules.state,Story.quest("story_field_book"),0) in view.text.text,"controller objective count agrees with learned skill")

		var mastery: Dictionary=Story.quest("story_mastery_return")
		var objective: Dictionary=mastery.objectives.filter(func(o):return o.type=="skill")[0]
		var drop_text: String=Story.skill_drop_text(objective,EditionRules.ITEMS,job,app.resources.map_by_id)
		expect(not drop_text.is_empty() and "并非全部来源或必得奖励" in drop_text and "地面拾取" in drop_text,"advanced lost book has honest fallback")
		var before_drops: Dictionary=app.rules.state.duplicate(true)
		app.windows.close_all();app.show_story();await settle();view=app.form.get_child(1);view.selected=mastery.id;view.refresh();await settle()
		var displayed:=false
		for child in view.details.get_children():
			if child is Label and child.text==drop_text:displayed=true
		expect(displayed,"mouse skill details show actual drop fallback")
		app.windows.close_all();app.game_panel("手柄人物委托",Vector2(520,430));view=load("res://scripts/edition2011/ui/controller_npc.gd").new();app.form.add_child(view);view.setup(app,app.rules.story_npc(mastery.start_npc));await settle()
		for i in range(view.rows.size()):
			if view.rows[i].id==mastery.id:view.cursor=i
		view.open_detail();expect(drop_text in view.text.text,"controller shows identical drop guidance")
		expect(app.rules.state==before_drops,"viewing drop guidance never grants book or skill")
	var report:={"checks":checks,"failures":failures,"scope":"all authored skill objectives for three professions, mouse source navigation and controller text; learning rules tested separately"}
	FileAccess.open("res://../artifacts/world-story/book-source-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
