class_name ClassicFrontend
extends Control

signal enter_character(profile: Dictionary, save_directory: String)
signal exit_requested
var accounts := LocalAccounts.new()
var audio := ClassicAudio.new()
var metadata: Dictionary={}
var atlases: Array[Texture2D]=[]
var page:="login"
var form:=Control.new()
var fields: Dictionary={}
var buttons: Array[BaseButton]=[]
var note: Label
var elapsed:=0.0
var picked_job:="战士"
var picked_gender:="男"
var selected_id:=""
var remembered:=""
var remember:=false
var import_legacy:=false
var busy:=false
var task:=Thread.new()
var operation:=""
var success_username:=""
var loading_time:=0.0
var last_chime:=""
var loaded:=false
var font:=SystemFont.new()

func _ready() -> void:
	size=Vector2(800,600)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	font.font_names=PackedStringArray(["PingFang SC","Heiti SC","Arial"])
	var theme:=Theme.new();theme.default_font=font;theme.default_font_size=14;self.theme=theme
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(form);form.mouse_filter=Control.MOUSE_FILTER_IGNORE;form.size=size
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/manifest.json"))
	if not manifest is Dictionary:fatal("缺少资源清单 manifest.json");return
	var expected:=""
	for entry in manifest.get("outputs",[]):
		if entry.path=="front/front.json":expected=entry.sha256
	if expected.is_empty() or FileAccess.get_sha256("res://assets/generated/front/front.json")!=expected:
		fatal("界面清单校验失败：front/front.json");return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/front/front.json"))
	if not parsed is Dictionary or parsed.get("format_version")!=1:
		fatal("界面资源无效：front/front.json");return
	metadata=parsed
	for i in range(int(metadata.atlas_count)):
		var path:="res://assets/generated/front/atlas_%d.png" % i
		var tex:=load(path) as Texture2D
		if tex==null:fatal("缺少界面图集："+path);return
		atlases.append(tex)
	audio.directory=accounts.directory;add_child(audio)
	if not audio.configure("res://assets/generated",false):fatal(audio.error_message);return
	for key in metadata.audio:
		var path:="res://assets/generated/"+str(metadata.audio[key].file)
		var stream:=load(path) as AudioStream
		if stream==null or stream.get_length()<=0:fatal("界面声音无法读取："+path);return
		audio.streams[key]=stream
	audio.music.finished.connect(func():if page!="loading" and audio.music.stream!=null:audio.music.play())
	var config:=ConfigFile.new()
	if config.load(accounts.directory.path_join("entry.cfg"))==OK:
		remember=bool(config.get_value("login","remember",false))
		remembered=str(config.get_value("login","username","")) if remember else ""
	accounts.load_database()
	loaded=true
	show_page("login" if accounts.current_id.is_empty() else "roster")
	if not accounts.healthy:notify(accounts.message)

func fatal(text: String) -> void:
	page="error"
	label("界面资源尚未就绪",Rect2(80,170,640,40),24)
	label(text,Rect2(80,235,640,130),16)
	text_button("退出",Rect2(340,400,120,36),func():exit_requested.emit())

func texture(key: String) -> AtlasTexture:
	var t:=AtlasTexture.new();var entry: Array=metadata.textures[key].texture
	t.atlas=atlases[int(entry[0])];t.region=Rect2(entry[1],entry[2],entry[3],entry[4]);return t

func paint(entry: Array,at: Vector2,color:=Color.WHITE) -> void:
	draw_texture_rect_region(atlases[int(entry[0])],Rect2(at,Vector2(entry[3],entry[4])),Rect2(entry[1],entry[2],entry[3],entry[4]),color)

func paint_key(key: String,at: Vector2) -> void:
	if metadata.textures.has(key):paint(metadata.textures[key].texture,at)

func portrait(job: String,gender: String,origin: Vector2,motion: int,active: bool) -> void:
	var frames: Array=metadata.portraits[job][gender][str(motion)]
	var frame:=int(elapsed*10)%frames.size() if active else 0
	for layer in frames[frame]:
		var tint:=Color.WHITE if active else Color(0.52,0.52,0.52)
		if layer.shadow:tint.a=0.6
		paint(layer.texture,origin+Vector2(layer.offset[0],layer.offset[1]),tint)

