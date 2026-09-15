extends SceneTree
const Craft=preload("res://scripts/edition2011/peach_crafting.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/peach-craft-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var npc: Dictionary=app.rules.story_npc(Craft.NPC);var at:=Vector2i(npc.cell[0]+1,npc.cell[1])
	for recipe in Craft.recipes():
		app.start_character({"id":recipe.product,"name":"合成验收","job":"战士","gender":"男"});app.world.hide()
		var next: Dictionary=app.rules.state.duplicate(true);next.gold=1000;next.level=60;next.quests.story_peach_witnesses="done";app.rules.count_item(next,"ref:293",1)
		for id in recipe.materials:app.rules.count_item(next,id,int(recipe.materials[id]))
		expect(app.rules.apply(next,"recipe_material_fixture"),"prepare recipe materials")
		expect(app.rules.story_action("story_peach_red_blade","accept",npc.id,npc.map,at),"accept crafting commission")
		expect(not EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_peach_red_blade")),"preowned sword does not complete crafting commission")
		var before: Dictionary=app.rules.state.duplicate(true);var revision:=int(before.revision)
		expect(not Craft.craft(app.rules,"0",at,recipe.product,revision) and app.rules.state==before,"wrong map refuses craft")
		expect(not app.rules.reference_trade(Craft.NPC,recipe.product,true,0) and app.rules.state==before,"cannot buy crafted output directly")
		expect(not Craft.craft(app.rules,npc.map,at,recipe.product,revision-1) and app.rules.state==before,"stale material confirmation refused")
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not Craft.craft(app.rules,npc.map,at,recipe.product,revision) and app.rules.state==before,"failed write preserves all materials and gold")
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(Craft.craft(app.rules,npc.map,at,recipe.product,revision),"craft recipe "+recipe.name)
		expect(int(app.rules.state.inventory.get(recipe.product,0))==int(before.inventory.get(recipe.product,0))+1 and app.rules.state.gold==before.gold-100,"one output and exact fee")
		for id in recipe.materials:expect(int(app.rules.state.inventory.get(id,0))==int(before.inventory.get(id,0))-int(recipe.materials[id]),"exact material consumption")
		expect(EditionRules.Story.ready(app.rules.state,EditionRules.Story.quest("story_peach_red_blade"))==(recipe.product=="ref:293"),"only requested successful craft advances commission")
		before=app.rules.state.duplicate(true)
		expect(not Craft.craft(app.rules,npc.map,at,recipe.product,revision) and app.rules.state==before,"duplicate confirmation cannot consume twice")
		app.start_character(app.rules.character.duplicate(true));app.world.hide()
		expect(app.rules.state.inventory.size()==before.inventory.size() and before.inventory.keys().all(func(id):return int(app.rules.state.inventory.get(id,0))==int(before.inventory[id])) and app.rules.state.gold==before.gold,"crafted output survives reload")
	var report:={"checks":checks,"failures":failures,"scope":"seven recipe rule transactions with material/level/position fixtures, rollback, stale confirmation, direct-purchase refusal and reload; no UI input or natural material acquisition"}
	FileAccess.open("res://../artifacts/world-story/peach-crafting-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
