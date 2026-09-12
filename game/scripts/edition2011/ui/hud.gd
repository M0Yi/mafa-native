class_name EditionHUD
extends Control
var app
var bar:=Control.new()
var blocker:=Control.new()
var extra:=HBoxContainer.new()
var anchored: Array=[]
var logical_width:=800.0
var chat:=LineEdit.new()
var messages:=RichTextLabel.new()
var displayed_revision:=-1
var attack_mode:=Button.new()
var stats:=Label.new()
var health_text:=Label.new()
var mana_text:=Label.new()
var coordinates:=Label.new()
var minimap=preload("res://scripts/edition2011/ui/minimap.gd").new()
var hp_ratio:=1.0
var mp_ratio:=1.0
var pointer_area:=Rect2()
var quest_tracker:=Button.new()
var level_text:=Label.new()

func setup(host) -> void:
	app=host;oversampling_with_scale=CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED;mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bar)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	blocker.position=Vector2(0,90);blocker.size=Vector2(800,161);bar.add_child(blocker)
	for spec in [[8,Vector2(643,61),"人物",app.show_character],[9,Vector2(682,41),"背包",app.show_bag],[10,Vector2(722,21),"技能",app.show_skills],[11,Vector2(764,11),"设置",app.show_settings],[128,Vector2(309,104),"组队",app.show_social],[130,Vector2(219,104),"地图",app.show_map_info],[134,Vector2(279,104),"行会",app.show_social],[530,Vector2(369,104),"好友",app.show_social],[136,Vector2(420,104),"返回选角",logout]]:
		var frame: Dictionary=app.resources.frame("prguse",spec[0])
		if frame.is_empty():continue
		var b:=EditionSkinButton.new();b.resources=app.resources;b.normal_frame=spec[0];b.position=spec[1];b.size=frame.size;b.tooltip_text=spec[2]
		bar.add_child(b);anchored.append([b,b.position]);b.pressed.connect(func():app.play_sound_id(105);spec[3].call())
	for i in range(6):
		var b:=EditionQuickSlot.new();b.app=app;b.index=i;b.text=str(i+1);b.position=Vector2(283+i*43,55);b.size=Vector2(36,32);b.tooltip_text="快捷物品 "+str(i+1)
		bar.add_child(b);anchored.append([b,b.position]);b.pressed.connect(func():use_quick(i))
	var chat_style:=StyleBoxFlat.new();chat_style.bg_color=Color("10100e");chat_style.content_margin_left=3;chat_style.content_margin_top=0;chat_style.content_margin_bottom=0
	for state in ["normal","focus","read_only"]:chat.add_theme_stylebox_override(state,chat_style)
	chat.add_theme_font_size_override("font_size",12)
	chat.position=Vector2(207,229);chat.size=Vector2(388,21);chat.placeholder_text="本地聊天 · Enter 发送";chat.max_length=200;bar.add_child(chat)
	chat.text_submitted.connect(func(value):
		if not value.strip_edges().is_empty():
			app.append_chat(app.rules.character.name,value)
			chat.clear();chat.release_focus())
	messages.position=Vector2(209,121);messages.size=Vector2(382,103);messages.bbcode_enabled=false;messages.scroll_following=true;messages.selection_enabled=true;messages.add_theme_font_size_override("font_size",12);messages.mouse_filter=Control.MOUSE_FILTER_STOP;bar.add_child(messages)
	for spec in [[health_text,Vector2(37,126),Vector2(61,40),10],[mana_text,Vector2(100,126),Vector2(61,40),10],[stats,Vector2(17,203),Vector2(175,21),12],[coordinates,Vector2(17,228),Vector2(175,20),12]]:
		var label: Label=spec[0];label.position=spec[1];label.size=spec[2]
		label.add_theme_font_size_override("font_size",spec[3]);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color",Color("151310"));label.add_theme_constant_override("outline_size",3)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(label)
	stats.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	level_text.add_theme_font_size_override("font_size",11);level_text.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(level_text)
	extra.position=Vector2(12,80);add_child(extra)
	for item in [["新手村",app.show_village_map],["任务",app.show_quests],["内功·经脉",app.show_training],["内挂",app.gameplay.show_assist],["加点/商店",app.gameplay.show_utilities]]:
		var b:=Button.new();b.text=item[0];extra.add_child(b);b.pressed.connect(item[1])
	attack_mode.pressed.connect(app.gameplay.cycle_attack_mode);extra.add_child(attack_mode)
	quest_tracker.position=Vector2(12,102);quest_tracker.add_theme_font_size_override("font_size",EditionDisplay.BODY_POINTS);add_child(quest_tracker)
	quest_tracker.pressed.connect(app.navigate_tracked_quest)
	add_child(minimap);minimap.setup(app)

