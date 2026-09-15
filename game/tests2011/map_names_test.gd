extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(4):await process_frame
func search(value: String) -> void:
	app.fields.filter.clear();app.fields.filter.grab_focus()
	for character in value:
		var key:=InputEventKey.new();key.pressed=true;key.unicode=character.unicode_at(0);root.push_input(key,true)
	await settle()
func buttons(node: Node) -> Array:
	var list: Array=[]
	for c in node.get_children():
		if c is BaseButton:list.append(c)
		list.append_array(buttons(c))
	return list
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-mapnames-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	var ids: Dictionary={};var names: Dictionary={};var count:=0
	for map in app.resources.maps:
		expect(not map.name.is_empty() and not map.name.begins_with("探索区域") and map.name!=map.id,"readable map name "+map.id)
		expect(not names.has(map.name) and not ids.has(map.id),"map labels and IDs distinguish every destination")
		expect(map.name==app.resources.world_catalog[map.id].name,"resource and content catalog agree")
		names[map.name]=true;ids[map.id]=true
		if app.resources.map_names[map.id].reconstructed:count+=1;expect(map.name.ends_with("（重建）"),"unverified historical names explicitly marked")
	expect(ids.size()==707 and count==374,"complete naming coverage and provenance counts")
	expect(app.resources.map_by_id["1"].name=="沃玛森林" and app.resources.map_by_id["d001"].name=="兽人古墓一层","reference IDs use source names")
	app.start_character({"id":"mapnames","name":"地图旅人","job":"战士","gender":"男"});app.world.paused=true
	app._process(0.016);expect(app.status.text.contains("边界村") and not app.status.text.contains("[289,618]"),"HUD shows village name without coordinates")
	app.show_travel();await settle()
	var destinations:=buttons(app.form).filter(func(b):return b.text in names)
	expect(destinations.size()==707,"travel list contains every named map")
	await search("沃玛森林")
	destinations=buttons(app.form).filter(func(b):return b.text in names)
	expect(destinations.any(func(b):return b.text=="沃玛森林"),"search accepts Chinese map name")
	await search("b101")
	destinations=buttons(app.form).filter(func(b):return b.text in names)
	expect(destinations.size()==1 and destinations[0].text==app.resources.map_by_id.b101.name,"legacy ID search still displays proper name")
	app.windows.close_all();app.enter_map("1");app._process(0.016)
	expect(app.world.zone_name()=="沃玛森林" and app.status.text.contains("沃玛森林") and not app.status.text.contains("["),"entered map uses proper name in HUD")
	expect(app.save_world() and app.rules.state.map=="1","save keeps stable map ID")
	app.rules.quest("1");app.show_quests();await settle()
	var quest=app.form.get_children().filter(func(c):return c.get_script()!=null and c.get_script().resource_path.ends_with("quest_panel.gd"))[0]
	quest.selected=4;quest.refresh();await settle()
	var text:=""
	for child in quest.content.get_children():
		if child is Label:text+=child.text
	expect(text.contains("沃玛森林 · 铁矿委托") and not text.contains("ore:1"),"regional quest displays map name, not storage key")
	expect(app.resources.errors.is_empty(),"no resource errors")
	var result:={"checks":checks,"failures":failures};print(JSON.stringify(result));FileAccess.open("res://../artifacts/map-names-0.9.2/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
