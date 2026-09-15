class_name EditionEntry
extends Control

var app
var canvas:=Control.new()
var page:="login"
var fields: Dictionary={}
var controls: Dictionary={}
var message: Label
var clock:=0.0
var transition_time:=0.0
var selected_id:=""
var previous_id:=""
var roster_page:=0
var chosen_job:=0
var chosen_sex:=0
var difficulty:="easy"
var selection_time:=0.0
var busy:=false
var pending_creation: Dictionary={}
var artwork: Array=[]
var portraits: Array=[]
var modal_text:=""
var auth_kind:=""
var remember_choice:=false
var remembered_user:=""
var selection_effect: TextureRect
const REVIVAL_DURATION:=0.65
const Layout=preload("res://scripts/edition2011/ui/entry_layout.gd")

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and is_instance_valid(canvas) and canvas.get_parent()==null:canvas.free()

func setup(host) -> void:
	app=host
	oversampling_with_scale=CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.size=Vector2(800,600)
	add_child(canvas)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(update_layout)
	show_page("login")

func clear() -> void:
	if is_instance_valid(message):
		message.get_parent().remove_child(message);message.queue_free()
	for child in canvas.get_children():canvas.remove_child(child);child.queue_free()
	fields.clear();controls.clear();artwork.clear();portraits.clear()
	message=null
	selection_effect=null

func art(bank: String,index: int,at: Vector2) -> void:
	artwork.append([bank,index,at])

func text_at(value: String,rect: Rect2,font_size:=14) -> Label:
	var label:=Label.new();label.text=value;label.position=rect.position;label.size=rect.size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("decda0"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(label);return label

func input(key: String,rect: Rect2,secret:=false) -> LineEdit:
	var node:=LineEdit.new();node.name=key;node.position=rect.position;node.size=rect.size
	node.custom_minimum_size=Vector2.ZERO;node.add_theme_font_size_override("font_size",clampi(int(rect.size.y)-5,11,13))
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.015,0.015,0.015,0.95)
	style.content_margin_left=3;style.content_margin_top=0;style.content_margin_bottom=0
	node.add_theme_stylebox_override("normal",style);node.add_theme_stylebox_override("focus",style)
	node.add_theme_stylebox_override("read_only",style)
	node.secret=secret;node.max_length=128 if secret else 24
	node.add_theme_constant_override("minimum_character_width",1)
	canvas.add_child(node);node.size=rect.size;fields[key]=node
	node.text_submitted.connect(func(_value):
		if busy or not node.is_inside_tree() or node.is_queued_for_deletion() or not node.editable:return
		get_viewport().set_input_as_handled()
		submit())
	return node

func button(id: String,rect: Rect2,callback: Callable,normal:=-1,pressed:=-1,caption:="",sound_id:=104) -> EditionSkinButton:
	var b:=EditionSkinButton.new();b.name=id;b.resources=app.resources;b.position=rect.position;b.size=rect.size
	b.highlight=not id.begins_with("portrait_")
	b.clip_contents=true
	b.normal_frame=normal;b.pressed_frame=pressed;b.text=caption;b.tooltip_text={"login":"登录本机账号","register":"注册本机账号","password":"修改密码","quit":"退出游戏","back":"返回","enter":"进入游戏","delete":"删除选中角色","create":"创建角色","restore":"恢复已删除角色","recovery":"恢复本机账号","register_submit":"创建账号","create_submit":"创建角色","close":"关闭","confirm":"确认","logout":"返回登录"}.get(id,caption)
	b.add_theme_font_size_override("font_size",14);canvas.add_child(b);controls[id]=b
	b.pressed.connect(func():
		if busy or b.disabled or not b.is_inside_tree() or b.is_queued_for_deletion():return
		if sound_id>=0:app.play_sound_id(sound_id)
		callback.call())
	return b

func notify(value: String) -> void:
	if is_instance_valid(message):message.text=value;message.tooltip_text=value
	app.pending_message=value