func _draw() -> void:
	if not loaded:return
	if page in ["login","register","password","worlds"]:
		paint_key("00000003",Vector2.ZERO);paint_key("00000004",Vector2(0,465))
		if page=="login":paint_key("00000011",Vector2(103,536))
	else:
		paint_key("0D000000" if page=="create" else "0C000000",Vector2.ZERO)
	if page=="create":
		portrait(picked_job,"男",Vector2(193,215),4,picked_gender=="男")
		portrait(picked_job,"女",Vector2(495,260 if picked_job=="战士" else 220),4,picked_gender=="女")
		paint_key("0D000001",Vector2(320,500))
		var x: float={"战士":354,"法师":396,"道士":439}[picked_job]
		draw_arc(Vector2(x,554),19,0,TAU,48,Color("e8c776"),1.5)
	if page in ["roster","delete","loading"]:
		var character:=accounts.character(selected_id)
		if not character.is_empty():
			var duration: float=metadata.portraits[character.job][character.gender]["1"].size()/10.0
			var motion:=1 if elapsed<duration else 2
			portrait(character.job,character.gender,Vector2(430,300),motion,true)

func label(text: String,rect: Rect2,font_size:=14,color:=Color("ead8ad")) -> Label:
	var l:=Label.new();l.text=text;l.position=rect.position;l.size=rect.size;l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color);l.add_theme_color_override("font_outline_color",Color("17110b"));l.add_theme_constant_override("outline_size",3)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;form.add_child(l);return l

func panel(rect: Rect2) -> Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.055,0.035,0.015,0.94);style.border_color=Color("806a3c");style.set_border_width_all(1);style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel",style);form.add_child(p);return p

func field(key: String,rect: Rect2,secret:=false,text:="") -> LineEdit:
	var e:=LineEdit.new();e.position=rect.position;e.size=rect.size;e.secret=secret;e.text=text
	e.max_length=128 if secret else 24;e.add_theme_font_size_override("font_size",14);e.clear_button_enabled=not secret
	form.add_child(e);fields[key]=e
	return e

