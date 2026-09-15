extends SceneTree

var failures: Array=[]
var checks:=0
var location:=""
func expect(value: bool,description: String) -> void:
	checks+=1
	if not value:failures.append(description);printerr("FAIL: ",description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	location=OS.get_environment("TMPDIR")+"mafa2011-tests-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	var store:=EditionStore.new();store.path=location
	expect(store.open(),"open isolated database")
	var rules:=EditionRules.new();rules.store=store
	var profile={"id":"test-character","name":"测试者","job":"战士","gender":"男"}
	expect(rules.attach(profile),"create world")
	var malformed:=rules.state.duplicate(true);malformed.inventory.potion={"bad":true}
	expect(not rules.valid(malformed),"reject malformed inventory without crashing")
	var before:=JSON.stringify(rules.state)
	expect(not rules.shop("sword",99),"reject unaffordable purchase")
	expect(JSON.stringify(rules.state)==before,"failed purchase leaves state unchanged")
	expect(JSON.parse_string(JSON.stringify(store.load_world(profile.id)))==JSON.parse_string(before),"failed purchase leaves disk unchanged")
	expect(rules.shop("sword",1),"buy sword")
	expect(rules.use_item("sword"),"equip sword")
	expect(rules.state.equipment.weapon=="sword" and rules.attack()>7,"equipped weapon affects damage")
	var potions:=int(rules.state.inventory.potion)
	expect(rules.warehouse("potion",true),"deposit potion")
	expect(rules.state.inventory.potion==potions-1 and rules.state.warehouse.potion==1,"deposit conserves quantity")
	expect(rules.warehouse("potion",false),"withdraw potion")
	expect(rules.state.inventory.potion==potions and not rules.state.warehouse.has("potion"),"withdraw conserves quantity")
	before=JSON.stringify(rules.state)
	expect(not rules.warehouse("potion",false),"reject empty withdrawal")
	expect(JSON.stringify(rules.state)==before,"empty withdrawal is atomic")
	expect(rules.quest("0"),"accept quest")
	before=JSON.stringify(rules.state)
	expect(not rules.quest("0"),"reject quest without materials")
	expect(JSON.stringify(rules.state)==before,"failed quest keeps status and currency")
	expect(rules.shop("ore",3),"buy quest materials")
	expect(rules.quest("0"),"complete quest")
	before=JSON.stringify(rules.state)
	expect(not rules.quest("0"),"reject duplicate quest reward")
	expect(JSON.stringify(rules.state)==before,"duplicate quest preserves state")
	var copy:=rules.state.duplicate(true)
	expect(store.commit(profile.id,copy,"idempotency","single-operation"),"first operation commits")
	var revision:=int(copy.revision)
	expect(not store.commit(profile.id,copy,"idempotency","single-operation"),"duplicate operation rejected")
	expect(copy.revision==revision,"failed commit does not increment caller revision")
	expect(not store.commit(profile.id,rules.state,"stale"),"stale revision rejected")
	expect(rules.attach(profile),"reload clears stale error")
	expect(store.load_world(profile.id).revision==revision,"rollback preserves committed revision")
	expect(store.backup(),"SQLite backup creates consistent snapshot")
	store.close()
	var corrupt:=FileAccess.open(location,FileAccess.WRITE);corrupt.store_string("deliberate test corruption");corrupt.close()
	expect(store.open(),"damaged primary restores valid backup")
	expect(not store.warning.is_empty(),"restoration reports retained corrupt file")
	expect(store.load_world(profile.id).revision==revision,"restored backup contains committed revision")
	store.close()
	var second:=EditionStore.new();second.path=location+".future.sqlite";expect(second.open(),"create future version test")
	expect(second.put_metadata("schema_version","999"),"set future version")
	second.close();expect(not second.open(),"future schema rejected")
	second.close()
	# Verify unchanged marker with an independent read-only connection.
	var db:=SQLite.new();db.path=location+".future.sqlite";db.verbosity_level=0;db.open_db()
	db.query("SELECT value FROM metadata WHERE key='schema_version';")
	expect(db.query_result[0].value=="999","future schema never rewritten")
	db.close_db();db=null
	var nav:=ClassicNavigation.new();nav.configure({"size":[3,3],"walkable":[[1,0,1],[0,1,1],[1,1,1]]})
	expect(not nav.can_step(Vector2i(0,0),Vector2i(1,1)),"no diagonal corner cutting")
	expect(nav.path(Vector2i(0,0),Vector2i(1,1)).is_empty(),"path does not bypass closed corner")
	expect(not nav.walkable(Vector2i(-1,0)),"map boundary rejects movement")
	print(JSON.stringify({"checks":checks,"failures":failures,"isolated_database":location}))
	quit(0 if failures.is_empty() else 1)