func show_page(value: String) -> void:
	if page=="roster" and value!="roster":
		app.stop_sound_id(101)
		# A dismissed revival is complete; returning must not resume a silent half-animation.
		selection_time=maxf(selection_time,REVIVAL_DURATION)
	page=value;clock=0;clear();visible=true;app.world.visible=false;app.hud.hide()
	app.mode="roster" if page in ["roster","create","delete","restore","credits"] else "login"
	if page in ["roster","create","delete","restore","credits"]:art("prguse",65,Vector2.ZERO)
	else:art("chrsel",22,Vector2.ZERO)
	match page:
		"login":
			art("prguse",60,Vector2(252,173))
			input("username",Rect2(348,258,140,20)).text=app.store.read_metadata("last_username")
			input("password",Rect2(348,290,141,20),true)
			var saved:=EditionRememberedLogin.saved(app.accounts)
			remembered_user=saved.get("username","")
			if not remembered_user.is_empty():
				fields.username.text=remembered_user;fields.password.placeholder_text="已记住，直接登录"
			var remember:=CheckBox.new();remember.text="记住账号密码";remember.position=Vector2(278,314)
			remember.add_theme_font_size_override("font_size",13);remember.button_pressed=not saved.is_empty()
			canvas.add_child(remember);controls["remember"]=remember
			remember.toggled.connect(func(enabled):
				if not enabled:
					if not EditionRememberedLogin.forget(app.store):notify(app.store.error);remember.set_pressed_no_signal(true);return
					remembered_user="";fields.password.placeholder_text="")
			fields.username.text_changed.connect(func(value):fields.password.placeholder_text="已记住，直接登录" if value.strip_edges().to_lower()==remembered_user and not remembered_user.is_empty() else "")
			button("login",Rect2(420,338,73,32),func():authenticate("login"))
			button("register",Rect2(278,377,102,32),func():show_page("register"))
			button("password",Rect2(383,377,117,32),func():show_page("password"))
			button("quit",Rect2(504,201,16,23),quit_prompt,-1,64)
			button("recovery",Rect2(283,442,220,28),func():show_page("recovery"),-1,-1,"本机账号恢复")
			button("import",Rect2(250,480,300,25),func():app.accounts.import_old_accounts();notify(app.accounts.message if not app.accounts.message.is_empty() else "旧账号已复制"),-1,-1,"复制旧原型账号身份")
			app.music_name("log-in-long2.wav")
		"register":
			art("prguse",63,Vector2(80,64))
			input("username",Rect2(241,180,117,16))
			input("password",Rect2(241,201,117,16),true)
			input("confirm",Rect2(241,222,117,16),true)
			text_at("本机账号\n\n账号：3–24 位英文、数字或下划线\n密码：8–128 位，支持粘贴\n\n无需真实姓名、身份证或手机。\n注册成功后请保存一次性显示的恢复码。\n恢复码可用于重设密码，请勿分享。",Rect2(155,265,480,190),15)
			button("register_submit",Rect2(237,479,82,30),func():authenticate("register"),-1,62)
			button("back",Rect2(525,482,82,30),func():show_page("login"),-1,52)
			button("close",Rect2(667,97,16,23),func():show_page("login"),-1,64)
		"password","recovery":
			art("prguse",50,Vector2(190,150))
			input("username",Rect2(429,268,137,16))
			input("old",Rect2(429,300,137,16),true)
			input("password",Rect2(429,327,137,16),true)
			input("confirm",Rect2(429,358,137,16),true)
			if page=="recovery":text_at("恢复码",Rect2(220,300,100,20),13)
			button("password_submit",Rect2(370,402,76,32),func():authenticate(page),-1,81).tooltip_text="确认修改密码"
			button("back",Rect2(465,401,96,33),func():show_page("login"),-1,52)
		"world":
			art("prguse",256,Vector2(246,65))
			text_at("选择本机世界",Rect2(325,128,200,30),18)
			button("local_world",Rect2(290,220,220,40),open_door,-1,-1,"玛法 · 本机独立世界")
			text_at("角色各自保存进度\n断网可玩",Rect2(330,285,220,80))
			button("back",Rect2(327,400,150,35),func():app.accounts.current_id="";show_page("login"),-1,-1,"返回登录")
		"door":
			transition_time=0;app.play_sound_id(100)
		"roster":build_roster()
		"create":build_create()
		"delete":
			var c: Dictionary=app.accounts.character(selected_id)
			art("prguse",360,Vector2(174,210))
			text_at("删除角色："+str(c.get("name",""))+"\n输入完整名称确认；可在选角界面恢复。",Rect2(194,230,400,60))
			input("confirmation",Rect2(210,292,360,25))
			button("delete_submit",Rect2(260,335,100,30),func():
				if app.accounts.archive_character(selected_id,fields.confirmation.text):selected_id="";show_page("roster")
				else:notify(app.accounts.message),-1,-1,"确认删除")
			button("back",Rect2(410,335,100,30),func():show_page("roster"),-1,-1,"取消")
		"restore":
			art("prguse",380,Vector2(272,120))
			text_at("恢复已删除角色",Rect2(300,145,240,30),18)
			var scroll:=ScrollContainer.new();scroll.position=Vector2(290,185);scroll.size=Vector2(220,230);canvas.add_child(scroll)
			var list:=VBoxContainer.new();scroll.add_child(list)
			for c in app.accounts.account().get("archived",[]):
				var b:=Button.new();b.text=c.name;b.custom_minimum_size=Vector2(190,28);list.add_child(b)
				b.pressed.connect(func():
					if app.accounts.restore_character(c.id):selected_id=c.id;show_page("roster")
					else:notify(app.accounts.message))
			button("back",Rect2(345,440,100,26),func():show_page("roster"),-1,-1,"返回")
		"notice","recovery_code","quit","credits":
			art("prguse",380,Vector2(272,120))
			text_at(modal_text,Rect2(292,144,214,220),14).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			if page=="recovery_code":
				var code:=input("recovery_code",Rect2(287,327,225,28));code.secret=false;code.max_length=64;code.editable=false;code.text=app.accounts.last_recovery_code
			button("confirm",Rect2(340,425,100,26),confirm_modal,-1,-1,"确认")
			if page=="quit":button("cancel",Rect2(340,386,100,26),func():show_page("login"),-1,-1,"取消")
	message=text_at("2.0.1.11 · 本机单机 · 界面还原开发版",Rect2(20,580,760,20),13)
	message.reparent(self)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.max_lines_visible=2
	message.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;message.clip_text=true
	message.mouse_filter=Control.MOUSE_FILTER_PASS
	update_layout()
	if not fields.is_empty():call_deferred("focus_first_field")
	queue_redraw()

