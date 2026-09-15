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
func talk(id: String) -> void:
	var npc: Dictionary=app.rules.story_npc(id)
	app.rules.story_talk(id,npc.map,Vector2i(npc.cell[0],npc.cell[1]))
func run() -> void:
	var Clues=preload("res://scripts/edition2011/bagua_clues.gd")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/bagua-clues-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var npc: Dictionary=app.rules.story_npc(Clues.NPC);var at:=Vector2i(npc.cell[0],npc.cell[1])
	for job in ["战士","法师","道士"]:
		app.start_character({"id":job,"name":"阵法线索","job":job,"gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.gold=0;expect(app.rules.apply(next,"poor_fixture"),"prepare poor wallet")
		expect(not Clues.buy(app.rules,0,npc.map,at),"poor cannot buy")
		next=app.rules.state.duplicate(true);next.gold=23000;expect(app.rules.apply(next,"funds_fixture"),"prepare exact funds")
		for index in range(4):
			var before: Dictionary=app.rules.state.duplicate(true)
			expect(not Clues.buy(app.rules,index,"0",at) and app.rules.state==before,"wrong map cannot buy")
			app.store.db.query("PRAGMA query_only=ON;")
			expect(not Clues.buy(app.rules,index,npc.map,at) and app.rules.state==before,"failed write keeps money and clue")
			app.store.db.query("PRAGMA query_only=OFF;")
			expect(Clues.buy(app.rules,index,npc.map,at),"purchase next clue")
			expect(app.rules.state.gold==before.gold-Clues.COSTS[index],"exact fixed fee without preset scaling")
			before=app.rules.state.duplicate(true)
			expect(not Clues.buy(app.rules,index,npc.map,at) and app.rules.state==before,"same stage not charged twice")
			app.start_character(app.rules.character.duplicate(true));app.world.hide()
			expect(int(app.rules.state.bagua_clues)==index+1,"clue count survives reload")
		expect(app.rules.state.gold==0,"four clues total 23000")
	var report:={"checks":checks,"failures":failures,"scope":"three professions four sequential clue purchases, fixed fees, readonly failure and reload; funds/positions fixtures, no natural Q011 travel or physical input"}
	FileAccess.open("res://../artifacts/world-story/bagua-clues-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
