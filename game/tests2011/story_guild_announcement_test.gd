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
func editor_field() -> TextEdit:
	for child in app.form.get_children():
		if child is TextEdit:return child
	return null
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/guild-announcement-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"notice","name":"公告旅人","gender":"男","job":"战士"});app.world.paused=false
	var before: Dictionary=app.rules.state.duplicate(true)
	expect(not app.rules.set_guild_announcement("集合") and app.rules.state==before,"no guild rejected")
	expect(app.rules.create_guild("海风旅人","云游客"),"create local guild")
	before=app.rules.state.duplicate(true)
	for text in [" ","字".repeat(201),"集合\t出发","集合"+String.chr(127)]:
		expect(not app.rules.set_guild_announcement(text) and app.rules.state==before,"invalid announcement rejected")
	app.show_social();await settle()
	await click(find_button("编辑行会公告"))
	var editor:=editor_field();expect(editor!=null and editor.text.is_empty(),"old guild opens empty editor")
	editor.text="比奇城集合\n带好红药，再出发。";editor.grab_focus();await settle()
	expect(app.typing(),"multiline focus blocks gameplay typing shortcuts")
	for key in [JOY_BUTTON_A,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:
		var pad:=InputEventJoypadButton.new();pad.pressed=true;pad.button_index=key;app.panel._input(pad)
		expect(app.rules.state==before and editor.has_focus() and app.windows.windows.has("行会公告"),"joypad does not submit or move focus while editing")
	var save:=find_button("保存公告");app.world.paused=true
	await click(save);expect(app.rules.state==before and editor.text.contains("比奇"),"pause preserves draft and state")
	app.world.paused=false;app.store.db.query("PRAGMA query_only=ON;")
	await click(save);expect(app.rules.state==before and editor.text.contains("比奇"),"failed save preserves draft and state")
	app.store.db.query("PRAGMA query_only=OFF;");await click(save)
	expect(app.rules.state.guild.get("announcement","")=="比奇城集合\n带好红药，再出发。","mouse saves multiline announcement")
	expect(not "行会公告" in app.windows.order and app.windows.order.back()=="玛法旅人","save closes editor and returns to members")
	var expected: Dictionary=before.duplicate(true);expected.guild.announcement="比奇城集合\n带好红药，再出发。"
	expected.revision=int(before.revision)+1
	expect(app.rules.state==expected,"announcement changes only text and one commit revision")
	var saved: Dictionary=app.store.load_world(app.rules.character.id).guild
	expect(saved.get("announcement","")==app.rules.state.guild.announcement and saved.members==app.rules.state.guild.members and saved.name==app.rules.state.guild.name and int(saved.contribution)==int(app.rules.state.guild.contribution),"announcement and membership persist through JSON numeric conversion")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.set_guild_announcement(before.guild.announcement) and app.rules.state==before,"unchanged submission has no effect")
	await click(find_button("编辑行会公告"));editor=editor_field()
	expect(editor.text==before.guild.announcement,"reopen restores saved text")
	editor.text="不要保存的草稿";await click(find_button("取消"))
	expect(app.rules.state==before and not "行会公告" in app.windows.order,"cancel discards draft only")
	await click(find_button("编辑行会公告"));editor=editor_field();editor.text="手柄返回未保存草稿";editor.grab_focus();await settle()
	var back:=InputEventJoypadButton.new();back.pressed=true;back.button_index=JOY_BUTTON_B;root.push_input(back,true)
	back=back.duplicate();back.pressed=false;root.push_input(back,true);await settle()
	expect(app.rules.state==before and not app.windows.windows.has("行会公告"),"joypad B closes focused editor without saving draft")
	var next: Dictionary=before.duplicate(true);next.hp=0;expect(app.rules.apply(next,"death_fixture"),"prepare death")
	before=app.rules.state.duplicate(true)
	expect(not app.rules.set_guild_announcement("死亡时修改") and app.rules.state==before,"dead character cannot edit")
	var report:={"checks":checks,"failures":failures,"scope":"viewport mouse edit/save/cancel at 800x600, validation, pause/death, read-only rollback, persistence; typed text and death fixtures, not IME/controller or siege verification"}
	FileAccess.open("res://../artifacts/world-story/guild-announcement-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	if failures.is_empty():print("PASS: guild announcement regression completed")
	var path: String=app.store.path
	app.queue_free();await settle()
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit(0 if failures.is_empty() else 1)