func focus_first_field() -> void:
	if not fields.is_empty() and is_instance_valid(fields.values()[0]) and fields.values()[0].is_inside_tree():fields.values()[0].grab_focus()

func build_roster() -> void:
	var characters: Array=app.accounts.characters()
	roster_page=clampi(roster_page,0,maxi(0,(characters.size()-1)/2))
	var visible_ids: Array=[]
	for i in range(2):
		var at:=roster_page*2+i
		if at>=characters.size():
			button("select_"+str(i),Layout.SELECT[i],func():pass,-1,66+i).disabled=true
			continue
		var c: Dictionary=characters[at];portraits.append([c,i]);visible_ids.append(c.id)
		var saved: Dictionary=app.store.load_world(c.id)
		var name_label:=text_at(c.name,Layout.NAMES[i],13)
		name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name_label.tooltip_text=c.name;name_label.mouse_filter=Control.MOUSE_FILTER_PASS
		text_at(str(int(saved.get("level",1))),Layout.LEVELS[i],13)
		text_at(c.job,Layout.CLASSES[i],13)
		button("select_"+str(i),Layout.SELECT[i],func():select_character(c.id),-1,66+i,"",-1)
		button("portrait_"+str(i),Rect2(70+i*340,55,300,340),func():select_character(c.id),-1,-1,"",-1)
	if not visible_ids.has(selected_id):
		selected_id="";previous_id=""
		if not visible_ids.is_empty():select_character(visible_ids[0])
	button("enter",Layout.ROSTER.enter,enter_selected,-1,68).disabled=characters.is_empty()
	button("create",Layout.ROSTER.create,func():show_page("create"),-1,69).disabled=characters.size()>=3
	button("delete",Layout.ROSTER.delete,func():show_page("delete"),-1,70).disabled=characters.is_empty()
	button("credits",Layout.ROSTER.credits,func():
		modal_text="制作与来源说明\n\n画面与音频：你提供的热血传奇 2.0.1.11 十周年客户端。\n\n本机程序：Godot / GDScript。部分流程参考 MIT 许可的 mirgo。\n\n这是单机适配开发版，非官方客户端。"
		show_page("credits"),-1,71)
	button("logout",Layout.ROSTER.logout,func():app.accounts.current_id="";selected_id="";previous_id="";show_page("login"),-1,72)
	button("page",Rect2(525,405,180,25),func():roster_page=1-roster_page;show_page("roster"),-1,-1,"角色分页 %d/%d"%[roster_page+1,maxi(1,ceili(characters.size()/2.0))]).disabled=characters.size()<3
	button("restore",Rect2(120,405,160,25),func():show_page("restore"),-1,-1,"恢复删除角色")
	selection_effect=TextureRect.new();selection_effect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;selection_effect.material=material
	canvas.add_child(selection_effect)
	app.music_name("sellect-loop2.wav")

