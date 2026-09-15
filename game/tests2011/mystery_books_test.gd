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
	var Books=preload("res://scripts/edition2011/mystery_books.gd")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mystery-books-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var npc: Dictionary=app.rules.story_npc(Books.NPC);var at:=Vector2i(npc.cell[0],npc.cell[1])
	for job in Books.BOOKS:
		app.start_character({"id":job,"name":"神秘技能书","job":job,"gender":"男"});app.world.hide()
		var item: String=Books.BOOKS[job]
		var next: Dictionary=app.rules.state.duplicate(true);next.gold=0
		expect(app.rules.apply(next,"poor_fixture"),"prepare poor wallet")
		expect(not Books.purchase(app.rules,npc.map,at),"poor cannot buy")
		next=app.rules.state.duplicate(true);next.gold=Books.PRICE;next.level=100;next.inventory={"wood_sword":48};next.items=[]
		expect(app.rules.apply(next,"full_bag_fixture"),"prepare full bag")
		var before: Dictionary=app.rules.state.duplicate(true)
		expect(not Books.purchase(app.rules,npc.map,at) and app.rules.state==before,"full bag preserves money")
		next=app.rules.state.duplicate(true);app.rules.count_item(next,"wood_sword",-1)
		expect(app.rules.apply(next,"space_fixture"),"free one slot")
		before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
		expect(not Books.purchase(app.rules,npc.map,at) and app.rules.state==before,"write failure preserves money and items")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(Books.purchase(app.rules,npc.map,at),"purchase retry "+job+": "+app.rules.message)
		expect(app.rules.state.gold==0 and int(app.rules.state.inventory.get(item,0))==1,"exact profession book and fixed price")
		expect(app.rules.state.skills==before.skills,"purchase does not learn skill automatically")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(int(app.rules.state.inventory.get(item,0))==1 and app.rules.state.gold==0,"book and debit survive reload")
	var report:={"checks":checks,"failures":failures,"scope":"three profession book purchases, full bag and readonly failure, persistence; funds/position fixtures, no physical UI or learning verification"}
	FileAccess.open("res://../artifacts/world-story/mystery-books-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
