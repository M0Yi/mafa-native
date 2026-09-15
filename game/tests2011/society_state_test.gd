extends SceneTree
const Guard=preload("res://scripts/edition2011/society_state.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	expect(Guard.valid({},EditionRules.ITEMS),"legacy absent social fields supported")
	for value in [null,[],"wrong",{"x":null},{"x":{"hp":-1,"generation":0,"respawn":0}},{"x":{"hp":250.5,"generation":0,"respawn":0}},{"x":{"hp":100,"generation":"0","respawn":0}},{"x":{"hp":100,"generation":0,"respawn":INF}}]:
		expect(not Guard.valid({"traveler_health":value},EditionRules.ITEMS),"invalid health rejected")
	for guild in [{"members":"云游客"},{"members":[null]},{"contribution":-1},{"contribution":0.5},{"supplies":[]},{"supplies":{"unknown":1}},{"supplies":{"potion":-1}},{"aid_log":[null]},{"aid_log":[{"member":"云游客"}]}]:
		expect(not Guard.valid({"guild":guild},EditionRules.ITEMS),"invalid guild state rejected")
	expect(Guard.valid({"guild":{"name":"旧行会"}},EditionRules.ITEMS),"legacy name-only record remains readable")
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/society-state-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var profile: Dictionary={"id":"state","name":"状态校验","gender":"男","job":"战士"};app.start_character(profile)
	var legacy: Dictionary=app.rules.state.duplicate(true);legacy.guild={"name":"旧行会"};app.rules.apply(legacy,"legacy_guild_fixture")
	expect(app.rules.social("guild_member","云游客") and "云游客" in app.rules.state.guild.members,"legacy guild can invite its first recorded member")
	var next: Dictionary=app.rules.state.duplicate(true);next.guild={"supplies":"broken"}
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.apply(next,"invalid_operation") and app.rules.state==before,"invalid operation cannot commit")
	expect(app.store.commit(profile.id,next,"corrupt_fixture"),"save corruption fixture written outside rule layer")
	expect(not app.rules.attach(profile) and "原数据库" in app.rules.message,"corrupt save attach refused explicitly")
	expect(app.store.load_world(profile.id).guild.supplies=="broken","original corrupt data retained without rebuild")
	var report:={"checks":checks,"failures":failures,"scope":"social field shape/ranges, legacy optional fields, actual corrupt save attach and original data preservation; does not simulate disk damage"}
	FileAccess.open("res://../artifacts/world-story/society-state-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
