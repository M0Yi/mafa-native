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
	for i in range(6):await process_frame
func click(button: Button) -> void:
	var ancestor: Node=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle()
	var e:=InputEventMouseButton.new();e.position=button.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
	e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
func find_button(text: String) -> Button:
	for button in app.panel.navigation_buttons(app.panel.body):
		if button.text==text:return button
	return null
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/palace-guild-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"guildfounder","name":"王城旅人","gender":"男","job":"战士"})
	var before: Dictionary=app.rules.state.duplicate(true)
	for title in [" ","甲","一二三四五六七八九十一二三","甲\n乙"]:
		expect(not app.rules.create_guild(title,"云游客") and app.rules.state==before,"invalid title cannot create guild")
	expect(not app.rules.create_guild("海风旅人","不存在的旅人") and app.rules.state==before,"invalid cofounder rejected")
	var npc: Dictionary=app.rules.story_npc("server:npc:0")
	app.enter_map("0122",Vector2i(29,33));app.world.paused=false;app.save_world();app.show_reference_npc(npc);await settle()
	var open:=find_button("本地行会登记")
	expect(open!=null,"king exposes local registration")
	app.windows.close_all()
	var prepared: Dictionary=app.rules.state.duplicate(true);prepared.quests.story_traveler_guild="accepted"
	expect(app.rules.apply(prepared,"accepted_guild_task_fixture"),"prepare accepted guild task")
	app.show_story();await settle()
	var view=app.form.get_child(1);view.selected="story_traveler_guild";view.refresh();await settle()
	open=null
	for child in view.details.get_children():
		if child is Button and child.text=="前往国王命名登记":open=child;break
	expect(open!=null,"guild task offers named palace registration")
	if open!=null:await click(open)
	expect(app.windows.order.back()=="本地行会登记","mouse opens registration")
	var title: LineEdit=app.fields.local_guild_name;title.text="海风旅人"
	var submit:=find_button("确认登记");expect(submit!=null,"registration has confirm action")
	before=app.rules.state.duplicate(true);app.world.player.reset(Vector2i(20,20))
	if submit!=null:await click(submit)
	expect(app.rules.state==before and title.text=="海风旅人","moving away rejects submission and preserves typed name")
	app.world.player.reset(Vector2i(29,33));app.world.paused=true
	if submit!=null:await click(submit)
	expect(app.rules.state==before,"pause refuses registration")
	app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;")
	if submit!=null:await click(submit)
	expect(app.rules.state==before and title.text=="海风旅人","save failure leaves form retryable")
	app.store.db.query("PRAGMA query_only=OFF;")
	if submit!=null:await click(submit)
	expect(app.rules.state.guild.get("name","")=="海风旅人","mouse commits chosen name")
	expect(Story.ready(app.rules.state,Story.quest("story_traveler_guild")) and app.rules.state.quests.story_traveler_guild=="accepted","named registration satisfies membership without automatically claiming task")
	expect("云游客" in app.rules.state.guild.get("members",[]) and "王城旅人" in app.rules.state.guild.get("members",[]),"founders are members")
	expect(app.rules.state.gold==before.gold,"local registration preserves existing free rule")
	expect(app.store.load_world(app.rules.character.id).guild.get("name","")=="海风旅人","chosen name persists")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.create_guild("另一个名称","青禾") and app.rules.state==before,"repeat registration cannot replace guild")
	app.show_palace_guild(npc);await settle()
	expect(find_button("确认登记")==null and find_button("查看本地成员与物资")!=null,"existing guild shows management instead of creation")
	var report:={"checks":checks,"failures":failures,"scope":"guild task to local palace registration via viewport mouse, name/companion validation, distance/pause/write failure and persistence; typed text and initial position fixtures, not IME or original guild war acceptance"}
	FileAccess.open("res://../artifacts/world-story/palace-guild-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