func logout() -> void:
	app.windows.confirm("保存进度并返回选角？",func():
		if app.save_world():app.show_roster())

func use_quick(index: int) -> void:
	if app.world.paused or app.rules.state.hp<=0:return
	var ids: Array=app.rules.state.get("quickbar",["potion","mana","","","",""])
	if index>=ids.size() or str(ids[index]).is_empty():app.pending_message="这个快捷栏尚未绑定物品";return
	app.gameplay.use_type(ids[index])

func blocks_pointer() -> bool:
	var point:=get_global_mouse_position()
	if minimap.get_global_rect().has_point(point):return true
	if pointer_area.has_point(point) or extra.get_global_rect().has_point(point) or quest_tracker.get_global_rect().has_point(point):return true
	for item in anchored:
		if item[0].get_global_rect().has_point(point):return true
	return false

func _process(delta: float) -> void:
	if app==null or app.mode!="game":return
	attack_mode.text=EditionCombat.MODES.get(app.rules.state.get("attack_mode","peace"),"和平")+" [T]"
	attack_mode.tooltip_text="切换和平 / 编组 / 行会 / 全体 / 红名模式；安全区禁止攻击"
	if displayed_revision!=app.chat_revision:
		displayed_revision=app.chat_revision;messages.text="\n".join(app.chat_history)
	var screen:=get_viewport_rect().size
	var zoom:=EditionDisplay.ui_zoom(screen,app.windows.requested_scale,app.display_density)
	logical_width=screen.x/zoom
	bar.scale=Vector2.ONE*zoom;bar.position=Vector2(0,screen.y-251*zoom).floor()
	blocker.size=Vector2(logical_width,161)
	pointer_area=Rect2(bar.position+Vector2(0,90)*zoom,Vector2(screen.x,161*zoom))
	for item in anchored:item[0].position=Vector2(EditionDisplay.hud_x(item[1].x,logical_width),item[1].y)
	chat.size.x=logical_width-412;messages.size.x=logical_width-418
	extra.scale=Vector2.ONE*zoom;extra.position=Vector2(12,64)*zoom
	quest_tracker.scale=Vector2.ONE*zoom;quest_tracker.position=Vector2(12,102)*zoom
	var q:=EditionVillage.current(app.rules.state)
	var story_text: String=EditionRules.Story.tracker_text(app.rules.state)
	quest_tracker.text=story_text if not story_text.is_empty() else ("查看玛法故事与委托" if q.is_empty() else q.title+" · "+EditionVillage.progress(app.rules.state,q))
	quest_tracker.tooltip_text=quest_tracker.text
	quest_tracker.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_tracker.custom_minimum_size.x=0;quest_tracker.size.x=minf(540,screen.x/zoom-24)
	hp_ratio=move_toward(hp_ratio,float(app.rules.state.hp)/app.rules.max_hp(),delta*3)
	mp_ratio=move_toward(mp_ratio,float(app.rules.state.mp)/app.rules.max_mp(),delta*3)
	health_text.text="生命\n%d/%d"%[app.rules.state.hp,app.rules.max_hp()]
	mana_text.text="魔法\n%d/%d"%[app.rules.state.mp,app.rules.max_mp()]
	stats.text=str(app.world.metadata.get("name",""))
	coordinates.text="坐标 %d, %d"%[app.world.player.cell.x,app.world.player.cell.y]
	level_text.position=Vector2(EditionDisplay.hud_x(666,logical_width),147);level_text.text=str(int(app.rules.state.level))
	queue_redraw()

