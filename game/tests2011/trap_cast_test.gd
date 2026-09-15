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
var sounds: Array=[]
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/trap-cast-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"cast","name":"困魔施法","job":"道士","gender":"男"});app.world.hide();app.enter_map("1",Vector2i(300,299));app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.level=27;next.mp=100;next.gold=1200000;next.map=app.world.metadata.id;next.cell=[app.world.player.cell.x,app.world.player.cell.y]
	expect(app.rules.apply(next,"trap_purchase_funds_fixture"),"prepare funds and level")
	var shop: Dictionary=app.rules.story_npc("server:merchant:109")
	expect(preload("res://scripts/edition2011/mystery_books.gd").purchase(app.rules,shop.map,Vector2i(shop.cell[0],shop.cell[1])),"buy actual trap book")
	var book: Dictionary={}
	for item in app.rules.state.items:
		if item.type=="ref:149":book=item;break
	expect(not book.is_empty() and not app.rules.state.skills.has("trap"),"book purchase does not teach")
	expect(not app.rules.learn_book(book),"level 27 cannot consume book")
	next=app.rules.state.duplicate(true);next.level=28
	expect(app.rules.apply(next,"level28_fixture"),"reach learning level")
	var unlearned: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.rules.learn_book(book) and app.rules.state==unlearned,"failed learning retains book")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.rules.learn_book(book),"learn using purchased book")
	expect(app.rules.state.skills.has("trap") and int(app.rules.state.inventory.get("ref:149",0))==0,"learning consumes exactly one book")
	expect("trap" in app.rules.state.skill_keys.values(),"learned control mapped to available shortcut")
	app.start_character(app.rules.character.duplicate(true));app.world.hide();app.world.paused=false
	expect(app.rules.state.skills.has("trap"),"learned control survives reload")
	app.sound_started.connect(func(id):sounds.append(id))
	var monster: Dictionary=EditionRegion.entity_from({"runtime_id":"trap:deer","name":"鹿","interval":10},EditionRegion.data().monsters["鹿"],"trap:deer",-1,app.world.player.cell+Vector2i(2,0),0)
	app.world.entities=[monster];app.selected=monster
	var before: Dictionary=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.gameplay.cast("trap") and app.rules.state==before and app.pending_attack.is_empty(),"failed cast does not charge or schedule control")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.gameplay.cast("trap"),"cast control spell")
	expect(sounds.count(10160)==1,"cast sound uses original index once")
	expect(app.rules.state.mp==90 and not monster.has("trap_status"),"cost once, effect waits for hit")
	app.elapsed+=0.3;app.resolve_attack()
	expect(monster.has("trap_status") and monster.hp==25,"control hit causes no minimum-one damage")
	expect(sounds.count(10162)==1 and sounds.count(10161)==0,"hit audio once, intentionally empty travel stage silent")
	var expiry: float=monster.get("trap_status",{}).get("expires",0)
	app.resolve_attack()
	expect(float(monster.get("trap_status",{}).get("expires",0))==expiry and app.rules.state.mp==90,"resolved hit does not repeat")
	app.world.elapsed=app.elapsed
	var controlled_state: Dictionary=app.rules.state.duplicate(true)
	app.store.db.query("PRAGMA query_only=ON;")
	expect(not app.save_world() and app.rules.state==controlled_state,"failed save preserves database state")
	app.store.db.query("PRAGMA query_only=OFF;")
	expect(app.save_world(),"save active control with world clock")
	var loaded: Dictionary=app.store.load_world(app.rules.character.id)
	var clone:=monster.duplicate(true);clone.erase("trap_status")
	expect(preload("res://scripts/edition2011/trap_status.gd").restore(clone,loaded.trapped_monsters[monster.id],loaded.time),"SQLite snapshot restores control")
	expect(clone.trap_status.expires==expiry,"save does not renew duration")
	monster.erase("trap_status")
	expect(app.save_world() and app.store.load_world(app.rules.character.id).get("trapped_monsters",{}).is_empty(),"next save removes obsolete control records")
	app.fight_timer=0;app.elapsed+=6
	expect(app.gameplay.cast("trap"),"second cast after cooldown")
	monster.generation+=1;app.elapsed+=0.3;app.resolve_attack()
	expect(not monster.has("trap_status"),"new monster life ignores stale hit")
	app.fight_timer=0;app.elapsed+=6;monster.catalog_group="boss_elite";before=app.rules.state.duplicate(true)
	expect(not app.gameplay.cast("trap") and app.rules.state==before,"immune boss excluded before mana debit")
	var report:={"checks":checks,"failures":failures,"scope":"actual cast and hit resolution, mana debit SQLite failure, generation and boss checks; purchase NPC position, funds, level progression, monster and times fixtures; actual book learning and sound_started events; SQLite control snapshot save/restore helper; no physical input or natural population reload verification"}
	FileAccess.open("res://../artifacts/world-story/trap-cast-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