func select_character(id: String) -> void:
	if selected_id==id or app.accounts.character(id).is_empty():return
	previous_id=selected_id;selected_id=id;selection_time=0
	# The sound belongs to the stone animation, never to a static job/gender icon.
	app.stop_sound_id(101);app.play_sound_id(101)

func choose_job(index: int) -> void:
	if chosen_job==index:return
	chosen_job=index;clock=0;app.play_sound_id(103);update_choices()

func choose_sex(index: int) -> void:
	if chosen_sex==index:return
	chosen_sex=index;clock=0;app.play_sound_id(103);update_choices()

func update_choices() -> void:
	for i in range(3):controls["job_"+str(i)].normal_frame=55+i if chosen_job==i else -1;controls["job_"+str(i)].queue_redraw()
	for i in range(2):controls["sex_"+str(i)].normal_frame=58+i if chosen_sex==i else -1;controls["sex_"+str(i)].queue_redraw()

func build_create() -> void:
	art("prguse",73,Layout.CREATE_ORIGIN)
	input("name",Layout.create_rect(Layout.CREATE_NAME)).max_length=12
	for i in range(3):
		button("job_"+str(i),Layout.create_rect(Layout.JOBS[i]),func():choose_job(i),-1,74+i,"",-1)
	button("class_help",Layout.create_rect(Rect2(182,156,44,36)),func():notify("战士：近战与防御；法师：远程法术；道士：辅助与召唤。"),-1,-1,"",103)
	for i in range(2):
		button("sex_"+str(i),Layout.create_rect(Layout.SEXES[i]),func():choose_sex(i),-1,77+i,"",-1)
	button("difficulty",Layout.create_rect(Rect2(22,294,256,30)),func():difficulty="classic" if difficulty=="easy" else "easy";controls.difficulty.text=difficulty_text(),-1,-1,difficulty_text(),103)
	button("create_submit",Layout.create_rect(Layout.CREATE_SUBMIT),create_character)
	# This close glyph differs from Prguse 64: tint the baked glyph in place.
	button("back",Layout.create_rect(Layout.CREATE_CLOSE),func():show_page("roster"))
	text_at("选择职业与性别",Rect2(110,405,280,30),18)
	update_choices()

func difficulty_text() -> String:return "轻松：经验×3 / 金币×2" if difficulty=="easy" else "经典：经验×1 / 金币×1"

func create_character() -> void:
	if not pending_creation.is_empty() and (pending_creation.account!=app.accounts.current_id or app.accounts.character(pending_creation.id).is_empty()):pending_creation={}
	var c: Dictionary={}
	if not pending_creation.is_empty():
		c=app.accounts.character(pending_creation.id)
		if fields.name.text.strip_edges()!=c.name or LocalAccounts.JOBS[chosen_job]!=c.job or LocalAccounts.GENDERS[chosen_sex]!=c.gender:
			notify("角色「%s」已创建，初始化尚未完成；请保持原名称、职业和性别重试，或返回选角。"%c.name);return
	else:
		c=app.accounts.create_character(fields.name.text,LocalAccounts.JOBS[chosen_job],LocalAccounts.GENDERS[chosen_sex],false,difficulty)
		if c.is_empty():notify(app.accounts.message);return
		pending_creation={"account":app.accounts.current_id,"id":c.id,"preset":difficulty}
	# Attach saves the immutable preset before returning to the roster.
	if not app.rules.attach(c,pending_creation.preset):notify("角色已保留，初始化未完成："+app.rules.message+"。请再次点击创建重试。");return
	pending_creation={}
	selected_id="";previous_id="";roster_page=(app.accounts.characters().size()-1)/2
	# Start one matching revival event when the successfully saved character appears.
	select_character(c.id);show_page("roster")

