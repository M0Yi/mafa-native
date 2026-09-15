extends SceneTree
var app
var ticks:=0
var title: Label
var subtitle: Label
func _initialize():call_deferred("setup")
func setup() -> void:
	root.size=Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../.cache/promo-frames"))
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mafa-promo-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(10):await process_frame
	app.start_character({"id":"promo","name":"行路人","job":"法师","gender":"女"});app.world.paused=false;app.set_process(false)
	var layer:=CanvasLayer.new();layer.layer=99;root.add_child(layer)
	var shade:=ColorRect.new();shade.color=Color(0.035,0.045,0.05,0.9);shade.position=Vector2(0,0);shade.size=Vector2(1280,102);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(shade)
	title=Label.new();title.position=Vector2(42,14);title.add_theme_font_override("font",app.font);title.add_theme_font_size_override("font_size",30);title.modulate=Color("eaca8c");layer.add_child(title)
	subtitle=Label.new();subtitle.position=Vector2(44,59);subtitle.add_theme_font_override("font",app.font);subtitle.add_theme_font_size_override("font_size",17);layer.add_child(subtitle)
	var credit:=Label.new();credit.text="实机开发画面 · 单机重建 · 素材由用户自行载入";credit.position=Vector2(850,776);credit.add_theme_font_override("font",app.font);credit.add_theme_font_size_override("font_size",13);layer.add_child(credit)
	process_frame.connect(step)
func step() -> void:
	ticks+=1
	app._process(1.0/30)
	if ticks==1:
		title.text="回到玛法，按自己的节奏冒险。";subtitle.text="火龙神殿 · 经典像素风单机重建"
	if ticks==120:
		title.text="从新手村，再次出发";subtitle.text="任务、探索、装备成长 · 进度保存在本机"
		app.world.player.go_to(app.world.player.cell+Vector2i(5,0))
	if ticks==240:app.world.player.go_to(app.world.player.cell+Vector2i(0,5))
	if ticks==360:
		app.show_controller_panel();title.text="键鼠与手柄，各有顺手的操作";subtitle.text="肩键切换背包、装备、技能与任务"
	if ticks in [430,490,550]:
		var view=app.form.get_child(1);view.page=(view.page+1)%4;view.refresh()
	if ticks==630:
		app.windows.close_all();app.gameplay.show_assist();title.text="把重复操作交给本地辅助";subtitle.text="自动补给、脚下拾取与职业辅助 · 所有自动行为默认关闭"
	if ticks==720:app.form.get_child(app.form.get_child_count()-1).select(3)
	if ticks==870:
		app.windows.close_all();app.enter_map("3",Vector2i(-1,-1));app.world.paused=false;title.text="熟悉的城镇，继续自己的旅程";subtitle.text="跨区域探索 · 本地任务与 NPC 服务"
	if ticks==930:app.world.player.go_to(app.world.player.cell+Vector2i(4,0))
	if ticks==1050:
		title.text="只分发程序，把素材留在你的电脑";subtitle.text="macOS · Windows · Linux 预发布 / 自行载入适配客户端"
	if ticks==1200:
		title.text="玛法 · 火龙神殿";subtitle.text="github.com/M0Yi/mafa-native  ·  0.14.0 Preview"
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://../.cache/promo-frames/%05d.png"%ticks)
	if ticks>=1350:app.queue_free();quit()
