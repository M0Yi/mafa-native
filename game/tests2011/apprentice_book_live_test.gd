extends SceneTree
var app
var checks:=0
var failures: Array=[]
var frames:=0
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func walk() -> void:
	for i in range(60*120):
		app._process(1.0/60);frames+=1
		if app.rules.state.hp<=0:break
		if app.world.player.route.is_empty() and app.world.player.progress>=1:break
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/apprentice-book-live-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false)
	var q: Dictionary=EditionRules.Story.quest("story_apprentice_book")
	var bookseller: Dictionary=app.rules.story_npc(q.start_npc)
	var smith: Dictionary=app.rules.story_npc("server:merchant:12")
	for job in ["战士","法师","道士"]:
		app.start_character({"id":"apprentice-"+job,"name":"书页行装","job":job,"gender":"男"});app.world.hide()
		app.enter_map(bookseller.map,Vector2i(bookseller.cell[0]+1,bookseller.cell[1]));app.world.paused=false
		var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_letter="done"
		expect(app.rules.apply(prepared,"prior_letter_fixture"),"prepare previous delivery")
		expect(app.rules.story_action(q.id,"accept",bookseller.id,bookseller.map,app.world.player.cell),"accept book errand at bookseller")
		app.approach_story_npc(smith.id);walk()
		expect(app.rules.story_near(smith.id,app.world.metadata.id,app.world.player.cell),"walk to smith")
		app.interact(smith);app.windows.close_all()
		expect(EditionRules.Story.ready(app.rules.state,q),"actual smith conversation meets objective")
		app.approach_story_npc(bookseller.id);walk()
		expect(app.rules.story_near(bookseller.id,app.world.metadata.id,app.world.player.cell),"walk back to bookseller")
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",bookseller.id,bookseller.map,app.world.player.cell) and app.rules.state==before,"failed delivery keeps completed conversation and gives no book")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(q.id,"submit",bookseller.id,bookseller.map,app.world.player.cell),"deliver book errand")
		var book: String=q.rewards.books_by_job[job]
		expect(app.rules.state.inventory.get(book,0)==1 and app.rules.state.skills==before.skills,"correct book awarded without automatic learning")
		var awarded: Dictionary=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",bookseller.id,bookseller.map,app.world.player.cell) and app.rules.state==awarded,"repeat delivery cannot duplicate book")
		expect(not app.gameplay.use_type(book) and app.rules.state==awarded,"under-level reading preserves skill book")
		expect(app.store.load_world(app.rules.character.id).inventory.get(book,0)==1,"earned book saved")
	var report:={"checks":checks,"failures":failures,"simulated_seconds":frames/60.0,"scope":"three jobs walk bookseller-smith-return under main loop and interact, transactional book rewards and under-level use; initial bookseller location and prior letter fixtures, no natural leveling or physical input"}
	FileAccess.open("res://../artifacts/world-story/apprentice-book-live-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free()
	for i in range(8):await process_frame
	quit(0 if failures.is_empty() else 1)