func enter_selected() -> void:
	if app.accounts.character(selected_id).is_empty():notify("请先选择或创建角色");return
	modal_text="玛法 · 本机世界\n\n经典十周年画面与声音。\n当前仍为开发版本。\n\nWASD 移动，Shift 跑步\n左键寻路，右键跑动\nB 背包，P 暂停\n\n普通窗口不会暂停世界。"
	show_page("notice")

func open_door() -> void:show_page("door")
func quit_prompt() -> void:modal_text="确定退出游戏？";show_page("quit")

func confirm_modal() -> void:
	match page:
		"notice":
			app.start_character(app.accounts.character(selected_id))
			if app.mode!="game":
				var reason: String=app.pending_message
				show_page("roster");notify(reason)
		"credits":show_page("roster")
		"quit":app._notification(NOTIFICATION_WM_CLOSE_REQUEST)
		"recovery_code":app.accounts.last_recovery_code="";show_page("login")

func submit() -> void:
	if busy:return
	var id: String={"login":"login","register":"register_submit","password":"password_submit","recovery":"password_submit","create":"create_submit","roster":"enter","notice":"confirm","quit":"confirm","recovery_code":"confirm","credits":"confirm"}.get(page,"")
	# Keyboard and mouse invoke the same guarded action and its sound exactly once.
	if controls.has(id) and not controls[id].disabled:controls[id].pressed.emit()

func authenticate(kind: String) -> void:
	if busy or app.thread.is_started():return
	var user: String=fields.username.text;var password: String=fields.password.text
	var confirmation: String=fields.confirm.text if fields.has("confirm") else ""
	var old: String=fields.old.text if fields.has("old") else ""
	remember_choice=kind=="login" and controls.remember.button_pressed if kind=="login" else false
	var use_saved:=kind=="login" and password.is_empty() and user.strip_edges().to_lower()==remembered_user and not remembered_user.is_empty()
	busy=true;auth_kind=kind;notify("正在验证，请稍候…")
	for b in controls.values():b.disabled=true
	var start_error: int=app.thread.start(func():
		match kind:
			"login":return EditionRememberedLogin.login(app.accounts,user) if use_saved else app.accounts.login(user,password)
			"register":return app.accounts.register_account(user,password,confirmation)
			"recovery":return app.accounts.recover_password(user,old,password,confirmation)
		return app.accounts.change_password(user,old,password,confirmation))
	if start_error!=OK:authentication_start_failed(start_error)

func authentication_start_failed(error: int) -> void:
	busy=false
	for control in controls.values():control.disabled=false
	notify("无法启动本机账号验证，请重试（错误 %d）"%error)

func finish_auth(ok: bool) -> void:
	busy=false
	if not ok:
		for b in controls.values():b.disabled=false
		notify(app.accounts.message);return
	if auth_kind=="login":
		app.store.put_metadata("last_username",app.accounts.account().username)
		var remembered:=EditionRememberedLogin.remember(app.accounts) if remember_choice else EditionRememberedLogin.forget(app.store)
		var warning: String=app.store.error if not remembered else ""
		show_page("world")
		if not warning.is_empty():notify("登录成功，但记住设置未保存："+warning)
	elif auth_kind=="register":modal_text="账号已创建\n\n请复制并妥善保存下方恢复码。\n它只在这里显示一次。\n\n本机恢复不需要身份证或短信。";show_page("recovery_code")
	else:show_page("login");notify("密码已修改")