func strip_rect(ratio: float,y: float) -> Rect2:
	var strip: Dictionary=app.resources.frame("prguse",7)
	if strip.is_empty():return Rect2()
	return Rect2(EditionDisplay.hud_x(666,logical_width),y,floorf(strip.size.x*clampf(ratio,0,1)),strip.size.y)

func draw_strip(ratio: float,y: float) -> void:
	var rect:=strip_rect(ratio,y)
	if not rect.has_area():return
	var strip: Dictionary=app.resources.frame("prguse",7)
	# UI frame offsets are archive metadata, not placement offsets. Reference
	# uihud.go crops frame 7 at (666,527/560), relative to the 349px HUD origin.
	draw_texture_rect_region(strip.texture,rect,Rect2(Vector2.ZERO,rect.size))

func draw_frame(index: int,at: Vector2) -> void:
	var frame: Dictionary=app.resources.frame("prguse",index)
	if not frame.is_empty():draw_texture(frame.texture,at)

func _draw() -> void:
	if app==null or app.mode!="game":return
	var screen:=get_viewport_rect().size
	draw_rect(Rect2(0,screen.y-131*bar.scale.y,screen.x,131*bar.scale.y),Color("11100e"))
	draw_set_transform(bar.position,0,bar.scale)
	var background: Dictionary=app.resources.frame("prguse",1)
	if not background.is_empty():
		# Keep the orb and right-hand buttons at their native aspect ratio.
		draw_texture_rect_region(background.texture,Rect2(0,0,207,251),Rect2(0,0,207,251))
		draw_texture_rect_region(background.texture,Rect2(logical_width-200,0,200,251),Rect2(600,0,200,251))
		# Separate the movable quick-slot ornament from the chat frame. The old
		# 8px sample repeated a blue highlight, then overlaid a second full frame.
		# This broad, undecorated stone span preserves texture scale and excludes
		# corner bevels. Crop the final repeat instead of stretching it.
		for x in range(207,int(ceil(logical_width-200)),160):
			var width:=minf(160,logical_width-200-x)
			# Alternate direction so adjacent strips share identical edge pixels.
			if ((x-207)/160)%2==1:
				draw_set_transform(bar.position+Vector2((x+width)*bar.scale.x,0),0,Vector2(-bar.scale.x,bar.scale.y))
				draw_texture_rect_region(background.texture,Rect2(0,93,width,158),Rect2(580-width,93,width,158))
				draw_set_transform(bar.position,0,bar.scale)
			else:draw_texture_rect_region(background.texture,Rect2(x,93,width,158),Rect2(420,93,width,158))
		draw_texture_rect_region(background.texture,Rect2(EditionDisplay.hud_x(207,logical_width),0,393,93),Rect2(207,0,393,93))
	draw_rect(Rect2(207,119,logical_width-412,112),Color("0b0b0b"))
	var frame: Dictionary=app.resources.frame("prguse",4)
	if not frame.is_empty():
		var half:=int(frame.size.x/2)
		for i in range(2):
			var ratio:=hp_ratio if i==0 else mp_ratio
			var crop:=roundf(frame.size.y*(1-clampf(ratio,0,1)))
			var rect:=Rect2(i*(half+1),crop,half-2,frame.size.y-crop)
			if rect.size.y>0:draw_texture_rect_region(frame.texture,Rect2(Vector2(40+i*(half+1),91+crop),rect.size),rect)
	var xp:=clampf(float(app.rules.state.xp)/(int(app.rules.state.level)*100),0,1)
	draw_strip(xp,178)
	draw_strip(float(app.rules.weight(app.rules.state))/(100+int(app.rules.state.level)*5),211)
	draw_set_transform(Vector2.ZERO)