func text_button(text: String,rect: Rect2,callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_ALL
	b.pressed.connect(callback);form.add_child(b);buttons.append(b);return b

func image_button(key: String,at: Vector2,callback: Callable,hint: String) -> TextureButton:
	var b:=TextureButton.new();b.texture_normal=texture(key);b.position=at
	var id:=key.hex_to_int()
	if metadata.textures.has("%08X" % (id+1)):b.texture_hover=texture("%08X" % (id+1));b.texture_pressed=b.texture_hover
	if metadata.textures.has("%08X" % (id+2)):b.texture_pressed=texture("%08X" % (id+2))
	b.tooltip_text=hint;b.focus_mode=Control.FOCUS_ALL;b.pressed.connect(callback);form.add_child(b);buttons.append(b);return b

func music(key: String) -> void:
	if audio.music.get_meta("track","")==key:return
	audio.music.stop();audio.music.stream=audio.streams[key].duplicate();audio.music.set_meta("track",key)
	if audio.music.stream is AudioStreamMP3:audio.music.stream.loop=page!="loading"
	audio.apply_volumes();audio.music.play()

func show_page(value: String) -> void:
	if busy:return
	for child in form.get_children():form.remove_child(child);child.queue_free()
	fields.clear();buttons.clear();page=value;elapsed=0;last_chime=""
	note=null
	if value in ["login","register","password","worlds"]:music("00040007")
	elif value=="create":music("00040001")
	elif value=="loading":music("00040003")
	else:music("00040002")
	match value:
		"login":build_login()
		"register","password":build_registration(value=="password")
		"worlds":build_worlds()
		"roster":build_roster()
		"create":build_create()
		"delete":build_delete()
		"loading":
			label("正在进入玛法大陆……",Rect2(200,140,400,40),22).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			loading_time=0
	note=label("",Rect2(100,20,600,45),14);note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var footer:=label("本机单机 · 社区兼容界面，非核验 1.76 · 0.3.0",Rect2(0,581,800,18),10,Color("a99875"));footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not accounts.healthy and value=="login":
		for b in buttons:b.disabled=true
		text_button("恢复上次备份",Rect2(300,420,200,32),func():
			if accounts.restore_backup():show_page("login");notify("账号备份已恢复。")
			else:notify(accounts.message))
	queue_redraw()

func build_login() -> void:
	image_button("00000005",Vector2(150,482),func():show_page("register"),"创建本机账号")
	image_button("00000008",Vector2(352,482),func():show_page("password"),"修改本机密码")
	image_button("0000000B",Vector2(554,482),func():exit_requested.emit(),"退出游戏")
	image_button("0000000E",Vector2(600,536),func():authenticate("login"),"登录")
	field("username",Rect2(159,537,146,25),false,remembered)
	field("password",Rect2(409,537,146,25),true).text_submitted.connect(func(_s):authenticate("login"))
	var box:=CheckBox.new();box.text="记住账号";box.position=Vector2(105,561);box.add_theme_font_size_override("font_size",11);box.button_pressed=remember;box.toggled.connect(func(v):remember=v);form.add_child(box)
	label("账号与角色只保存在这台 Mac，无需联网。",Rect2(355,565,390,16),11)
	focus_username.call_deferred()

func build_registration(change: bool) -> void:
	panel(Rect2(170,126,460,352))
	label("修改密码" if change else "创建本机账号",Rect2(210,147,380,35),23)
	var rows: Array=[["username","账　号",false],["old","原密码",true],["password","新密码",true],["confirm","再输入",true]] if change else [["username","账　号",false],["password","密　码",true],["confirm","再输入",true]]
	for i in range(rows.size()):
		var row: Array=rows[i];label(row[1],Rect2(210,202+i*47,92,28),15)
		field(row[0],Rect2(310,202+i*47,270,28),row[2],remembered if i==0 else "")
	label("账号 3–24 位字母数字_；密码 8–128 个字符。",Rect2(210,395,380,24),11)
	text_button("确认修改" if change else "注册账号",Rect2(310,435,125,30),func():authenticate("password" if change else "register"))
	text_button("返回",Rect2(450,435,125,30),func():show_page("login"))
	fields.confirm.text_submitted.connect(func(_s):authenticate("password" if change else "register"))
	focus_username.call_deferred()

func build_worlds() -> void:
	panel(Rect2(180,180,440,205))
	label("选择玛法世界",Rect2(210,195,380,32),22)
	text_button("玛法大陆　·　本机单机",Rect2(220,250,360,44),func():show_page("roster"))
	label("本机账号："+accounts.account().username,Rect2(220,304,350,25),13)
	text_button("注销返回",Rect2(445,341,130,28),logout)

func build_roster() -> void:
	var characters:=accounts.characters()
	if accounts.character(selected_id).is_empty():selected_id=characters[0].id if not characters.is_empty() else ""
	panel(Rect2(30,115,210,319))
	label("角色名册 · "+accounts.account().username,Rect2(45,127,183,34),14)
	for i in range(3):
		var text:="空角色位　＋"
		if i<characters.size():text="%s\n%s · %s · 等级 1" % [characters[i].name,characters[i].job,characters[i].gender]
		var b:=text_button(text,Rect2(45,171+i*80,180,67),func():
			if i<characters.size():selected_id=characters[i].id;show_page("roster")
			else:show_page("create"))
		if i<characters.size() and characters[i].id==selected_id:b.modulate=Color("ffcf76")
	image_button("0C000030",Vector2(335,75),start_game,"开始游戏").disabled=selected_id.is_empty()
	image_button("0C000010",Vector2(565,130),func():show_page("create"),"创建角色").disabled=characters.size()>=3
	image_button("0C000020",Vector2(60,463),func():show_page("delete"),"删除角色（保留备份）").disabled=selected_id.is_empty()
	image_button("0C000040",Vector2(45,544),func():exit_requested.emit(),"退出游戏")
	text_button("注销账号",Rect2(170,547,110,28),logout)
	var c:=accounts.character(selected_id)
	if not c.is_empty():
		label("%s　%s · %s" % [c.name,c.job,c.gender],Rect2(280,148,270,38),17).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label("等级 1 · 比奇大陆",Rect2(280,183,270,24),13).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		play_portrait_sound(c.job,c.gender,1)
	else:label("先创建一位角色，开始玛法之旅。",Rect2(290,285,350,60),19)

func build_create() -> void:
	label("创建角色",Rect2(300,30,200,34),24).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var description: String={"战士":"以剑与力量迎战，擅长近身攻防。","法师":"驾驭元素，以魔法远攻与范围法术制敌。","道士":"道术、治疗与召唤，攻守兼备。"}[picked_job]
	label(picked_job+"　/　"+description,Rect2(150,78,500,45),15).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for gender in ["男","女"]:
		var x:=183 if gender=="男" else 500
		var b:=text_button(("✓ " if gender==picked_gender else "")+gender+"角色",Rect2(x,474,116,29),func():picked_gender=gender;show_page("create"))
		if gender==picked_gender:b.modulate=Color("ffcf76")
	var name:="" if not has_meta("draft_name") else str(get_meta("draft_name"))
	var edit:=field("name",Rect2(355,517,100,22),false,name);edit.max_length=12;edit.add_theme_font_size_override("font_size",12)
	edit.text_changed.connect(func(v):set_meta("draft_name",v));edit.text_submitted.connect(func(_s):create_character())
	for spec in [["战士","0D000030",339],["法师","0D000040",381],["道士","0D000050",424]]:
		image_button(spec[1],Vector2(spec[2],539),func():picked_job=spec[0];show_page("create"),spec[0])
	image_button("0D000010",Vector2(512,549),create_character,"创建角色")
	image_button("0D000020",Vector2(554,549),func():show_page("roster"),"返回角色选择")
	if FileAccess.file_exists(accounts.directory.path_join("save.json")) and accounts.characters().is_empty():
		var box:=CheckBox.new();box.text="接续旧版漫游位置（保留原存档）";box.position=Vector2(210,120);box.add_theme_font_size_override("font_size",12);box.button_pressed=import_legacy;box.toggled.connect(func(v):import_legacy=v);form.add_child(box)
	play_portrait_sound(picked_job,picked_gender,0)

func build_delete() -> void:
	var c:=accounts.character(selected_id)
	panel(Rect2(170,190,460,210))
	label("删除角色："+str(c.get("name","")),Rect2(195,208,410,30),19)
	label("请输入角色全名确认。旧存档仍会保留在备份中。",Rect2(195,246,410,38),13)
	field("confirmation",Rect2(235,290,330,28))
	text_button("确认删除",Rect2(260,345,125,32),func():
		if accounts.archive_character(selected_id,fields.confirmation.text):selected_id="";show_page("roster");notify("已移出角色名册，存档备份保留。")
		else:notify(accounts.message))
	text_button("取消",Rect2(410,345,125,32),func():show_page("roster"))

func play_portrait_sound(job: String,gender: String,phase: int) -> void:
	var key:="%08X" % (0x00010000|int({"战士":0,"道士":1,"法师":2}[job])<<8|int(gender=="男")<<4|phase)
	audio.play_sound(key)

func notify(text: String) -> void:
	if note!=null:note.text=text

func authenticate(kind: String) -> void:
	if busy:return
	var username: String=fields.username.text
	var password: String=fields.password.text
	var confirm: String=fields.confirm.text if fields.has("confirm") else ""
	var old: String=fields.old.text if fields.has("old") else ""
	operation=kind;success_username=username.strip_edges().to_lower();busy=true
	for b in buttons:b.disabled=true
	for f in fields.values():f.editable=false
	notify("正在核验本机账号……" if kind=="login" else "正在保存，请稍候……")
	task=Thread.new()
	var error:=task.start(func():
		match kind:
			"login":return accounts.login(username,password)
			"register":return accounts.register_account(username,password,confirm)
			"password":return accounts.change_password(username,old,password,confirm)
		return false)
	if error!=OK:busy=false;notify("无法启动账号处理，请重新打开游戏。")

func _process(delta: float) -> void:
	if not loaded:return
	elapsed+=delta;queue_redraw()
	if busy and not task.is_alive():
		var ok=task.wait_to_finish();busy=false
		if ok:
			remembered=success_username
			if operation=="login":save_remembered();show_page("worlds")
			else:show_page("login");notify("注册成功，请登录。" if operation=="register" else "密码已修改，请重新登录。")
		else:
			for b in buttons:b.disabled=false
			for f in fields.values():f.editable=true
			notify(accounts.message)
	if page=="loading":
		loading_time+=delta
		if loading_time>=1.2:
			page="entered";audio.music.stop()
			var c:=accounts.character(selected_id)
			enter_character.emit(c.duplicate(true),accounts.character_directory(c.id))

func save_remembered() -> void:
	var config:=ConfigFile.new();config.set_value("login","remember",remember);config.set_value("login","username",remembered if remember else "")
	config.save(accounts.directory.path_join("entry.cfg"))

func create_character() -> void:
	var c:=accounts.create_character(fields.name.text,picked_job,picked_gender,import_legacy)
	if c.is_empty():notify(accounts.message);return
	selected_id=c.id
	if has_meta("draft_name"):remove_meta("draft_name")
	import_legacy=false;show_page("roster")
	if not accounts.message.is_empty():notify(accounts.message)

func start_game() -> void:
	if accounts.character(selected_id).is_empty():notify("请先创建并选择角色。 ");return
	show_page("loading")

func logout() -> void:
	accounts.current_id="";selected_id="";show_page("login")

func _exit_tree() -> void:
	if task.is_started():task.wait_to_finish()

func focus_username() -> void:
	if is_inside_tree() and fields.has("username") and fields.username.is_inside_tree():fields.username.grab_focus()
