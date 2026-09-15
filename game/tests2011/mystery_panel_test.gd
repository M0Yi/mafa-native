extends SceneTree
var app
var checks:=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func button_named(text: String) -> Button:
	for node in app.panel.find_children("*","Button",true,false):
		if node.text==text:return node
	return null
func check_visible_button(text: String) -> Button:
	var button:=button_named(text)
	check(button!=null,"missing: "+text)
	if button==null:return null
	var rect:=button.get_global_rect()
	var visible:=button.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(rect)
	var parent=button.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents:visible=visible and parent.get_global_rect().encloses(rect)
		parent=parent.get_parent()
	check(visible,"clipped: "+text)
	return button
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(800,600)
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false;app.store.path="/tmp/mystery-panel-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(8):await process_frame
	app.set_process(false);app.start_character({"id":"panel","name":"配方界面","job":"战士","gender":"男"});app.world.hide()
	app.game_panel("测试保留窗口",Vector2(200,150))
	preload("res://scripts/edition2011/mystery_books.gd").materials_panel(app)
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/mystery-panel.png")
	for title in ["确认材料并制作","采矿方法与配方说明","寻找出售鹤嘴锄的比奇铁匠","寻找金条兑换员","查看金矿采集与掉落来源","返回技能书商店"]:check_visible_button(title)
	var help:=button_named("采矿方法与配方说明")
	if help!=null:
		help.pressed.emit()
		for i in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/world-story/mystery-help.png")
		check(not app.windows.windows.has("成男 · 神秘武器配方"),"help replaces recipe")
		check(app.windows.windows.has("测试保留窗口"),"unrelated window preserved")
		var back:=check_visible_button("返回本职业配方")
		if back!=null:
			back.pressed.emit()
			for i in range(8):await process_frame
			check_visible_button("确认材料并制作")
			check(not app.windows.windows.has("神秘打造 · 采矿说明"),"return closes help")
			check(app.windows.windows.size()==2,"only current page and unrelated window remain")
			button_named("返回技能书商店").pressed.emit()
			for i in range(8):await process_frame
			check(not app.windows.windows.has("成男 · 神秘武器配方"),"shop replaces recipe")
			check_visible_button("查看本职业武器配方与材料来源")
			check(app.windows.windows.has("测试保留窗口"),"shop keeps unrelated window")
	preload("res://scripts/edition2011/peach_crafting.gd").sources_panel(app,{"name":"金矿来源","materials":{"ref:132":5}})
	for i in range(8):await process_frame
	check_visible_button("前往废矿寻找矿壁")
	var labels: String=""
	for node in app.panel.find_children("*","Label",true,false):labels+=node.text
	check(labels.contains("纯度至少18") and labels.contains("单机重建"),"ore provenance and crafting requirement visible in source text")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/mystery-sources.png")
	preload("res://scripts/edition2011/mystery_books.gd").oil_panel(app)
	for i in range(8):await process_frame
	for title in ["确认材料并制作祝福油","查看强效太阳水来源","返回技能书商店"]:check_visible_button(title)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/blessing-oil-panel.png")
	button_named("查看强效太阳水来源").pressed.emit()
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/world-story/blessing-oil-sources.png")
	var sources: Array=preload("res://scripts/edition2011/peach_crafting.gd").material_sources("ref:193")
	check(not sources.is_empty(),"strong sunwater has enabled populated monster sources")
	var next_page:=check_visible_button("下一页来源")
	if next_page!=null:
		next_page.pressed.emit()
		for i in range(8):await process_frame
		var text: String=""
		for node in app.panel.find_children("*","Label",true,false):text+=node.text
		check(text.contains("第2页") and text.contains(str(sources[3].monster)),"source pagination displays next source group")
		var previous:=check_visible_button("上一页来源")
		if previous!=null:
			previous.pressed.emit()
			for i in range(8):await process_frame
			text=""
			for node in app.panel.find_children("*","Label",true,false):text+=node.text
			check(text.contains("第1页") and text.contains(str(sources[0].monster)),"previous page restores initial source group")
	var distribution:=check_visible_button("查看分布与路线 · "+str(sources[0].monster))
	if distribution!=null:
		distribution.pressed.emit()
		for i in range(8):await process_frame
		for mid in sources[0].maps.slice(0,6):check_visible_button("查看路线 · "+str(app.resources.map_by_id[mid].name))
		var return_sources:=check_visible_button("返回材料来源")
		if return_sources!=null:
			return_sources.pressed.emit()
			for i in range(8):await process_frame
			check(not app.windows.windows.has("材料怪物分布"),"return closes map subpage")
	var report={"checks":checks,"failures":failures,"scope":"800x600 native rendered button clipping and signal-driven help return; no physical input"}
	FileAccess.open("res://../artifacts/world-story/mystery-panel-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));app.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
