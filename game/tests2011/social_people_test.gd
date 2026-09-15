extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func button(title: String) -> Button:
	for control in app.panel.navigation_buttons(app.form):
		if control.text==title:return control
	return null
func press(key: int) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=key;event.pressed=true;root.push_input(event,true);await settle()
func choose(title: String) -> void:
	var wanted:=button(title);expect(wanted!=null,"button exists: "+title)
	if wanted==null:return
	for i in range(15):
		if root.gui_get_focus_owner()==wanted:break
		await press(JOY_BUTTON_DPAD_DOWN)
	expect(root.gui_get_focus_owner()==wanted,"controller selects intended operation")
	await press(JOY_BUTTON_A)
func click(control: Control) -> void:
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await settle()
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center();event.global_position=event.position;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/social-people-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"people","name":"旅人选择","gender":"男","job":"战士"});app.world.paused=false
	app.show_social();await settle();await click(button("切换旅人：云游客"))
	expect(app.social_person=="青禾","mouse cycles current traveler")
	await choose("邀请 / 离开队伍")
	expect(app.rules.state.party==["青禾"],"controller invites selected person only")
	await choose("成立行会")
	expect("青禾" in app.rules.state.guild.members and "云游客" not in app.rules.state.guild.members,"guild uses selected founder companion")
	for name in ["青禾","远山","轻舟"]:await choose("切换旅人："+name)
	expect(app.social_person=="云游客","selection cycles through all four travelers")
	await choose("邀请当前旅人加入行会")
	expect("云游客" in app.rules.state.guild.members and "青禾" in app.rules.state.guild.members,"existing guild accepts second member")
	var before: Dictionary=app.rules.state.duplicate(true);await choose("邀请当前旅人加入行会")
	expect(app.rules.state==before,"duplicate guild invitation is inert")
	expect(app.store.load_world(app.rules.character.id).guild.members==app.rules.state.guild.members,"members persisted")
	var q: Dictionary=EditionRules.Story.quest("story_companion_yuanshan")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests[q.id]="accepted";next.quests.story_traveler_friend="done";next.tracked_story=q.id;app.rules.apply(next,"tracked_companion_fixture")
	before=app.rules.state.duplicate(true)
	app.social_person="青禾";app.show_story();await settle()
	var view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
	await click(button("打开玛法旅人"))
	expect(app.social_person=="远山" and app.windows.order.back()=="玛法旅人","mouse task action selects named member")
	app.social_person="轻舟";app.navigate_tracked_quest();await settle()
	expect(app.social_person=="远山" and app.windows.order.back()=="玛法旅人","tracked relationship routes to correct member")
	expect(app.rules.state==before,"opening target controls does not alter relationships or grant progress")
	await choose("邀请 / 离开队伍")
	expect("远山" in app.rules.state.party and "轻舟" not in app.rules.state.party,"task-directed invite affects only requested traveler")
	q=EditionRules.Story.quest("story_companions_guild_roster")
	next=app.rules.state.duplicate(true);next.quests[q.id]="accepted"
	for prerequisite in q.requires:next.quests[prerequisite]="done"
	app.rules.apply(next,"roster_prerequisite_fixture")
	for i in range(3):
		app.show_story();await settle();view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
		var entries: Array=app.panel.navigation_buttons(app.form).filter(func(b):return b.text=="打开玛法旅人")
		expect(entries.size()==3,"roster has three distinct relationship controls")
		await click(entries[i]);expect(app.social_person==q.objectives[i].name,"each roster control selects its own traveler")
		if app.social_person not in app.rules.state.guild.members:await choose("邀请当前旅人加入行会")
	expect(EditionRules.Story.ready(app.rules.state,q),"three real invitations satisfy roster")
	var recipient: Dictionary=app.rules.story_npc(q.end_npc)
	expect(app.rules.story_action(q.id,"submit",recipient.id,recipient.map,Vector2i(recipient.cell[0],recipient.cell[1])),"roster submits through actual task rules")
	var report:={"checks":checks,"failures":failures,"scope":"viewport mouse traveler cycle and controller party/guild actions, alternate founder plus cloud invitation, duplicate and DB read, named-member task action and tracker routing without mutation; no remote server"}
	FileAccess.open("res://../artifacts/world-story/social-people-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
