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
	root.size=Vector2i(1280,800)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"fire-dragon-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"fire-test","name":"神殿勘察","job":"战士","gender":"男"});app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.gold=3000;expect(app.rules.apply(next,"fixture"),"fixture")
	expect(not app.fire_dragon.buy_permit(),"cannot remotely buy permit")
	app.enter_map("3",Vector2i(338,333))
	expect(Rect2(app.world.camera,app.world.view_size/float(app.world.zoom)).has_point(app.world.player.anchor),"map entry camera contains landing before next update")
	expect(app.fire_dragon.near(EditionFireDragon.ENTRANCE),"reference NPC reachable")
	expect(not app.fire_dragon.enter(),"no permit refuses entry")
	var tracked: Dictionary=app.rules.state.duplicate(true);tracked.quests.story_dragon_survey="accepted";tracked.tracked_story="story_dragon_survey"
	expect(app.rules.apply(tracked,"survey_tracking_fixture"),"track accepted survey")
	var before_route: Dictionary=app.rules.state.duplicate(true)
	app.navigate_tracked_quest();await settle()
	expect(app.windows.windows.has("火龙神殿入口") and app.rules.state==before_route,"outside tracking explains paid entrance without changing state")
	app.windows.close_all()

	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.fire_dragon.buy_permit() and app.rules.state.gold==3000,"failed purchase retains gold")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.fire_dragon.buy_permit(),"buy permit")
	expect(app.rules.state.gold==2500 and app.fire_dragon.state().permits==1,"single purchase debit")
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.fire_dragon.enter(),"entry commit failure rejected")
	expect(app.world.metadata.id=="3" and app.fire_dragon.state().permits==1,"entry rollback keeps location and permit")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.fire_dragon.enter(),"permit entry succeeds")
	expect(app.world.player.cell==EditionFireDragon.LANDING and app.world.navigation.mobile(app.world.player.cell),"landing mobile")
	expect(not app.world.navigation.walkable(EditionFireDragon.GUARD_CELL),"guide has collision")
	for index in range(900,904):
		var frame: Dictionary=app.resources.frame("npc",index)
		expect(not frame.is_empty() and frame.size.x>1 and frame.size.y>1,"guide idle frame is not a transparent placeholder")
	expect(not app.world.navigation.path(app.world.player.cell,EditionFireDragon.SURVEY).is_empty(),"central chamber reachable after NPC collision")
	expect(app.fire_dragon.state().permits==0 and app.fire_dragon.state().active,"entry consumes once")
	expect(not app.fire_dragon.enter(),"double entry rejected")
	before_route=app.rules.state.duplicate(true);app.world.paused=true;app.navigate_tracked_quest()
	expect(app.world.player.route.is_empty() and app.rules.state==before_route,"paused survey tracking cannot move or complete")
	app.world.paused=false;app.navigate_tracked_quest()
	expect(not app.world.player.route.is_empty() and app.world.player.route.back()==EditionFireDragon.SURVEY,"inside tracking paths to actual survey point")
	expect(app.rules.state==before_route and not app.fire_dragon.state().get("surveyed",false),"planning does not grant survey completion")

	var saved: Dictionary=app.store.load_world("fire-test")
	expect(saved.map==EditionFireDragon.MAP and saved.fire_dragon.active,"entry persists together with location")
	for frame in range(12000):
		app.world.player.update(1.0/60,Vector2i.ZERO,false)
		if (app.world.player.cell-EditionFireDragon.SURVEY).length()<=2:break
		app.fire_dragon.update()
	expect(app.world.player.completed_steps>0 and (app.world.player.cell-EditionFireDragon.SURVEY).length()<=2,"tracked route walks from landing into survey radius")
	expect(not app.fire_dragon.state().get("surveyed",false),"approach outside radius never completes survey")
	var survey_before: Dictionary=app.rules.state.duplicate(true)
	app.world.paused=true;app.fire_dragon.update()
	expect(app.rules.state==survey_before,"paused at survey point cannot complete")
	app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;");app.fire_dragon.update()
	expect(app.rules.state==survey_before and not app.store.load_world("fire-test").fire_dragon.get("surveyed",false),"failed survey write leaves memory and disk incomplete")
	app.store.db.query("PRAGMA query_only=OFF;");app.fire_dragon.update()
	expect(app.fire_dragon.state().surveyed and app.store.load_world("fire-test").fire_dragon.surveyed,"central visit retries and persists")
	expect(EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_dragon_survey")),"actual central visit satisfies tracked story")
	var surveyed: Dictionary=app.rules.state.duplicate(true);app.fire_dragon.update()
	expect(app.rules.state==surveyed,"remaining in survey radius does not commit twice")
	expect(not app.fire_dragon.claim(),"cannot claim from inside chamber")
	app.world.paused=true;var time: float=app.elapsed;app._process(10);expect(app.elapsed==time,"pause freezes expedition clock");app.world.paused=false
	expect(app.world.player.go_to(EditionFireDragon.LANDING),"return route to guide exists")
	for frame in range(12000):
		app.world.player.update(1.0/60,Vector2i.ZERO,false)
		if app.world.player.route.is_empty() and app.world.player.progress>=1.0:break
	expect(app.world.player.cell==EditionFireDragon.LANDING and app.fire_dragon.near(EditionFireDragon.GUARD),"walk back reaches guide without overlapping NPC")
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.fire_dragon.leave(),"return commit failure rejected")
	expect(app.world.metadata.id==EditionFireDragon.MAP and app.fire_dragon.state().active,"return rollback keeps expedition")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.fire_dragon.leave(),"guide returns to Mengzhong")
	expect(EditionRegion.safe("3",app.world.player.cell),"return in reference safe zone")
	app.world.player.reset(Vector2i(338,333));var gold: int=app.rules.state.gold
	expect(app.fire_dragon.claim(),"first survey reward succeeds")
	expect(app.rules.state.gold==gold+500 and not app.fire_dragon.claim(),"reward cannot duplicate")
	expect(app.fire_dragon.buy_permit() and app.fire_dragon.enter(),"repeat trip supported")
	expect(app.fire_dragon.time_text()=="神殿剩余 20:00","visible timer starts with paid session")
	app.elapsed=float(app.fire_dragon.state().deadline)-60.0
	var before_warning: Dictionary=app.rules.state.duplicate(true)
	app.world.paused=true;var chat_count: int=app.chat_history.size();app.fire_dragon.update()
	expect(app.chat_history.size()==chat_count and app.fire_dragon.time_text()=="神殿剩余 01:00","paused timer has no warning side effect")
	app._process(0)
	expect("神殿剩余 01:00" in app.status.text,"main status displays active countdown")
	await settle()
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://../artifacts/fire-dragon-190/countdown.png")
	app.world.paused=false;app.fire_dragon.update()
	expect("不足一分钟" in app.pending_message and app.chat_history.size()==chat_count+1,"one-minute warning reaches chat")
	app.fire_dragon.update()
	expect(app.chat_history.size()==chat_count+1 and app.rules.state==before_warning,"warning does not repeat or mutate persistence")
	app.elapsed=float(app.fire_dragon.state().deadline)-0.2
	expect(app.fire_dragon.time_text()=="神殿剩余 00:01","fractional final second stays visible")
	app.elapsed=float(app.fire_dragon.state().deadline);app.fire_dragon.update()
	expect(app.world.metadata.id=="3" and not app.fire_dragon.state().active,"timeout returns safely")
	expect(app.fire_dragon.state().claimed,"repeat trip preserves claimed reward")
	expect(app.fire_dragon.time_text().is_empty(),"timer disappears outside active temple session")
	app.enter_map(EditionFireDragon.MAP,EditionFireDragon.SURVEY);app.world.entities=[];await settle()
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://../artifacts/fire-dragon-190/chamber.png")
	expect(app.resources.errors.is_empty(),"visible chamber has no resource errors")
	var report:={"scope":"paid entry, tracked player movement to survey and guide, pause and write-failure retry; story acceptance fixture, actors and expedition clock not advanced during walking, no hardware input", "checks":checks,"failures":failures,"resource_errors":app.resources.errors}
	FileAccess.open("res://../artifacts/fire-dragon-190/entry-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
