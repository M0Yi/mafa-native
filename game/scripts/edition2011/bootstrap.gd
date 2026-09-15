extends Control
# The distributed application contains code only. Client data is read from a local cache.
var status: Label
var choose: Button
var supplement_source: LineEdit
var source: LineEdit
var output:=""
var cache_parent:="user://resource-cache"
var settings_path:="user://resources.cfg"
var pid:=-1
var elapsed:=0.0
var verifying_root:=""
func _ready() -> void:
	get_tree().auto_accept_quit=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-output="):
			var report: Dictionary=load("res://scripts/edition2011/package_audit.gd").new().run()
			var destination:=FileAccess.open(arg.trim_prefix("--audit-output="),FileAccess.WRITE)
			if destination==null:
				printerr("无法写入发布审计报告：",FileAccess.get_open_error());get_tree().quit(1);return
			destination.store_string(JSON.stringify(report));destination.flush()
			var write_error:=destination.get_error();destination.close()
			if write_error!=OK:
				printerr("发布审计报告写入失败：",write_error);get_tree().quit(1);return
			print(JSON.stringify(report));get_tree().quit(0 if report.code_only else 1);return
	var cfg:=ConfigFile.new()
	var loaded:=cfg.load(settings_path)
	if loaded!=OK and loaded!=ERR_FILE_NOT_FOUND:
		build_ui();status.text="无法读取现有资源设置，已保留原文件。请检查文件和权限后重试。";return
	var configured_root=cfg.get_value("resources","root","")
	if not configured_root is String:
		build_ui();status.text="资源设置中的缓存路径格式错误，已保留原文件。请选择有效的缓存目录或重新导入。";return
	var root: String=configured_root
	var forced:=false
	for arg in OS.get_cmdline_user_args():
		if arg=="--asset-setup":forced=true
		if arg.begins_with("--asset-root="):root=arg.trim_prefix("--asset-root=")
	if not forced:
		if not root.is_empty():
			build_ui()
			if valid(root):start_verification(root)
			else:status.text="上次使用的素材缓存不存在或不完整，请重新选择或导入。"
			return
		if OS.has_feature("editor") and valid("res://assets"):launch("res://assets");return
	build_ui()
func valid(root: String) -> bool:
	var path:=root.path_join("client2011/manifest.json")
	if not FileAccess.file_exists(path):return false
	var raw=JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw is Dictionary and raw.get("resource_version")=="2.0.1.11" and FileAccess.file_exists(root.path_join("client2011/maps.json"))
func launch(root: String) -> void:
	get_tree().auto_accept_quit=true
	EditionResources.BASE=root.path_join("client2011/")
	EditionResources.SUPPLEMENT_BASE=root.path_join("supplement16/")
	get_tree().change_scene_to_file.call_deferred("res://edition2011.tscn")
func build_ui() -> void:
	var font: Font=preload("res://fonts/NotoSansCJKsc-Regular.otf")
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
			if valid(path):start_verification(path)
			else:status.text="目录无效：请选择包含 client2011/manifest.json 的资源根目录。"))
	var quit:=Button.new();quit.text="退出";box.add_child(quit);quit.pressed.connect(request_quit)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:request_quit()
func request_quit() -> void:
	if pid>0:
		status.text="素材处理仍在运行，请等待完成后退出；原始客户端和现有存档不会被修改。"
		return
	get_tree().quit()
func directory(callback: Callable) -> void:
	var picker:=FileDialog.new();picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_DIR;picker.use_native_dialog=true
	add_child(picker);picker.dir_selected.connect(func(path):callback.call(path);picker.queue_free());picker.canceled.connect(picker.queue_free);picker.popup_centered_ratio(0.8)
func start_import(path: String) -> void:
	if pid>0:return
	if not DirAccess.dir_exists_absolute(path):status.text="客户端目录不存在。";return
	verifying_root=""
	var arguments:=PackedStringArray(["--source",path])
	if not supplement_source.text.strip_edges().is_empty():arguments.append_array(["--supplement",supplement_source.text.strip_edges()])
	start_worker(arguments)
func start_verification(path: String) -> void:
	if pid>0:return
	verifying_root=ProjectSettings.globalize_path(path).replace("\\","/").trim_suffix("/")
	start_worker(PackedStringArray(["--verify-cache",verifying_root]))
func start_worker(arguments: PackedStringArray) -> void:
	output=ProjectSettings.globalize_path(cache_parent.path_join("import-"+Crypto.new().generate_random_bytes(12).hex_encode()))
	if DirAccess.make_dir_recursive_absolute(output)!=OK:status.text="无法创建素材缓存目录，请检查磁盘空间与写入权限。";return
	var executable:=OS.get_executable_path().get_base_dir().path_join("mafa-importer.exe" if OS.get_name()=="Windows" else "mafa-importer")
	var args:=arguments.duplicate()
	args.append_array(["--output",output])
	if OS.has_feature("editor"):
		executable=OS.get_environment("MAFA_PYTHON")
		if executable.is_empty():executable="python" if OS.get_name()=="Windows" else "python3"
		args.insert(0,ProjectSettings.globalize_path("res://../tools/import_client.py"))
	if not OS.has_feature("editor") and not FileAccess.file_exists(executable):status.text="资源导入工具缺失，请重新解压完整发布包。";return
	pid=OS.create_process(executable,args)
	choose.disabled=pid>0
	if pid>0 and not verifying_root.is_empty():status.text="正在检查已有地图、图像和声音缓存，请稍候。";return
	status.text="正在转换原始素材，原目录保持只读。请等待完成；失败后可以重试。" if pid>0 else "无法启动导入工具；开发环境请先安装 Python 依赖。"
func _process(delta: float) -> void:
	if pid<=0:return
	elapsed+=delta
	if elapsed<1:return
	elapsed=0
	var path:=output.path_join("import-status.json")
	if FileAccess.file_exists(path):
		var parser:=JSON.new()
		var report=parser.data if parser.parse(FileAccess.get_file_as_string(path))==OK else null
		if report is Dictionary:
			if report.get("state")=="ready":
				pid=-1;choose.disabled=false
				var result: String=str(report.get("root","")).replace("\\","/")
				if (not result.begins_with(output+"/") if verifying_root.is_empty() else result!=verifying_root) or not valid(result):status.text="导入结果目录缺失或不匹配，请重新导入。";return
				save_and_launch(result);return
			if report.get("state")=="error":
				pid=-1;choose.disabled=false
				var message=report.get("message","")
				status.text="导入失败："+(message if message is String and not message.strip_edges().is_empty() else "未提供错误详情，请检查导入日志后重试。")
				return
	if not OS.is_process_running(pid):pid=-1;choose.disabled=false;status.text="导入工具已退出但没有完成。请检查客户端与磁盘空间，然后重试。"
func save_and_launch(root: String) -> void:
	var cfg:=ConfigFile.new()
	var loaded:=cfg.load(settings_path)
	if loaded!=OK and loaded!=ERR_FILE_NOT_FOUND:
		status.text="无法读取现有资源设置，已保留原文件。请检查文件和权限后重试。";return
	cfg.set_value("resources","root",root)
	var target:=ProjectSettings.globalize_path(settings_path)
	var pending:=target+"."+Crypto.new().generate_random_bytes(12).hex_encode()+".tmp"
	var saved:=cfg.save(pending)
	if saved==OK:saved=DirAccess.rename_absolute(pending,target)
	if saved!=OK:
		if FileAccess.file_exists(pending):DirAccess.remove_absolute(pending)
		status.text="无法保存资源设置，已保留原配置和存档。请检查磁盘空间与写入权限后重试。";return
	launch(root)