func update_layout() -> void:
	var viewport:=get_viewport_rect().size
	var zoom:=EditionDisplay.entry_zoom(viewport)
	canvas.scale=Vector2.ONE*zoom;canvas.position=((viewport-Vector2(800,620)*zoom)/2).floor()
	if is_instance_valid(message):
		message.scale=Vector2.ONE*zoom
		message.position=Vector2(16*zoom,viewport.y-40*zoom).floor()
		message.size=Vector2(viewport.x/zoom-32,36)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:return
	clock+=delta
	if page=="roster":selection_time+=delta
	update_layout()
	if page=="door":
		transition_time+=delta
		if transition_time>=3.0:show_page("roster")
	if page=="roster" and is_instance_valid(selection_effect):
		selection_effect.hide()
		for item in portraits:
			if item[0].id==selected_id and selection_effect_frame()>=0:
				var effect: Dictionary=app.resources.frame("chrsel",selection_effect_frame())
				if not effect.is_empty():selection_effect.texture=effect.texture;selection_effect.position=Vector2(90+int(item[1])*340,58+int(item[1])*2);selection_effect.show()
	queue_redraw()

func selection_effect_frame() -> int:
	# ChrSel 4..17 is a revival overlay, not an idle aura. Stop with the
	# 13-frame stone transition; never restart it while the character stands.
	if page!="roster" or selection_time>=REVIVAL_DURATION or selected_id.is_empty():return -1
	return 4+mini(13,int(maxf(0,selection_time)/0.05))

func portrait_frame(c: Dictionary) -> int:
	var base:=LocalAccounts.JOBS.find(c.job)*40+LocalAccounts.GENDERS.find(c.gender)*120
	if c.id==selected_id:
		if selection_time<REVIVAL_DURATION:return 60+base+mini(12,int(selection_time/0.05))
		return 40+base+int((selection_time-REVIVAL_DURATION)/0.3)%16
	if c.id==previous_id and selection_time<REVIVAL_DURATION:
		return 60+base+12-mini(12,int(selection_time/0.05))
	return 60+base

func draw_art(bank: String,index: int,at: Vector2) -> void:
	var frame: Dictionary=app.resources.frame(bank,index)
	if not frame.is_empty():draw_texture(frame.texture,at)

func _draw() -> void:
	if app==null:return
	draw_rect(get_viewport_rect(),Color("100e0b"))
	var wall: Dictionary=app.resources.frame("chrsel",22)
	if not wall.is_empty():
		var tile:=Vector2(64,600)*canvas.scale.x
		for x in range(ceili(get_viewport_rect().size.x/tile.x)):
			for y in range(ceili(get_viewport_rect().size.y/tile.y)):
				draw_texture_rect_region(wall.texture,Rect2(Vector2(x,y)*tile,tile),Rect2(0,0,64,600),Color(0.32,0.32,0.32))
	draw_set_transform(canvas.position,0,canvas.scale)
	for item in artwork:draw_art(item[0],item[1],item[2])
	if page=="register":draw_rect(Rect2(135,253,510,208),Color("171411"))
	if page=="recovery":draw_rect(Rect2(214,295,110,28),Color("171411"))
	if page=="door":draw_art("chrsel",23+mini(9,int(transition_time/0.3)),Vector2(152,96))
	for item in portraits:
		var c: Dictionary=item[0];var slot: int=item[1]
		var job_index:=LocalAccounts.JOBS.find(c.job);var sex_index:=LocalAccounts.GENDERS.find(c.gender)
		var positions: Array=[[[71,52],[65,55]],[[77,46],[171,97]],[[85,63],[164,103]]]
		var pair: Array=positions[job_index][sex_index]
		var at:=Vector2(pair[0]+slot*340,pair[1]+slot*2)
		var frame:=portrait_frame(c)
		if c.id==selected_id and selection_time>=REVIVAL_DURATION:
			if sex_index==1 and job_index==1:at+=Vector2(-30,-14)
			if sex_index==1 and job_index==2:at+=Vector2(-23,-20)
		draw_art("chrsel",frame,at)
	if page=="create":
		draw_art("chrsel",40+chosen_job*40+chosen_sex*120+int(clock/0.3)%16,Vector2(90,65))
	draw_set_transform(Vector2.ZERO)
	var footer_height:=40*canvas.scale.y
	draw_rect(Rect2(0,get_viewport_rect().size.y-footer_height,get_viewport_rect().size.x,footer_height),Color(0.035,0.028,0.022,0.92))

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or busy or not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE:
		match page:
			"create","delete","restore","notice","credits":show_page("roster")
			"login":quit_prompt()
			"door":return
			"recovery_code":confirm_modal()
			_:app.accounts.current_id="";show_page("login")
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]:submit();get_viewport().set_input_as_handled()
