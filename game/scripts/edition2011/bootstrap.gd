extends Control
# The distributed application contains code only. Client data is read from a local cache.
var status: Label
var choose: Button
var supplement_source: LineEdit
var source: LineEdit
var output:=""
var pid:=-1
var elapsed:=0.0
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-output="):
			var report: Dictionary=load("res://scripts/edition2011/package_audit.gd").new().run()
			FileAccess.open(arg.trim_prefix("--audit-output="),FileAccess.WRITE).store_string(JSON.stringify(report))
			print(JSON.stringify(report));get_tree().quit(0 if report.code_only else 1);return
	var cfg:=ConfigFile.new();cfg.load("user://resources.cfg")
	var root: String=cfg.get_value("resources","root","")
	var forced:=false
	for arg in OS.get_cmdline_user_args():
		if arg=="--asset-setup":forced=true
		if arg.begins_with("--asset-root="):root=arg.trim_prefix("--asset-root=")
	if not forced:
		if not root.is_empty() and valid(root):launch(root);return
		if OS.has_feature("editor") and valid("res://assets"):launch("res://assets");return
	build_ui()
func valid(root: String) -> bool:
	var path:=root.path_join("client2011/manifest.json")
	if not FileAccess.file_exists(path):return false
	var raw=JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw is Dictionary and raw.get("resource_version")=="2.0.1.11" and FileAccess.file_exists(root.path_join("client2011/maps.json"))
func launch(root: String) -> void:
	EditionResources.BASE=root.path_join("client2011/")
	EditionResources.SUPPLEMENT_BASE=root.path_join("supplement16/")
	get_tree().change_scene_to_file.call_deferred("res://edition2011.tscn")
func build_ui() -> void:
	var font:=SystemFont.new();font.font_names=PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC","WenQuanYi Micro Hei"])
	font.fallbacks=[load("res://fonts/NotoSansCJKsc-Regular.otf")]
	theme=Theme.new();theme.default_font=font;theme.default_font_size=16
	var bg:=ColorRect.new();bg.color=Color("141b20");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,32)
	add_child(margin)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",20);margin.add_child(box)
	var heading:=Label.new();heading.text="玛法 · 本机资源设置";heading.add_theme_font_size_override("font_size",28);box.add_child(heading)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.text="游戏不附带热血传奇原始或转换后的图片、地图、音乐与音效。\n选择你自行准备的 2.0.1.11 十周年客户端文件夹（包含 Data、Map、Wav）。首次导入会在本机生成缓存，可能需要数分钟和数 GB 空间。\n客户端中的 EXE 不会执行；缓存与存档分开保存。"
	box.add_child(status)
	source=LineEdit.new();source.placeholder_text="原始客户端目录";box.add_child(source)
	supplement_source=LineEdit.new();supplement_source.placeholder_text="可选：十六周年客户端目录（补充缺图与声音）";box.add_child(supplement_source)
	var extra:=Button.new();extra.text="选择十六周年补充目录（可选）";box.add_child(extra);extra.pressed.connect(func():directory(func(path):supplement_source.text=path))
	choose=Button.new();choose.text="选择原始客户端目录并导入";choose.custom_minimum_size.y=48;box.add_child(choose)
	choose.pressed.connect(func():directory(func(path):source.text=path;start_import(path)))
	var manual:=Button.new();manual.text="导入上面填写的目录";box.add_child(manual);manual.pressed.connect(func():start_import(source.text))
	var existing:=Button.new();existing.text="载入已转换资源目录（包含 client2011）";box.add_child(existing)
	existing.pressed.connect(func():
		if pid>0:return
		directory(func(path):
			if valid(path):save_and_launch(path)
			else:status.text="目录无效：请选择包含 client2011/manifest.json 的资源根目录。"))
	var quit:=Button.new();quit.text="退出";box.add_child(quit);quit.pressed.connect(func():
		if pid>0:status.text="转换仍在运行，请等待完成后退出。";return
		get_tree().quit())
func directory(callback: Callable) -> void:
	var picker:=FileDialog.new();picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_DIR;picker.use_native_dialog=true
	add_child(picker);picker.dir_selected.connect(func(path):callback.call(path);picker.queue_free());picker.canceled.connect(picker.queue_free);picker.popup_centered_ratio(0.8)
func start_import(path: String) -> void:
	if pid>0:return
	if not DirAccess.dir_exists_absolute(path):status.text="客户端目录不存在。";return
	output=ProjectSettings.globalize_path("user://resource-cache")
	DirAccess.make_dir_recursive_absolute(output)
	var report:=output.path_join("import-status.json")
	if FileAccess.file_exists(report):DirAccess.remove_absolute(report)
	var executable:=OS.get_executable_path().get_base_dir().path_join("mafa-importer.exe" if OS.get_name()=="Windows" else "mafa-importer")
	var args:=PackedStringArray(["--source",path,"--output",output])
	if not supplement_source.text.strip_edges().is_empty():args.append_array(["--supplement",supplement_source.text.strip_edges()])
	if OS.has_feature("editor"):
		executable=OS.get_environment("MAFA_PYTHON")
		if executable.is_empty():executable="python" if OS.get_name()=="Windows" else "python3"
		args.insert(0,ProjectSettings.globalize_path("res://../tools/import_client.py"))
	if not OS.has_feature("editor") and not FileAccess.file_exists(executable):status.text="资源导入工具缺失，请重新解压完整发布包。";return
	pid=OS.create_process(executable,args)
	choose.disabled=pid>0
	status.text="正在转换原始素材，原目录保持只读。请等待完成；失败后可以重试。" if pid>0 else "无法启动导入工具；开发环境请先安装 Python 依赖。"
func _process(delta: float) -> void:
	if pid<=0:return
	elapsed+=delta
	if elapsed<1:return
	elapsed=0
	var path:=output.path_join("import-status.json")
	if FileAccess.file_exists(path):
		var report=JSON.parse_string(FileAccess.get_file_as_string(path))
		if report is Dictionary:
			if report.get("state")=="ready":pid=-1;save_and_launch(report.root);return
			if report.get("state")=="error":pid=-1;choose.disabled=false;status.text="导入失败："+str(report.message);return
	if not OS.is_process_running(pid):pid=-1;choose.disabled=false;status.text="导入工具已退出但没有完成。请检查客户端与磁盘空间，然后重试。"
func save_and_launch(root: String) -> void:
	var cfg:=ConfigFile.new();cfg.set_value("resources","root",root)
	if cfg.save("user://resources.cfg")!=OK:status.text="无法保存资源设置，未修改存档。";return
	launch(root)
