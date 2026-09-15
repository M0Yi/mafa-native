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
	app.store.path="/tmp/story-guild-ui-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"guild-ui","name":"行会操作","gender":"男","job":"战士"});app.world.paused=false
	var q: Dictionary=Story.quest("story_traveler_guild")
	var next: Dictionary=app.rules.state.duplicate(true)
	for prerequisite in q.requires:next.quests[prerequisite]="done"
	expect(app.rules.apply(next,"guild_ui_prerequisite_fixture"),"prepare prior journey")
	var npc: Dictionary=app.rules.story_npc(q.start_npc);var cell:=Vector2i(npc.cell[0],npc.cell[1])
	expect(app.rules.story_action(q.id,"accept",npc.id,npc.map,cell),"accept guild task")
	expect(not Story.ready(app.rules.state,q),"acceptance alone cannot create guild")
	app.show_social();await settle()
	var before: Dictionary=app.rules.state.duplicate(true);app.world.paused=true
	await click(find_button(app.form,"成立行会"))
	expect(app.rules.state==before,"paused mouse creation does not change state")
	app.world.paused=false;next=app.rules.state.duplicate(true);next.hp=0
	expect(app.rules.apply(next,"death_fixture"),"prepare dead state")
	before=app.rules.state.duplicate(true)
	await click(find_button(app.form,"成立行会"))
	expect(app.rules.state==before and not Story.ready(app.rules.state,q),"dead mouse creation cannot satisfy task")
	for kind in ["friends","party"]:expect(not app.rules.social(kind,"云游客") and app.rules.state==before,"dead relationship operation refused "+kind)
	next=app.rules.state.duplicate(true);next.hp=100;expect(app.rules.apply(next,"revive_fixture"),"restore test character")
	before=app.rules.state.duplicate(true);app.store.db.query("PRAGMA query_only=ON;")
	await click(find_button(app.form,"成立行会"))
	expect(app.rules.state==before and not Story.ready(app.rules.state,q),"failed creation retains incomplete task")
	app.store.db.query("PRAGMA query_only=OFF;");await click(find_button(app.form,"成立行会"))
	expect(Story.ready(app.rules.state,q) and "云游客" in app.rules.state.guild.members,"real mouse creation satisfies membership")
	before=app.rules.state.duplicate(true);await click(find_button(app.form,"成立行会"))
	expect(app.rules.state==before,"repeat creation preserves existing guild")
	expect(app.rules.story_action(q.id,"submit",npc.id,npc.map,cell),"submit after actual creation")
	expect(app.store.load_world(app.rules.character.id).quests[q.id]=="done","guild task completion persists")
	var report:={"checks":checks,"failures":failures,"scope":"native mouse guild creation, pause/death and write failure retry; prerequisite, death/revive and NPC distance are fixtures, not full social-world acceptance"}
	FileAccess.open("res://../artifacts/world-story/guild-ui-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
