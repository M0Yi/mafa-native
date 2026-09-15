extends Node2D

signal sound_started(id: int)
signal music_started(track: String)
var music_track:=""

var configure_native_window:=true
var windowed_size:=Vector2i.ZERO
var display_density:=1.0
var manage_native_window:=false

var resources:=EditionResources.new()
var task_marker_key:=""
var store:=EditionStore.new()
var accounts:=EditionAccounts.new()
var rules:=EditionRules.new()
var world:=EditionWorld.new()
var layer:=CanvasLayer.new()
var ui:=Control.new()
var hud:=Control.new()
var panel: Control
var form: VBoxContainer
var fields: Dictionary={}
var notice: Label
var status: Label
var music:=AudioStreamPlayer.new()
var effects: Array[AudioStreamPlayer]=[]
var effect_index:=0
var mode:="login"
var overlay:=""
var elapsed:=0.0
var save_elapsed:=0.0
var ai_elapsed:=0.0
var fight_timer:=0.0
var pending_attack: Dictionary={}
var selected: Dictionary={}
var selected_item_uid:=""
var font: Font=preload("res://fonts/NotoSansCJKsc-Regular.otf")
var job:="战士"
var gender:="男"
var preset:="easy"
var thread:=Thread.new()
var auth_action:=""
var muted:=false
var chat_history: Array[String]=[]
var chat_revision:=0
var pending_message:="":
	set(value):
		pending_message=value
		if mode=="game" and not value.is_empty():append_chat("系统",value)

func append_chat(channel: String,text: String) -> void:
	chat_history.append("[%s] %s"%[channel,text.replace("\n"," ")])
	while chat_history.size()>200:chat_history.pop_front()
	chat_revision+=1

var automation:=""
var capture_path:=""
var capture_frames:=0
var portrait: TextureRect
var entry:=EditionEntry.new()
var windows:=EditionWindows.new()
var classic_hud: Control
var fire_dragon:=EditionFireDragon.new()
var cook_trials=preload("res://scripts/edition2011/cook_trials.gd").new()
var dark_temple=preload("res://scripts/edition2011/dark_temple.gd").new()
var gameplay:=EditionGameplay.new()
var sound_levels: Dictionary={}
var death_return_at:=-1.0
var allow_focus_pause:=true
var benchmark_seconds:=0.0
var benchmark_elapsed:=0.0
var benchmark_sample:=0.0
var benchmark_samples: Array=[]
var benchmark_output:=""
var changing_map:=false
var region:=EditionRegion.new()

func _ready() -> void:
	fire_dragon.setup(self)
	dark_temple.setup(self)
	cook_trials.setup(self)
	get_tree().auto_accept_quit=false
	world.font=font
	var theme:=Theme.new();theme.default_font=font;theme.default_font_size=16
	ui.theme=theme;hud.theme=theme
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--isolated-check="):
			var path:=arg.trim_prefix("--isolated-check=")
			if path.is_absolute_path():store.path=path
		if arg.begins_with("--benchmark-seconds="):benchmark_seconds=float(arg.trim_prefix("--benchmark-seconds="));allow_focus_pause=false
		if arg.begins_with("--benchmark-output="):benchmark_output=arg.trim_prefix("--benchmark-output=")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("30271b") if state_name=="normal" else Color("53452e")
		style.border_color=Color("867044");style.set_border_width_all(1)
		style.content_margin_left=9;style.content_margin_right=9;style.content_margin_top=5;style.content_margin_bottom=5
		theme.set_stylebox(state_name,"Button",style)
	add_child(layer);layer.add_child(hud);layer.add_child(ui)
	layer.add_child(windows);windows.setup(self)
	layer.add_child(entry)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(music);music.volume_db=-12
	music.finished.connect(func():if music.stream!=null:music.play())
	for _i in range(12):
		var sound:=AudioStreamPlayer.new();sound.volume_db=-10;add_child(sound);effects.append(sound)
	if not resources.initialize():fatal("资源目录不完整："+str(resources.errors));return
	var story_errors: Array[String]=preload("res://scripts/edition2011/story_catalog.gd").validate(JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/world-story.json")),EditionRules.ITEMS,resources.map_by_id)
	if not story_errors.is_empty():fatal("任务目录错误：\n"+"\n".join(story_errors));return
	if not store.open():fatal(store.error);return
	initialize_sound_buses()
	world.preferred_zoom=clampi(int(store.read_metadata("zoom")),0,6) if not store.read_metadata("zoom").is_empty() else 0
	muted=store.read_metadata("muted")=="true"
	accounts.store=store;rules.store=store
	rules.story_progressed.connect(func(text):append_chat("任务",text))
	rules.item_performed.connect(func(type,event):play_sound_id(EditionItemAudio.sound(type,event),0,"Interface"))
	if not accounts.load_database():fatal(accounts.message);return
	world.resources=resources;add_child(world);move_child(world,0);world.visible=false
	gameplay.setup(self);world.add_child(gameplay)
	world.clicked_entity.connect(interact)
	world.moved.connect(func(_cell):play_sound_id(1+world.player.completed_steps%2))
	world.player.route_blocked.connect(func(_cell):pending_message="前方被阻挡，已停止寻路；请等待让路后再次选择任务目标，或手动绕行。")
	world.actor_sound.connect(play_actor_sound)
	world.monster_hit_traveler.connect(func(target,attack):
		if world.paused or target not in world.entities or EditionRegion.safe(world.metadata.id,Vector2i(target.cell[0],target.cell[1])):return
		gameplay.hit_traveler(target,attack))
	world.monster_hit.connect(func(_entity,damage):
		if not gameplay.available() or EditionRegion.safe(world.metadata.id,world.player.cell):return
		if not rules.receive_damage(rules.incoming_monster_damage(damage,bool(_entity.get("magic_attack",false)),elapsed),bool(_entity.get("green_poison",false)),elapsed,bool(_entity.get("stone",false))):pending_message=rules.message;return
		if rules.stoned(elapsed):
			pending_attack.clear();world.player.route.clear()
			gameplay.spell_events.clear();gameplay.visuals.clear();gameplay.skill_effects.clear();gameplay.queue_redraw()
		pending_message=rules.message;world.animate("die" if rules.state.hp<=0 else "hurt")
		play_sound_id((144 if world.gender=="男" else 145) if rules.state.hp<=0 else (138 if world.gender=="男" else 139))
		if rules.state.hp<=0:world.player.route.clear();pending_attack.clear();gameplay.ensure_death())
	entry.setup(self)
	windows.requested_scale=int(store.read_metadata("ui_scale"))
	setup_display()
	if OS.get_cmdline_user_args().has("--check-package"):
		for pair in [["chrsel",40],["hum",0],["tiles",100],["npc",0],["cbohum_wis",0],["smtiles2",1120],["smtiles",1209]]:resources.frame(pair[0],pair[1])
		for name in ["log-in-long2.wav","sellect-loop2.wav","field2.wav","1.wav","50.wav","100.wav","m11-1.wav"]:resources.sound(name)
		var legacy:=FileAccess.file_exists("res://assets/generated/manifest.json")
		print(JSON.stringify({"package_check":true,"resource_errors":resources.errors,"maps":resources.maps.size(),"legacy_assets_present":legacy,"architecture":Engine.get_architecture_name()}))
		quit_application(0 if resources.errors.is_empty() and not legacy else 1)
		return
	var preview_cell:=Vector2i(-1,-1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--edition-cell="):
			var parts:=arg.trim_prefix("--edition-cell=").split(",")
			if parts.size()==2:preview_cell=Vector2i(int(parts[0]),int(parts[1]))
		if arg.begins_with("--capture-path="):capture_path=arg.trim_prefix("--capture-path=")
		if arg.begins_with("--edition-map="):
			automation=arg.trim_prefix("--edition-map=")
	if not automation.is_empty():
		var fake={"id":"visual-check","name":"地图检查","job":"战士","gender":"男"}
		rules.character=fake;rules.state=rules.new_world(fake,"easy");EditionInventory.migrate(rules.state);mode="game";entry.hide();world.visible=true;elapsed=0
		enter_map(automation,preview_cell);build_hud();close_panel()

func setup_display() -> void:
	if not configure_native_window or DisplayServer.get_name()=="headless":return
	# Deterministic captures/tests explicitly choose their own framebuffer size.
	if OS.get_cmdline_args().has("--write-movie") or OS.get_cmdline_args().has("--resolution"):return
	var density:=maxf(1,DisplayServer.screen_get_scale())
	var usable:=DisplayServer.screen_get_usable_rect()
	var stored: String=store.read_metadata("display:window_points")
	var raw=JSON.parse_string(stored) if not stored.is_empty() else null
	var saved:=Vector2.ZERO
	if raw is Array and raw.size()==2:saved=Vector2(float(raw[0]),float(raw[1]))
	var win:=get_window()
	win.mode=Window.MODE_WINDOWED
	win.min_size=Vector2i((EditionDisplay.BASE_UI*density).min(Vector2(usable.size)-Vector2(40,64)*density))
	win.size=EditionDisplay.window_pixels(Vector2(usable.size),density,saved)
	win.position=usable.position+(usable.size-win.size)/2
	windowed_size=win.size;display_density=density;manage_native_window=true

func update_display_density() -> void:
	if not manage_native_window:return
	var density:=maxf(1,DisplayServer.screen_get_scale())
	if is_equal_approx(density,display_density):return
	var win:=get_window();var usable:=DisplayServer.screen_get_usable_rect()
	var points:=Vector2(win.size)/display_density
	win.min_size=Vector2i((EditionDisplay.BASE_UI*density).min(Vector2(usable.size)-Vector2(40,64)*density))
	if win.mode==Window.MODE_WINDOWED:
		win.size=EditionDisplay.window_pixels(Vector2(usable.size),density,points)
		win.position=win.position.clamp(usable.position,usable.end-win.size)
		windowed_size=win.size
	elif windowed_size!=Vector2i.ZERO:
		windowed_size=EditionDisplay.window_pixels(Vector2(usable.size),density,Vector2(windowed_size)/display_density)
	display_density=density

func save_display_settings() -> void:
	if not manage_native_window or not store.opened:return
	var pixels:=get_window().size if get_window().mode==Window.MODE_WINDOWED else windowed_size
	if pixels==Vector2i.ZERO:return
	var density:=maxf(1,DisplayServer.screen_get_scale())
	store.put_metadata("display:window_points",JSON.stringify([pixels.x/density,pixels.y/density]))

func toggle_fullscreen() -> void:
	var win:=get_window()
	if win.mode==Window.MODE_WINDOWED:
		windowed_size=win.size;win.mode=Window.MODE_FULLSCREEN
	else:
		win.mode=Window.MODE_WINDOWED
		if windowed_size!=Vector2i.ZERO:win.size=windowed_size

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and mode=="game" and allow_focus_pause and DisplayServer.get_name()!="headless":windows.pause("focus")
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_display_settings()
		if mode=="game" and automation.is_empty() and not save_world():return
		if thread.is_started():thread.wait_to_finish()
		if store.opened and not store.backup():info(store.error);return
		store.close();quit_application()

func reset_panel(title: String) -> void:
	for child in ui.get_children():ui.remove_child(child);child.queue_free()
	fields.clear()
	panel=PanelContainer.new();panel.position=Vector2(0,0);panel.custom_minimum_size=Vector2(490,0)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.07,0.055,0.035,0.96);style.border_color=Color(0.48,0.36,0.18);style.set_border_width_all(2);style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=18;style.content_margin_bottom=18
	panel.add_theme_stylebox_override("panel",style);ui.add_child(panel)
	form=VBoxContainer.new();form.add_theme_constant_override("separation",9);panel.add_child(form)
	var label:=Label.new();label.text=title;label.add_theme_font_size_override("font_size",25);label.modulate=Color(0.9,0.76,0.48);form.add_child(label)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size=Vector2(440,0);notice.modulate=Color(0.85,0.76,0.57);form.add_child(notice)
	if mode=="game":world.player.route.clear()

func info(text: String) -> void:
	if is_instance_valid(notice):notice.text=text
	pending_message=text

func label(text: String) -> Label:
	var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.custom_minimum_size.x=0;form.add_child(node);return node

func button(text: String,callback: Callable,parent: Node=null) -> Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=27;b.add_theme_font_size_override("font_size",14);b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.tooltip_text=text
	if mode=="game":
		for state_name in ["normal","focus"]:b.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
		for state_name in ["hover","pressed"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color(0.65,0.5,0.2,0.18);b.add_theme_stylebox_override(state_name,style)
		b.add_theme_color_override("font_color",Color("e8d9b2"))
	(parent if parent!=null else form).add_child(b)
	b.pressed.connect(func():
		if not b.is_inside_tree() or b.is_queued_for_deletion() or b.disabled:return
		play_sound_id(105 if mode=="game" else 104)
		var owner_window: Node=b
		while owner_window!=null and not owner_window is EditionWindow:owner_window=owner_window.get_parent()
		if owner_window is EditionWindow:windows.activate(owner_window.window_id)
		callback.call())
	return b

func field(key: String,title: String,secret: bool=false) -> LineEdit:
	var f:=LineEdit.new();f.placeholder_text=title;f.secret=secret;f.custom_minimum_size.y=36;fields[key]=f;form.add_child(f);return f

func music_name(name: String) -> void:
	if music_track==name and music.playing:return
	music_track=name
	music.stop();music.bus="Music";music.stream=resources.sound(name)
	if music.stream!=null and not muted:music.play();music_started.emit(name)

func play_actor_sound(id: int,at: Vector2,event: String) -> void:
	var distance:=at.distance_to(world.player.anchor)/48.0
	if distance>12:return
	play_sound_id(id,-minf(28,distance*2.0)-(8 if event=="idle" else 0),"Environment" if event in ["idle","appear"] else "Combat")

func play_sound_id(id: int,attenuation:=0.0,bus_override:="") -> void:
	if muted:return
	var stream:=resources.sound_id(id)
	if stream==null:return
	var player: AudioStreamPlayer=effects[effect_index%effects.size()];effect_index+=1;player.volume_db=-10+attenuation;player.stream=stream;player.bus=bus_override if not bus_override.is_empty() else ("Interface" if id>=100 and id<=118 else ("Environment" if id in [1,2] else "Combat"));player.play();sound_started.emit(id)

func stop_sound_id(id: int) -> void:
	var stream:=resources.sound_id(id)
	for player in effects:
		if player.stream==stream:player.stop()

func show_login() -> void:
	windows.close_all();entry.show_page("login")

func show_register() -> void:
	windows.close_all();entry.show_page("register")

func show_password() -> void:
	windows.close_all();entry.show_page("password")


func show_roster() -> void:
	windows.close_all();entry.show_page("roster")

func show_create() -> void:
	windows.close_all();entry.show_page("create")

func start_character(c: Dictionary) -> void:
	var previous_character: String=str(rules.character.get("id",""))
	if not rules.attach(c,preset):info(rules.message);return
	if rules.state.hp<=0:
		var zone:=EditionRegion.revival_zone(str(rules.state.map),Vector2i(rules.state.cell[0],rules.state.cell[1]),resources.connections.by_map)
		if zone.is_empty():info("找不到可达的城市安全区，角色存档已保留");return
		if not world.enter_map(str(zone.map),Vector2i(zone.cell[0],zone.cell[1])):info("复活城市无法载入，请重试");return
		var landing:=Vector2i(-1,-1)
		var center:=Vector2i(zone.cell[0],zone.cell[1])
		var npcs: Array=resources.npcs_by_map.get(zone.map,[])
		var best:=INF
		for y in range(center.y-int(zone.radius),center.y+int(zone.radius)+1):
			for x in range(center.x-int(zone.radius),center.x+int(zone.radius)+1):
				var point:=Vector2i(x,y)
				if not world.navigation.mobile(point) or resources.connections.current.has(point) or npcs.any(func(n):return Vector2i(n.cell[0],n.cell[1])==point):continue
				if resources.connections.landing_cells.get(zone.map,[]).has(point):continue
				var distance:=point.distance_squared_to(center)
				if distance<best:best=distance;landing=point
		if landing==Vector2i(-1,-1):info("城市安全区没有可用落点，请重试");return
		if not rules.revive_on_entry(str(zone.map),landing):info(rules.message);return
	windows.close_all();selected_item_uid="";warehouse_keeper={}
	if previous_character!=str(c.id):
		fight_timer=0.0;ai_elapsed=0.0;save_elapsed=0.0;pending_message=""
		gameplay.potion_ready=0.0;gameplay.pending_pickup="";gameplay.pickup_retry_left=0.0
		gameplay.assist_left=0.0;gameplay.active_assist=false;gameplay.origin_map=""
	chat_history.assign(rules.state.get("chat_log",[]));chat_revision+=1
	gameplay.clear_death()
	entry.hide();world.paused=false;world.gender=c.gender;mode="game";world.visible=true;elapsed=float(rules.state.time)
	var cell:=Vector2i(rules.state.cell[0],rules.state.cell[1])
	if not enter_map(rules.state.map,cell):fatal("地图无法载入："+rules.state.map);return
	if rules.state.hp<=0:gameplay.ensure_death();world.animate("die")
	build_hud();close_panel()

func enter_map(id: String,cell:=Vector2i(-1,-1),record_arrival:=true) -> bool:
	var previous_map: String=world.metadata.get("id","")
	var previous_entities: Array=world.entities
	if cell==Vector2i(-1,-1):cell=EditionRegion.destination(id)
	if not world.enter_map(id,cell):return false
	pending_attack.clear();gameplay.spell_events.clear();gameplay.visuals.clear();gameplay.skill_effects.clear();gameplay.queue_redraw();death_return_at=-1
	region.reset({"entities":previous_entities})
	world.elapsed=elapsed;world.player_alive=rules.state.get("hp",1)>0;world.player_poison_until=float(rules.state.get("green_poison",{}).get("until",0))
	selected={}
	var spots: Array=world.metadata.service_spots
	world.entities=resources.npcs_by_map.get(id,[]).duplicate(true)
	if id=="0":
		for npc in EditionVillage.entities():
			if npc.get("service")=="village_quests":npc.name="边界村长";world.entities.append(npc)
	world.register_npc_collision()
	pending_message="已进入"+world.zone_name()
	# Detailed missing-frame diagnostics remain available in map information.
	# Small interiors are service spaces; the old universal encounter loop put
	# forest monsters inside every shop and could obstruct its only doorway.
	region.populate(world,rules,0,elapsed)
	if id=="0":world.entities.append_array(EditionVillage.travelers())
	else:world.entities.append({"id":"traveler:yunyouke","kind":"traveler","name":"云游客","bank":"hum","gender":"男","equipment":{"armor":"robe","weapon":"wood_sword"},"cell":spots[2].duplicate(),"origin":spots[2].duplicate()})
	if id!="0":
		for traveler in EditionVillage.travelers():
			if traveler.name in rules.state.party and traveler.name!="云游客":world.entities.append(traveler)
	for entity in world.entities.duplicate():
		if entity.kind not in ["traveler","monster"]:continue
		if entity.kind=="traveler" and entity.name in rules.state.party:
			var companion_cell:=world.actors.party_landing()
			if companion_cell==Vector2i(-1,-1):
				world.entities.erase(entity);pending_message+=" · 同行成员暂候：附近没有安全落脚格";continue
			entity.cell=[companion_cell.x,companion_cell.y]
		var at: Vector2i=world.actors.traveler_landing(Vector2i(entity.cell[0],entity.cell[1]),entity.id) if entity.kind=="traveler" and entity.name not in rules.state.party else world.actors.landing(Vector2i(entity.cell[0],entity.cell[1]))
		if at==Vector2i(-1,-1):world.entities.erase(entity);pending_message+=" · 旅人暂候：附近没有不挡路的落脚格";continue
		entity.cell=[at.x,at.y]
		entity.origin=entity.cell.duplicate()
		world.actors.mover(entity)
		if entity.kind=="monster":world.actors.sound(entity,"appear")
	gameplay.sync_travelers(false)
	music_name("field2.wav")
	if record_arrival and previous_map!=id and not rules.story_arrival(id):pending_message=rules.message
	return true

func story_npc_button(npc: Dictionary) -> void:
	for q in EditionRules.Story.data().quests:
		if EditionRules.Story.involves_npc(rules.state,q,npc.id):
			button("故事与委托",func():show_story(npc))
			return

func show_story(npc: Dictionary={}) -> void:
	if not npc.is_empty():
		windows.close(str(npc.get("name","")))
		if npc.get("id","")=="border:elder":windows.close("边界村长 · 单机任务")
	game_panel("玛法故事与委托",Vector2(620,460))
	var view=load("res://scripts/edition2011/ui/story_panel.gd").new();form.add_child(view);view.setup(self,npc)

func show_quest_entry(id: String) -> void:
	if not EditionRules.Story.quest(id).is_empty():
		show_story()
		var view=form.get_child(1);view.selected=id
		if rules.state.quests.get(id)=="done":view.select_status(3)
		else:view.refresh()
		return
	if not EditionVillage.quest(id).is_empty():
		show_adventure(4)
		var adventure=windows.windows["冒险面板"].body.get_child(1)
		var view=adventure.content[4];view.tab=0;view.selected=id;view.show_completed=rules.state.quests.get(id)=="done";view.refresh()
		view.details.get_parent().set_deferred("scroll_vertical",0)
		return
	info("任务记录不存在，请重新打开任务列表")

func navigate_tracked_quest() -> void:
	var q: Dictionary=EditionRules.Story.tracked(rules.state)
	if q.is_empty():
		if EditionVillage.current(rules.state).is_empty():show_story()
		else:navigate_village_objective()
		return
	if EditionRules.Story.ready(rules.state,q):approach_story_npc(q.end_npc);return
	var objective: Dictionary=EditionRules.Story.next_objective(rules.state,q)
	if EditionRules.Story.navigable(objective):approach_story_objective(objective)
	else:
		show_story()
		var view=form.get_child(1);view.selected=q.id;view.refresh()

func show_story_skill(objective: Dictionary) -> void:
	var skill: String=objective.get("skills_by_job",{}).get(rules.character.job,"")
	if not objective.has("skills_by_job"):skill=EditionRules.Story.skill_suggestion(rules.state,rules.character.job).get("skill","")
	if skill.is_empty() or EditionSkills.DEFINITIONS.get(skill,{}).get("job","")!=rules.character.job:
		info("此技能目标不适用于当前职业");return
	if get_viewport().gui_is_dragging():info("请先完成物品拖动，再查看技能");return
	show_adventure(3)
	var journal=windows.windows["冒险面板"].body.get_child(1)
	var skills=journal.content[3]
	skills.filter=0;skills.selected=skill;skills.refresh()

func show_story_book_hunt(objective: Dictionary) -> void:
	game_panel("技能书掉落来源",Vector2(540,430))
	var view=load("res://scripts/edition2011/ui/book_hunt.gd").new()
	form.add_child(view);view.setup(self,objective)

func story_transport(target_map: String) -> Dictionary:
	if target_map=="m001" and world.metadata.id!="m001":
		return {"title":"未知暗殿入口","text":"连接通道的老人可免费送你入殿，三小时后返回出发处；暂停和退出期间不计时。请到老人身边办理。","button":"前往暗殿老人","npc":"server:merchant:103"}
	var demon_maps: Array=["6","61","62","611","612","613","621","622","63","631","632","64","65","66"]
	if target_map in demon_maps and world.metadata.id not in demon_maps:
		return {"title":"魔龙城传送路线","text":"苍月的远古比奇传送石可前往魔龙城：40级免费，36级起20000金币，也可支付200000金币进入。请到人物身边选择符合条件的路线。","button":"前往苍月传送石","npc":"server:npc:13"}
	if target_map=="5" and world.metadata.id!="5":
		var returning: bool=world.metadata.id in demon_maps
		return {"title":"苍月岛交通","text":"魔龙城的传送石可免费返回苍月。" if returning else "比奇海边老人可收取2000金币送往苍月；需要到人物身边办理。","button":"前往返程传送石" if returning else "前往海边老人","npc":"server:npc:14" if returning else "server:npc:8"}
	if target_map in ["d2081","d2082"] and world.metadata.id not in ["d2081","d2082"]:
		return {"title":"雷炎洞穴入口","text":"魔龙之脑可消耗一枚龙鳞送你进入一层。龙鳞须从地面拾取；火龙任务的鳞片凭证不能代替。返程请预备回城石；苍月的远古比奇传送石可按等级与金币条件送往魔龙城。","button":"前往魔龙之脑","npc":"server:npc:18"}
	return {}

func show_story_route(target_map: String,target_npc: Dictionary={}) -> void:
	if world.metadata.id==EditionFireDragon.MAP and target_map!=EditionFireDragon.MAP:
		game_panel("火龙神殿返程")
		panel.enable_button_navigation()
		label("先找神殿接引员返回盟重安全区，再点击任务追踪前往交付人物。接引员返回不收费；再次入殿仍需勘察凭证。")
		button("步行前往神殿接引员",func():
			if world.metadata.id!=EditionFireDragon.MAP:info("地图已经变化，请重新查看任务追踪。");return
			if not gameplay.available():info("请继续游戏后前往接引员。");return
			if world.approach(EditionFireDragon.GUARD_CELL):
				windows.close_all();pending_message="正在前往神殿接引员；靠近后与他交谈，选择返回盟重安全区。"
			else:info("到接引员的道路暂时受阻，请调整位置后重试。"))
		return
	var transport: Dictionary=story_transport(target_map)
	if not transport.is_empty():
		game_panel(transport.title)
		panel.enable_button_navigation()
		label(transport.text)
		button(transport.button,func():approach_story_npc(transport.npc))
		return
	if target_map==EditionFireDragon.MAP:
		if world.metadata.id!="3":
			show_story_route("3");info("先到盟重传送员处办理火龙凭证，再使用神殿入口。");return
		game_panel("火龙神殿入口")
		panel.enable_button_navigation()
		label("火龙任务需由盟重传送员办理凭证和进入；任务路线不会代替凭证费用。")
		button("前往盟重传送员",func():approach_story_npc(EditionFireDragon.ENTRANCE))
		return
	if not resources.map_by_id.has(target_map):info("目标地图未登记");return
	var source_map: String=world.metadata.id
	var planner=preload("res://scripts/edition2011/story_routes.gd")
	var components: Array=[] if target_npc.is_empty() else planner.npc_components(resources,target_npc)
	var steps: Array=[]
	if target_npc.is_empty() or not components.is_empty():steps=planner.plan(resources.connections.by_map,source_map,target_map,world.player.cell,world.navigation,components)
	game_panel("任务远行路线",Vector2(540,420))
	panel.enable_button_navigation()
	label("目的地："+str(resources.map_by_id[target_map].name))
	if steps.is_empty():
		label("当前位置没有查到可步行连接的路线。可向当地传送员询问；传送仍按原条件和费用办理。")
		button("查看本区传送员与出入口",show_region_info);return
	label("共 %d 段通路。每次换图后点击任务追踪，重新确认下一段。"%steps.size())
	var first: Dictionary=steps[0]
	button("步行到下一入口："+str(resources.map_by_id[first.target_map].name),func():
		if world.metadata.id!=source_map:info("地图已经变化，请重新查看任务路线");return
		var at:=Vector2i(first.cell[0],first.cell[1])
		if world.player.cell==at:info("你在门槛上，请先离开一格，再走回入口。");return
		if world.approach(at):windows.close_all();pending_message="正在前往下一入口："+str(resources.map_by_id[first.target_map].name)
		else:info("当前位置到入口的道路受阻，请重新查看路线。"))
	for index in range(steps.size()):
		var route: Dictionary=steps[index]
		label("%d. %s → %s%s"%[index+1,resources.map_by_id[route.map].name,resources.map_by_id[route.target_map].name," · 原入口坐标适配" if route.kind=="reference_adjusted" else " · 单机补建通路" if route.kind!="reference" else ""])
	label("路线仅使用现有步行出入口；首段可达性已检查，后续需实际经过。不会免费传送或自动攻击。")

func show_story_stored_material(objective: Dictionary) -> bool:
	var item: String=str(objective.item)
	var stored: int=int(rules.state.warehouse.get(item,0))
	if stored<=0:return false
	var regional: Dictionary=EditionRegion.data()
	var warehouses: Array=[]
	for npc in regional.npcs:
		if npc.get("enabled",false) and EditionRegion.shop(npc.id).get("warehouse",false):warehouses.append(npc)
	if warehouses.is_empty():return false
	warehouses.sort_custom(func(a,b):
		if (a.map==world.metadata.id)!=(b.map==world.metadata.id):return a.map==world.metadata.id
		if a.map==world.metadata.id:
			var origin:=Vector2(world.player.cell)
			var da:=origin.distance_squared_to(Vector2(a.cell[0],a.cell[1]))
			var db:=origin.distance_squared_to(Vector2(b.cell[0],b.cell[1]))
			if da!=db:return da<db
		return str(a.id)<str(b.id))
	game_panel("取回任务材料")
	panel.enable_button_navigation()
	label("%s：背包 %d，仓库 %d。先到仓库管理员处取回，再查看任务进度；若数量仍不足，再补齐剩余材料。"%[EditionRules.ITEMS[item].name,int(rules.state.inventory.get(item,0)),stored])
	label("取出需要背包空位和可用负重；此页面只提供路线，不会远程取出或自动提交任务。")
	for npc in warehouses:
		button("前往 %s · %s"%[npc.name,resources.map_by_id.get(npc.map,{}).get("name",npc.map)],func():approach_story_npc(npc.id))
	return true

func approach_story_objective(objective: Dictionary) -> void:
	if objective.get("type","")=="collect":
		if not gameplay.available():info("请继续游戏后寻找地面物品");return
		var drops: Array=rules.state.get("ground_loot",[]).filter(func(drop):return drop.map==world.metadata.id and drop.type==objective.item)
		drops.sort_custom(func(a,b):return Vector2(a.cell[0]-world.player.cell.x,a.cell[1]-world.player.cell.y).length_squared()<Vector2(b.cell[0]-world.player.cell.x,b.cell[1]-world.player.cell.y).length_squared())
		for drop in drops:
			if world.approach(Vector2i(drop.cell[0],drop.cell[1])):
				windows.close_all();pending_message="正在接近"+str(EditionRules.ITEMS[objective.item].name)+"；到达后点击物品或按拾取键。";return
		if show_story_stored_material(objective):return
		var elsewhere: Dictionary={}
		for drop in rules.state.get("ground_loot",[]):
			if drop.type==objective.item and drop.map!=world.metadata.id and resources.map_by_id.has(drop.map):elsewhere[drop.map]=int(elsewhere.get(drop.map,0))+int(drop.count)
		if not elsewhere.is_empty():
			game_panel("寻找遗留任务物品")
			label("其他地图仍留有"+str(EditionRules.ITEMS[objective.item].name)+"。先按正常路线返回，再点击任务追踪接近物品；传送与神殿凭证条件仍需满足。")
			for map_id in elsewhere:
				button("查看路线："+str(resources.map_by_id[map_id].name)+" · 地面 ×"+str(elsewhere[map_id]),func():
					if not rules.state.get("ground_loot",[]).any(func(drop):return drop.map==map_id and drop.type==objective.item):info("此地图的对应物品已不在地面，请重新查看任务追踪");return
					show_story_route(map_id))
			return
		if objective.item=="dragon_story_scale":
			game_panel("火龙鳞片来源")
			panel.enable_button_navigation()
			label("鳞片是单机任务凭证：先接取火龙首领或远征换装委托，再在神殿击败火龙教主，最后从地面拾取。商城与普通材料商不出售此凭证。")
			var stored: int=int(rules.state.warehouse.get("dragon_story_scale",0))
			if stored>0:label("仓库已有 %d 枚，请先到仓库取回；仓库中的凭证不能直接交付。"%stored)
			var accepted: bool=rules.state.quests.get("story_dragon_trial")=="accepted" or rules.state.quests.get("story_dragon_forge")=="accepted"
			if accepted:
				button("查看火龙教主目标",func():approach_story_objective({"type":"kill","maps":[EditionFireDragon.MAP],"names":["火龙教主"]}))
			else:
				label("当前没有接取对应委托，直接击败首领不会获得这枚任务凭证。")
				button("前往盟重询问远征委托",func():approach_story_npc(EditionFireDragon.ENTRANCE))
			return
		if objective.item in ["ref:219","ref:228"]:
			game_panel("寻找鹿茸与鹿血")
			panel.enable_button_navigation()
			label("鹿茸来自未知暗殿的鹿1，原表每次掉落一份；鹿血来自普通鹿，原表每次判定概率为万分之一。战利品需要从地面拾取，任务不保证稀有材料掉落。")
			button("向连接通道老人询问暗殿入口",func():approach_story_npc(dark_temple.NPC))
			button("寻找鹿1" if objective.item=="ref:219" else "寻找普通鹿",func():approach_story_objective({"type":"kill","maps":["m001"] if objective.item=="ref:219" else ["0","d12","m001"],"names":["鹿1"] if objective.item=="ref:219" else ["鹿"]}))
			return
		if show_material_suppliers(str(objective.item)):return
		info("当前地图没有可到达的对应掉落物，也没有已接入的出售商人；请按任务说明获取材料。物品不会自动进入背包。")
		return
	if objective.get("type","")=="flag" and objective.get("field","")=="feast_gift" and objective.get("key","")=="completed":
		approach_story_npc("server:merchant:104");return
	if objective.get("type","")=="flag" and objective.get("field","")=="cook_trial" and objective.get("key","")=="claimed":
		if cook_trials.state().get("active",false):info("请在本次考验中击败对手并拾取头盔，计时结束后返回老人交付。")
		else:approach_story_npc(cook_trials.NPC)
		return
	if objective.get("type","")=="flag" and objective.get("field","")=="fire_dragon" and objective.get("key","")=="surveyed":
		if world.metadata.id!=EditionFireDragon.MAP:show_story_route(EditionFireDragon.MAP);return
		if not gameplay.available():info("请继续游戏后前往勘察点");return
		if not fire_dragon.state().get("active",false):info("请由接引员返回盟重，再凭勘察凭证进入");return
		if world.player.go_to(EditionFireDragon.SURVEY):windows.close_all();pending_message="正在前往神殿中央勘察点；抵达后记录见闻。"
		else:info("当前到中央勘察点的道路受阻，请调整位置后重试。")
		return
	if objective.type=="relationship":
		social_person=str(objective.name);show_social();return
	if objective.type in ["talk","repair","warehouse","purchase","binding","craft"]:approach_story_npc(objective.npc);return
	var target_map: String=objective.get("map","")
	if objective.type=="kill":target_map=objective.maps[0] if world.metadata.id not in objective.maps else world.metadata.id
	if target_map.is_empty():return
	if target_map!=world.metadata.id:
		show_story_route(target_map);return
	if objective.type=="mine":
		if not gameplay.available():info("请继续游戏后寻找矿壁");return
		var spot: Dictionary=preload("res://scripts/edition2011/mining.gd").nearby_wall(world.navigation,world.player.cell,world.metadata.id,rules.state.get("mining",{}),elapsed)
		if spot.is_empty():info("附近未找到可到达且未采空的矿壁，请换一段矿道寻找");return
		if not world.player.go_to(spot.cell):info("前往矿壁的道路暂时受阻");return
		windows.close_all()
		pending_message="正在前往矿壁；抵达后面向%s，装备鹤嘴锄使用攻击操作。矿石需拾取，沿途留意敌人。"%["北","东北","东","东南","南","西南","西","西北"][int(spot.direction)]
		return
	if objective.type=="visit":
		if not save_world():info(rules.message)
		else:info("已到达"+str(world.metadata.name)+"，探索进度已保存。")
		return
	if not gameplay.available():info("请继续游戏后寻找任务怪物");return
	var candidates: Array=[]
	for monster in world.entities:
		if monster.kind=="monster" and monster.get("hp",0)>0 and monster.get("reference_name",monster.name) in objective.names:candidates.append(monster)
	candidates.sort_custom(func(a,b):return Vector2(a.cell[0]-world.player.cell.x,a.cell[1]-world.player.cell.y).length_squared()<Vector2(b.cell[0]-world.player.cell.x,b.cell[1]-world.player.cell.y).length_squared())
	for monster in candidates:
		if world.approach(Vector2i(monster.cell[0],monster.cell[1])):
			windows.close_all();pending_message="正在接近"+str(monster.name)+"；需自行选择攻击。";return
	var sites: Array=[];var seen: Dictionary={}
	var regional: Dictionary=EditionRegion.data()
	for row in regional.populations.get(world.metadata.id,[]):
		var definition: Dictionary=regional.spawns[int(row[0])]
		if definition.name not in objective.names:continue
		var at:=Vector2i(row[2],row[3])
		if seen.has(at):continue
		seen[at]=true;sites.append(at)
	sites.sort_custom(func(a,b):return Vector2(a-world.player.cell).length_squared()<Vector2(b-world.player.cell).length_squared())
	for at in sites:
		if world.approach(at):
			windows.close_all();pending_message="正在前往任务怪物的已登记刷新区域；到达后观察或等待刷新，需自行攻击。";return
	info("当前没有可到达的任务怪物或登记刷新区域，请检查路线后重试。")

func show_story_supplies() -> void:
	game_panel("远行补给")
	panel.enable_button_navigation()
	label("先核对药品与装备耐久，再决定是否出发。商店购买仍需到场，按实际价格和库存办理。")
	for item in ["potion","mana"]:
		label("%s · 背包 %d · 仓库 %d"%[EditionRules.ITEMS[item].name,int(rules.state.inventory.get(item,0)),int(rules.state.warehouse.get(item,0))])
		button("寻找售药商人 · "+str(EditionRules.ITEMS[item].name),func():
			if not show_material_suppliers(item):info("暂未找到已接入的对应售药商人。"))
		if int(rules.state.warehouse.get(item,0))>0:
			button("取回仓库药品 · "+str(EditionRules.ITEMS[item].name),func():show_story_stored_material({"item":item}))

func show_material_suppliers(item: String) -> bool:
	var suppliers:=EditionRegion.material_suppliers(item)
	if suppliers.is_empty():return false
	suppliers.sort_custom(func(a,b):
		if (a.npc.map==world.metadata.id)!=(b.npc.map==world.metadata.id):return a.npc.map==world.metadata.id
		if a.price!=b.price:return a.price<b.price
		return str(a.npc.id)<str(b.npc.id))
	game_panel("寻找材料商人")
	label("购买"+str(EditionRules.ITEMS[item].name)+"需要金币及背包空位；到店后确认库存与单价。不会自动购买或传送。")
	for supplier in suppliers:
		var npc: Dictionary=supplier.npc
		label("%s · %s · 每件 %d 金币%s"%[npc.name,resources.map_by_id.get(npc.map,{}).get("name",npc.map),supplier.price," · "+str(supplier.note) if not str(supplier.note).is_empty() else ""])
		button("前往商人 · "+str(npc.name),func():approach_story_npc(npc.id))
		if near_reference_npc(npc):
			button("打开商店 · "+str(npc.name),func():
				if not gameplay.available() or not near_reference_npc(npc):info("请继续游戏并回到商人身边");return
				show_reference_npc(npc))
	panel.enable_button_navigation()
	return true

func approach_story_npc(id: String) -> void:
	var npc:=rules.story_npc(id)
	if npc.is_empty():info("此任务人物尚未接入");return
	if npc.map!=world.metadata.id:
		show_story_route(npc.map,npc);return
	if world.approach(Vector2i(npc.cell[0],npc.cell[1])):windows.close_all();pending_message="正在前往"+str(npc.name)
	else:show_story_route(npc.map,npc)

func show_reference_npc(npc: Dictionary) -> void:
	if npc.id=="server:merchant:126":preload("res://scripts/edition2011/peach_crafting.gd").panel(self,npc);return
	game_panel(npc.name)
	panel.pin_notice()
	if npc.has("dialogue_source"):label(str(npc.dialogue))
	story_npc_button(npc)
	if npc.id=="server:merchant:105":
		label("金条兑换 · 每次手续费 2000 金币；兑回后金币上限 5000000")
		for to_bar in [true,false]:
			button("1002000 金币 → 金条 ×1" if to_bar else "金条 ×1 → 998000 金币",func():
				if not gameplay.available():return
				if rules.exchange_gold_bar(npc.id,world.metadata.id,world.player.cell,to_bar):play_sound_id(106)
				info(rules.message))
		for bundle in EditionRules.MEDICINE_BUNDLES:
			button("捆扎 %s ×6 → %s · 100 金币"%[EditionRules.ITEMS[EditionRules.MEDICINE_BUNDLES[bundle]].name,EditionRules.ITEMS[bundle].name],func():
				if not gameplay.available():return
				if rules.bind_medicine(npc.id,world.metadata.id,world.player.cell,bundle):play_sound_id(106)
				info(rules.message))

		button("捆扎回城卷 ×6 → 回城卷包 · 100 金币",func():
			if not gameplay.available():return
			if rules.bind_bundle(npc.id,world.metadata.id,world.player.cell,"ref:262"):play_sound_id(106)
			info(rules.message))

	if npc.id=="server:npc:0":button("本地行会登记",func():show_palace_guild(npc))
	if npc.id=="server:merchant:104":button("宴席谢礼 · 林小姐的提问",func():preload("res://scripts/edition2011/feast_gift.gd").panel(self))
	if npc.id=="server:merchant:108":button("八卦阵 · 购买与查看线索",func():preload("res://scripts/edition2011/bagua_clues.gd").panel(self))
	if npc.id=="server:merchant:109":button("神秘商店 · 本职业技能书",func():preload("res://scripts/edition2011/mystery_books.gd").panel(self))
	if npc.id=="server:merchant:109":button("返回老翁身边 · 免费 · 单机返程",func():preload("res://scripts/edition2011/bagua_clues.gd").travel(self,true))
	if npc.id==cook_trials.NPC:button("厨师考验 · 职业挑战",cook_trials.panel)
	if npc.id==dark_temple.NPC:button("未知暗殿 · 限时进入",dark_temple.panel)
	if npc.id==EditionFireDragon.ENTRANCE:button("火龙神殿 · 单机勘察",func():fire_dragon.panel(npc))
	var routes:=EditionRegion.teleports(npc.id)
	panel.enable_button_navigation()
	for route in routes:
		var price: String="%d 金币"%int(route.cost)
		for item in route.get("item_costs",{}):price+=" + %s ×%d"%[EditionRules.ITEMS[item].name,int(route.item_costs[item])]
		button("前往 %s · %s"%[route.label,price],func():teleport_with_npc(npc,route))
	var shop:=EditionRegion.shop(npc.id)
	if not shop.is_empty():
		if shop.has("service_note"):label(str(shop.service_note))
		var scroll:=ScrollContainer.new();scroll.name="MerchantItems";scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size=Vector2(0,170);form.add_child(scroll)
		var goods:=VBoxContainer.new();goods.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(goods)
		for row in shop.goods:
			var spec: Dictionary=EditionRules.ITEMS.get(row.type,EditionRegion.data().items.get(row.type,{}))
			var available: bool=EditionRules.ITEMS.has(row.type) and spec.get("runtime_status")=="supported"
			var price:=maxi(1,int(spec.get("price",0))*int(shop.price_rate)/100)
			var b:=button("%s · %d 金币%s"%[row.name,price,(" · "+str(row.note) if row.has("note") else "") if available else " · 素材或效果待补"],func():
				if not near_reference_npc(npc):info("请回到商人身边");return
				if rules.reference_trade(npc.id,row.type,true,elapsed):play_sound_id(106)
				info(rules.message),goods)
			b.disabled=not available
		for sale_item in rules.state.items:
			if sale_item.container!="inventory":continue
			var id: String=sale_item.type
			if not shop.accepted_modes.any(func(mode):return int(mode)==int(EditionRules.ITEMS[id].get("std_mode",-1))):continue
			var sale_uid: String=sale_item.uid
			var sale_button:=button("出售 %s ×1 · %s · 格%d"%[EditionRules.ITEMS[id].name,EditionInventory.condition_text(sale_item),int(sale_item.slot)+1],func():
				if not near_reference_npc(npc):info("请回到商人身边");return
				if rules.reference_trade(npc.id,id,false,elapsed,sale_uid):play_sound_id(106)
				info(rules.message),goods)
			var sale_status:=preload("res://scripts/edition2011/ui/merchant_sale_row.gd").new()
			sale_button.add_child(sale_status);sale_status.setup(self,sale_item)
		if shop.repair:button("修理装备",func():
			if near_reference_npc(npc):rules.reference_repair(npc.id);info(rules.message)
			else:info("请回到商人身边"))
		if shop.warehouse:button("仓库",func():
			if near_reference_npc(npc):show_warehouse(npc)
			else:info("请回到仓库管理员身边"))
		if shop.warehouse:button("手柄仓库存取",func():show_controller_warehouse(npc))
	if routes.is_empty() and shop.is_empty() and not npc.has("dialogue_source"):label(npc.get("dialogue","此人物的专用脚本已登记，尚未接入本地规则。"))
	if rules.state.quests.has("ore:"+world.metadata.id):button("交付旧区域委托",func():rules.quest(world.metadata.id);info(rules.message))
	button("本区NPC、安全区与传送位置",show_region_info)

func near_reference_npc(npc: Dictionary) -> bool:
	return npc.map==world.metadata.id and (world.player.cell-Vector2i(npc.cell[0],npc.cell[1])).length()<=4 and not world.paused and rules.state.hp>0

func teleport_with_npc(npc: Dictionary,route: Dictionary) -> bool:
	if not near_reference_npc(npc):info("请先走到传送员身边");return false
	if route.npc!=npc.id or not route.enabled:return false
	if rules.state.gold<int(route.cost):info("金币不足，需要 %d 金币"%int(route.cost));return false
	if int(rules.state.level)<int(route.min_level):info("未达到传送等级要求");return false
	for item in route.get("item_costs",{}):
		if int(rules.state.inventory.get(item,0))<int(route.item_costs[item]):info("传送需要："+str(EditionRules.ITEMS[item].name)+" ×"+str(route.item_costs[item]));return false
	var old_map: String=world.metadata.id;var old_cell:=world.player.cell
	var target:=Vector2i(route.target_cell[0],route.target_cell[1])
	if not enter_map(route.target_map,target,false):info("目标地图无法读取，未扣金币");return false
	if not rules.reference_teleport(route,world.player.cell,elapsed,old_map!=route.target_map,region.trap_snapshots(world)):
		var error: String=rules.message;enter_map(old_map,old_cell,false);info(error);return false
	windows.close_all();pending_message="已到达"+str(route.label)
	if not store.backup():pending_message+="；存档已写入，备份失败："+store.error
	return true

func show_region_info() -> void:
	game_panel("本区NPC与安全区")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,280);form.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var default_cell:=EditionRegion.destination(world.metadata.id)
	var origin: String=EditionRegion.data().defaults.get(world.metadata.id,{}).get("source","")
	var origin_label:=" · 单机重建" if origin=="connected_client_floor_reconstruction" else " · 参考安全区"
	button("默认抵达位置 [%d,%d]"%[default_cell.x,default_cell.y]+origin_label,func():world.approach(default_cell);windows.close_all(),list)
	for z in EditionRegion.data().safe_zones:
		if z.enabled and z.map==world.metadata.id:button("安全区 [%d,%d] · 半径%d格"%[z.cell[0],z.cell[1],z.radius],func():world.approach(Vector2i(z.cell[0],z.cell[1]));windows.close_all(),list)
	var nearby_npcs: Array=world.entities.filter(func(entity):return entity.kind=="npc")
	nearby_npcs.sort_custom(func(a,b):return Vector2(a.cell[0]-world.player.cell.x,a.cell[1]-world.player.cell.y).length_squared()<Vector2(b.cell[0]-world.player.cell.x,b.cell[1]-world.player.cell.y).length_squared())
	for npc in nearby_npcs:
		button(npc.name+" [%d,%d]"%[npc.cell[0],npc.cell[1]],func():world.approach(Vector2i(npc.cell[0],npc.cell[1]));windows.close_all(),list)

func cross_passage(route: Dictionary) -> bool:
	if changing_map or world.paused or rules.state.hp<=0:return false
	if route.get("map")!=world.metadata.id or world.player.cell!=Vector2i(route.cell[0],route.cell[1]):return false
	if route.get("target_map")==EditionFireDragon.MAP:
		changing_map=true
		var entered: bool=fire_dragon.enter_passage(route)
		changing_map=false
		if not entered:resources.connections.armed=false
		return entered
	changing_map=true
	var old_map: String=world.metadata.id;var old_cell:=world.player.cell
	var target:=Vector2i(route.target_cell[0],route.target_cell[1])
	var error:=""
	var loaded:=enter_map(route.target_map,target,false)
	if not loaded:error="入口目标地图无法读取"
	elif automation.is_empty() and not rules.save_location(world.metadata.id,world.player.cell,elapsed,chat_history,old_map!=route.target_map,region.special_snapshots(world),cook_trials.snapshot(),region.trap_snapshots(world)):error="切换地图未保存："+rules.message
	if not error.is_empty():
		if loaded:enter_map(old_map,old_cell,false)
		pending_message=error+"，已留在原入口，可退后重试。"
		resources.connections.armed=false;changing_map=false;return false
	windows.close_all();save_elapsed=0
	if automation.is_empty() and not store.backup():pending_message="已进入"+world.zone_name()+"；存档已写入，备份失败："+store.error
	changing_map=false;return true

func show_passages() -> void:
	game_panel("本区出入口")
	label("选择入口后自动走过去；走到标记处进入，进门后离开门槛再走回来即可返回。金色标记为单机补建通路。")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,260);form.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var grouped: Array=[]
	for route in resources.connections.routes:
		if grouped.any(func(r):return r.target_map==route.target_map and r.get("target_component",[])==route.get("target_component",[]) and Vector2(r.cell[0]-route.cell[0],r.cell[1]-route.cell[1]).length()<=2):continue
		grouped.append(route)
		button(resources.connections.title(route,resources)+" [%d,%d]"%[route.cell[0],route.cell[1]],func():
			if route.map!=world.metadata.id:info("地图已改变，请重新打开出入口列表");return
			var at:=Vector2i(route.cell[0],route.cell[1])
			if world.player.cell==at:info("请先离开门槛，再走回入口");return
			if world.approach(at):windows.close_all();pending_message="正在前往："+resources.connections.title(route,resources)
			else:info("当前位置无法步行到这个入口，请从相连区域或向导前往。"),list)

func build_hud() -> void:
	for c in hud.get_children():hud.remove_child(c);c.queue_free()
	hud.show();classic_hud=load("res://scripts/edition2011/ui/hud.gd").new();hud.add_child(classic_hud);classic_hud.setup(self)
	status=Label.new();status.oversampling_with_scale=CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED;status.position=Vector2(18,12);status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status.add_theme_font_size_override("font_size",EditionDisplay.BODY_POINTS)
	status.add_theme_color_override("font_shadow_color",Color.BLACK);status.add_theme_constant_override("shadow_outline_size",4);hud.add_child(status)


func close_panel() -> void:
	windows.close_top()

func game_panel(title: String, dimensions:=Vector2(416,360)) -> void:
	overlay=title
	var win:=windows.open(title,title,dimensions)
	panel=win;form=win.body;notice=win.notice


func show_adventure(index:=0) -> void:
	if windows.windows.has("冒险面板"):
		windows.activate("冒险面板")
		var existing=windows.windows["冒险面板"].body.get_child(1)
		existing.select(index);return
	game_panel("冒险面板",Vector2(620,548))
	var view=load("res://scripts/edition2011/ui/adventure_panel.gd").new()
	form.add_child(view);view.setup(self,index)

func controller_interact(npc: Dictionary) -> void:
	if world.paused or rules.state.hp<=0 or windows.has_modal():return
	if Vector2i(npc.cell[0],npc.cell[1]).distance_to(world.player.cell)>4:
		world.approach(Vector2i(npc.cell[0],npc.cell[1]));pending_message="请靠近后再次交谈";return
	var has_tasks: bool=npc.id=="border:elder"
	for q in EditionRules.Story.data().quests:
		if EditionRules.Story.involves_npc(rules.state,q,npc.id):has_tasks=true;break
	if not has_tasks:interact(npc);return
	if not rules.story_near(npc.id,world.metadata.id,world.player.cell):return
	if not rules.story_talk(npc.id,world.metadata.id,world.player.cell):
		pending_message=rules.message;return
	show_controller_story(npc)

func show_controller_story(npc: Dictionary) -> void:
	game_panel("手柄人物委托",Vector2(520,430))
	var view=load("res://scripts/edition2011/ui/controller_npc.gd").new();form.add_child(view);view.setup(self,npc)

func show_controller_panel() -> void:
	if windows.has_modal() or get_viewport().gui_is_dragging():return
	if windows.windows.has("手柄操作"):windows.close("手柄操作");return
	game_panel("手柄操作",Vector2(480,460))
	var view=load("res://scripts/edition2011/ui/controller_panel.gd").new()
	form.add_child(view);view.setup(self)

func show_character() -> void:show_adventure(1)
func show_bag() -> void:show_adventure(0)
func show_quests() -> void:show_adventure(4)

func return_to_village() -> void:
	if world.metadata.id=="0" and world.approach(EditionVillage.SPAWN):windows.close_all();pending_message="正在步行返回边界村";return
	show_story_route("0",rules.story_npc("border:elder"))

func navigate_village_objective(quest_id: String="") -> void:
	if not gameplay.available():info("请继续游戏并在存活时前往任务目标");return
	var target:=Vector2i(287,618)
	var q:=EditionVillage.quest(quest_id) if not quest_id.is_empty() else EditionVillage.current(rules.state)
	if not q.is_empty() and rules.state.quests.get(q.id)=="accepted":
		if q.id=="nv_equip" and not EditionVillage.ready(rules.state,q.id):show_bag();show_character();return
		if q.id=="nv_hunt" and int(rules.state.get("novice",{}).get("chickens",0))>=3 and int(rules.state.inventory.get("chicken_meat",0))<3:
			var has_meat: bool=rules.state.get("ground_loot",[]).any(func(drop):return drop.type=="chicken_meat")
			if has_meat or int(rules.state.warehouse.get("chicken_meat",0))>0:
				approach_story_objective({"type":"collect","item":"chicken_meat","count":3});return
	if not EditionVillage.nearby(world.metadata.id,world.player.cell):return_to_village();return
	if not q.is_empty() and rules.state.quests.get(q.id)=="accepted" and not EditionVillage.ready(rules.state,q.id):
		if q.id=="nv_patrol":target=EditionVillage.PATROL
		if q.id=="nv_hunt":
			target=Vector2i(274,656)
			var nearest_distance:=INF
			for p in EditionRegion.data().populations.get("0",[]):
				if EditionRegion.data().spawns[int(p[0])].name!="鸡":continue
				var at:=Vector2i(p[2],p[3]);var distance:=Vector2(at-world.player.cell).length_squared()
				if distance<nearest_distance:nearest_distance=distance;target=at
			for entity in world.entities:
				if entity.get("species")=="village_chicken" and entity.hp>0:target=Vector2i(entity.cell[0],entity.cell[1]);break
	var reached:=world.approach(target);windows.close_all();pending_message="正在前往任务目标" if reached else "目标附近没有可通行路线"

func show_village_map() -> void:
	game_panel("边界村地图")
	var map_view=load("res://scripts/edition2011/ui/village_map.gd").new();form.add_child(map_view);map_view.setup(self)
	label("金色：村内商人  绿色：鸡群  蓝色：村外小路  白色：你\n点击地图上的道路可寻路；灰暗位置不可通行。")
	button("前往当前任务目标",navigate_village_objective)
	button("返回村中出生点",return_to_village)
	for npc in EditionVillage.data().npcs:
		button(npc.name+" [%d,%d]"%[npc.cell[0],npc.cell[1]],func():
			if world.metadata.id!="0":return_to_village()
			world.approach(Vector2i(npc.cell[0],npc.cell[1]));windows.close_all())

func show_map_info() -> void:
	game_panel("世界地图")
	button("本区NPC、安全区与默认传送位置",show_region_info)
	button("本区出入口 · 自动寻路",show_passages)
	button("本区怪物与刷新",func():EditionMonsterCatalog.show(self,"map"))
	button("BOSS · 首领与精英资料",func():EditionMonsterCatalog.show(self,"boss"))
	button("全部怪物等级与配置",func():EditionMonsterCatalog.show(self))
	button("边界村地图与任务目标",show_village_map)
	button("返回新手村",return_to_village)
	label("%s\n当前位置：%d, %d\n走到门口、洞口或通路标记可进入相连地图；本区出入口列表可自动寻路。区域向导提供快捷旅行。"%[world.metadata.name,world.player.cell.x,world.player.cell.y])
	for missing in resources.world_catalog.get(world.metadata.id,{}).get("missing_references",[]):label("未完成：%s 缺少 %d 个索引帧；详见 converted-check.json"%[missing.library,missing.indexes.size()])

func interact(entity: Dictionary) -> void:
	selected=entity
	var p:=Vector2i(entity.cell[0],entity.cell[1])
	var interaction_range:=1.5 if entity.kind=="monster" else 4.0
	if (p-world.player.cell).length()>interaction_range:
		pending_message="请靠近后再次点击" if world.approach(p) else "无法到达目标附近，请换一条路线"
		return
	if entity.kind=="npc" and not world.paused:
		var before: int=rules.state.revision
		if not rules.story_talk(entity.id,world.metadata.id,world.player.cell):
			if rules.story_near(entity.id,world.metadata.id,world.player.cell):pending_message=rules.message
		elif rules.state.revision!=before:pending_message=rules.message
	if entity.id==EditionFireDragon.GUARD:fire_dragon.panel(entity);return
	if entity.kind=="monster":attack_target();return
	if entity.kind=="traveler":
		if Input.is_key_pressed(KEY_SHIFT):attack_target()
		else:
			social_person=str(entity.name);show_social()
		return
	if entity.get("service")=="reference":show_reference_npc(entity);return
	var warehouse_source: Dictionary=entity.duplicate(true)
	warehouse_source.map=world.metadata.id
	game_panel(entity.name)
	if entity.get("service")=="room_warehouse":show_warehouse(warehouse_source);return
	if entity.get("service")=="room_shop":
		for id in entity.goods:
			button("购买 %s · %d 金币"%[EditionRules.ITEMS[id].name,EditionRules.ITEMS[id].price],func():rules.shop(id,1);info(rules.message))
		for id in rules.state.inventory:
			button("出售 %s ×1"%EditionRules.ITEMS[id].name,func():rules.shop(id,1,false);info(rules.message))
		button("修理装备",func():rules.repair();info(rules.message))
		button("本店出口",show_passages);return
	if entity.get("service")=="village_quests":
		windows.close("玛法故事与委托")
		game_panel(entity.name,Vector2(620,460))
		var view=load("res://scripts/edition2011/ui/quest_panel.gd").new()
		form.add_child(view);view.setup(self,entity)
		return
	if entity.get("service")=="village_shop":
		for id in entity.goods:
			button("购买 %s · %d 金币"%[EditionRules.ITEMS[id].name,EditionRules.ITEMS[id].price],func():rules.shop(id,1);info(rules.message))
		button("出售背包物品",show_shop);button("修理装备",func():rules.repair();info(rules.message));return
	if entity.id.ends_with(":guide"):
		button("勘察本区并领取奖励",func():rules.exploration(world.metadata.id);info(rules.message))
		button("区域委托：接受 / 交付铁矿",func():rules.quest(world.metadata.id);info(rules.message))
		button("前往其他区域",show_travel)
		button("本区出入口",show_passages)
		button("购买 / 出售",show_shop);button("仓库",func():show_warehouse(warehouse_source))
		button("修理装备",func():rules.repair();info(rules.message))
	else:
		button("购买 / 出售",show_shop);button("仓库",func():show_warehouse(warehouse_source))
		button("修理装备",func():rules.repair();info(rules.message))

func show_travel() -> void:
	if selected.get("service")=="reference" and near_reference_npc(selected):show_reference_npc(selected);return
	if not str(selected.get("id","")).ends_with(":guide") or not near_reference_npc(selected):show_region_info();info("请走到传送员身边，与其对话后传送。");return
	game_panel("区域向导 · 选择目的地")
	var search:=field("filter","搜索地图名称")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,260);form.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var update:=func(query: String):
		for c in list.get_children():list.remove_child(c);c.queue_free()
		for m in resources.maps:
			if not query.is_empty() and not (m.id+str(m.get("name",""))).to_lower().contains(query.to_lower()):continue
			button(str(m.name),func():
				if not save_world():return
				if enter_map(m.id):save_world();close_panel()
				else:info("地图无法载入："+str(m.name)),list)
	search.text_changed.connect(update);update.call("")

func show_shop() -> void:
	game_panel("旅行商店 · 单机重建价格")
	for id in EditionRules.ITEMS:
		if EditionRules.ITEMS[id].get("quest_material",false):continue
		var row:=HBoxContainer.new();form.add_child(row)
		button("买 %s · %d 金币"%[EditionRules.ITEMS[id].name,EditionRules.ITEMS[id].price],func():rules.shop(id,1);info(rules.message),row)
		button("卖 1 件",func():rules.shop(id,1,false);info(rules.message),row)

func show_controller_warehouse(npc: Dictionary) -> void:
	if not near_reference_npc(npc) or not EditionRegion.shop(npc.get("id","")).get("warehouse",false):info("请回到仓库管理员身边，并继续游戏后办理");return
	game_panel("手柄仓库",Vector2(480,440))
	var view=load("res://scripts/edition2011/ui/controller_warehouse.gd").new();form.add_child(view);view.setup(self,npc)

var warehouse_keeper: Dictionary={}
func warehouse_access_allowed() -> bool:
	if warehouse_keeper.is_empty():return true
	if not windows.windows.has("个人仓库"):
		pending_message="仓库已关闭，请重新与保管员对话。";return false
	if near_reference_npc(warehouse_keeper):return true
	pending_message="请回到保管员身边，并继续游戏后办理。"
	return false
func show_warehouse(keeper: Dictionary={}) -> void:
	if keeper.is_empty():info("请与附近的仓库服务NPC对话后打开仓库。");return
	if not keeper.is_empty() and not near_reference_npc(keeper):info("请回到保管员身边，并继续游戏后办理。");return
	warehouse_keeper=keeper.duplicate(true)
	show_bag();game_panel("个人仓库");panel.use_native(3,Rect2(10,0,296,12))
	var grid=load("res://scripts/edition2011/ui/item_panel.gd").new();form.add_child(grid);grid.setup(self,"warehouse")


func show_training() -> void:
	game_panel("内功与经脉 · 重建基础")
	label("探索徽记 %d\n内功 %d　经脉 %d\n当前记录修炼等级，完整技能与战斗增益待后续接入。"%[rules.state.tokens,rules.state.inner,rules.state.meridian])
	button("技能书商店",gameplay.show_books)
	button("内功修炼",func():rules.train("inner");pending_message=rules.message;show_training())
	button("经脉修炼",func():rules.train("meridian");pending_message=rules.message;show_training())

var social_person:="云游客"
func show_story_guild_registration() -> void:
	if not gameplay.available():info("请继续游戏后前往王城登记");return
	var king:=rules.story_npc("server:npc:0")
	if king.is_empty():info("王城登记人物尚未接入");return
	if near_reference_npc(king):show_palace_guild(king)
	else:approach_story_npc(king.id)

func show_palace_guild(npc: Dictionary) -> void:
	if npc.get("id","")!="server:npc:0" or not near_reference_npc(npc):info("请回到国王身边并继续游戏后办理");return
	game_panel("本地行会登记",Vector2(440,360));panel.enable_button_navigation()
	label("单机登记沿用现有免费建会规则；不是原版号角建会或行会战争服务。")
	if not rules.state.guild.is_empty():
		label("已登记："+str(rules.state.guild.name))
		button("查看本地成员与物资",show_social);return
	var title:=field("local_guild_name","行会名称（2至12个字符）");title.text="玛法旅人会";title.max_length=12
	label("同行发起人")
	var companion:=OptionButton.new()
	for person in ["云游客","青禾","远山","轻舟"]:companion.add_item(person)
	form.add_child(companion)
	var submit:=func():
		if not near_reference_npc(npc):info("请回到国王身边并继续游戏后办理");return
		if rules.create_guild(title.text,companion.get_item_text(companion.selected)):
			pending_message=rules.message;show_social()
		else:info(rules.message)
	button("确认登记",submit)
	title.text_submitted.connect(func(_text):submit.call())
	button("返回国王",func():
		if near_reference_npc(npc):show_reference_npc(npc)
		else:info("请回到国王身边"))

func show_social() -> void:
	game_panel("玛法旅人");panel.enable_button_navigation()
	label("当前操作对象："+social_person)
	label("好友：%s\n队伍：%s\n行会：%s\n目前提供本地关系与跟随基础；交易、行会活动与攻城尚未验收。"%[str(rules.state.friends),str(rules.state.party),str(rules.state.guild.get("name","未加入"))])
	if not rules.state.guild.is_empty():
		label("行会公告："+str(rules.state.guild.get("announcement","暂无公告")))
		button("编辑行会公告",show_guild_announcement)
		label("行会贡献：%d · 储备物资（红药救助同行；蓝药恢复自身法力）"%int(rules.state.guild.get("contribution",0)))
		for item in rules.state.guild.get("supplies",{}):label("%s ×%d"%[EditionRules.ITEMS.get(item,{}).get("name",item),int(rules.state.guild.supplies[item])])
		button("用行会红药补给附近同行",func():gameplay.guild_aid();show_social())
		button("用行会蓝药恢复自身法力",func():gameplay.guild_mana();show_social())
	for kind in ["friends","party","guild"]:button({"friends":"添加 / 移除好友","party":"邀请 / 离开队伍","guild":"成立行会"}[kind],func():
		if world.paused:info("请继续游戏后办理旅人关系");return
		rules.social(kind,social_person);pending_message=rules.message;show_social())
	button("切换旅人："+social_person,func():
		var names: Array=["云游客","青禾","远山","轻舟"]
		social_person=names[posmod(names.find(social_person)+1,names.size())];show_social())
	if not rules.state.guild.is_empty():button("邀请当前旅人加入行会",func():
		if not gameplay.available():info("请继续游戏后办理行会邀请");return
		rules.social("guild_member",social_person);pending_message=rules.message;show_social())
	if not rules.state.guild.is_empty():button("查看行会救助记录",show_guild_aid_log)

func show_guild_announcement() -> void:
	if not gameplay.available() or rules.state.guild.is_empty():info("请继续游戏并加入本地行会后编辑公告");return
	game_panel("行会公告",Vector2(460,390));panel.enable_button_navigation()
	label("记录集合地点或补给安排；保存到当前本地行会，不会向外部发送消息。")
	var editor:=TextEdit.new();editor.custom_minimum_size=Vector2(0,170);editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;editor.text=str(rules.state.guild.get("announcement",""));form.add_child(editor)
	var count:=Label.new();form.add_child(count)
	var update_count:=func():count.text="%d / 200 字符"%editor.text.strip_edges().length()
	editor.text_changed.connect(update_count);update_count.call()
	button("保存公告",func():
		if not gameplay.available():info("请继续游戏后保存公告");return
		if rules.set_guild_announcement(editor.text):pending_message=rules.message;windows.close("行会公告");show_social()
		else:info(rules.message))
	button("取消",func():windows.close("行会公告"))

func show_guild_aid_log(page:=0) -> void:
	game_panel("行会救助记录",Vector2(540,420));panel.enable_button_navigation()
	var records: Array=rules.state.guild.get("aid_log",[]).duplicate(true);records.reverse()
	var pages:=maxi(1,ceili(records.size()/4.0));page=clampi(page,0,pages-1)
	label("最近 %d 条救助 · 第 %d/%d 页（最多保留100条，新记录在前）"%[records.size(),page+1,pages])
	if records.is_empty():label("尚无成功救助记录。使用行会红药救助同行或蓝药恢复自身法力后，会在这里保存明细。")
	for row in records.slice(page*4,mini(records.size(),page*4+4)):
		var place: String=str(resources.map_by_id.get(row.map,{}).get("name",row.map))
		var item: String=str(EditionRules.ITEMS.get(row.item,{}).get("name",row.item))
		label("%s · %s\n消耗 %s ×%d · 实际恢复 %d 点%s"%[row.member,place,item,int(row.count),int(row.healed),"法力" if row.get("resource","hp")=="mp" else "生命"])
	if page>0:button("上一页",func():show_guild_aid_log(page-1))
	if page+1<pages:button("下一页",func():show_guild_aid_log(page+1))
	button("关闭记录",func():windows.close("行会救助记录"))

func show_settings() -> void:
	game_panel("设置与操作");windows.pause("settings")
	panel.pin_notice()
	for bus in ["Music","Interface","Combat","Environment"]:
		var row:=HBoxContainer.new();form.add_child(row)
		var name:=Label.new();name.text={"Music":"音乐","Interface":"界面","Combat":"战斗","Environment":"环境"}[bus];row.add_child(name)
		var slider:=HSlider.new();slider.min_value=-40;slider.max_value=0;slider.step=1;slider.custom_minimum_size=Vector2(280,25)
		slider.value=sound_levels.get(bus,-6);row.add_child(slider)
		slider.value_changed.connect(func(value):
			if not slider.is_inside_tree() or slider.is_queued_for_deletion():return
			if not set_sound_level(bus,value):slider.set_value_no_signal(sound_levels.get(bus,-6)))
	for factor in [0,1,2,3,4]:
		button("界面缩放："+("自动" if factor==0 else str(factor)+"×"),func():
			if not store.put_metadata("ui_scale",str(factor)):info("界面缩放保存失败："+store.error);return
			windows.requested_scale=factor;info("界面缩放已保存"))
	label("自动显示保持像素大小，调整窗口扩展视野。\nWASD / 方向键：走动　Shift：跑动\n左键：寻路 / 交互　右键按住：朝指针跑动\n空格：普通攻击　E：最近 NPC　B：背包　K：技能\nQ：施法　R：切换技能　G：拾取　H：内挂\nT：切换攻击模式（默认和平），Shift 点击 AI 玩家攻击\n1–6：快捷物品，可从背包拖入绑定\nEsc：关闭窗口　P：暂停世界\n手柄：左摇杆移动；X 普攻，Y 施法，LB/RB 切换技能\nBack 打开独立操作面板；面板内 LB/RB 切页，B 返回\nStart：暂停 / 继续；账号文字输入请使用键盘\n资源基准：十周年 2.0.1.11，支持十六周年补充。")
	for z in [0,1,2,3,4,6]:button("地图缩放："+("稳定像素（推荐）" if z==0 else str(z)+"×"),func():
		if not store.put_metadata("zoom",str(z)):info("地图缩放保存失败："+store.error);return
		world.preferred_zoom=z;info("地图缩放已保存"))
	button("全屏 / 窗口",toggle_fullscreen)
	button("恢复推荐窗口大小",func():
		if not store.put_metadata("display:window_points",""):info("窗口设置保存失败："+store.error);return
		setup_display();info("已恢复推荐窗口大小"))
	button("静音 / 恢复声音",func():
		if toggle_mute():info("静音" if muted else "声音已恢复")
		else:info("静音设置保存失败："+store.error))
	button("保存进度",func():
		if save_world():info("游戏进度已保存")
		else:info("保存未完成："+pending_message))

func toggle_mute() -> bool:
	if not store.put_metadata("muted",str(not muted)):return false
	muted=not muted;music.stream_paused=muted
	if muted:
		for sound in effects:
			sound.stop();sound.stream=null;sound.stream_paused=false
	elif music.stream!=null and not music.playing:music.play()
	return true

func attack_target() -> void:
	if rules.state.hp<=0:return
	if rules.stoned(elapsed):pending_message="石化中，暂时无法攻击";return
	if EditionRegion.safe(world.metadata.id,world.player.cell):pending_message="安全区内不能攻击";return
	if fight_timer>0 or world.paused:return
	if gameplay.assisted_strike():return
	var nearest: Dictionary={};var distance:=1.5
	for e in world.entities:
		if not gameplay.can_target(e):continue
		var d:=(Vector2(e.cell[0],e.cell[1])-Vector2(world.player.cell)).length()
		if d<distance and gameplay.line_clear(world.player.cell,Vector2i(e.cell[0],e.cell[1])) and not EditionRegion.safe(world.metadata.id,Vector2i(e.cell[0],e.cell[1])):nearest=e;distance=d
	if not selected.is_empty() and gameplay.can_target(selected) and (Vector2(selected.cell[0],selected.cell[1])-Vector2(world.player.cell)).length()<1.5 and gameplay.line_clear(world.player.cell,Vector2i(selected.cell[0],selected.cell[1])):nearest=selected
	if nearest.is_empty():
		if preload("res://scripts/edition2011/mining.gd").swing(self):return
		pending_message="附近没有符合当前攻击模式的目标";return
	if EditionRegion.safe(world.metadata.id,Vector2i(nearest.cell[0],nearest.cell[1])):pending_message="安全区内不能攻击";return
	fight_timer=0.7;world.animate("attack");play_sound_id(51 if rules.state.equipment.get("weapon")=="wood_sword" else (52 if rules.state.equipment.get("weapon")=="sword" else 57))
	var direction:=Vector2i(signi(int(nearest.cell[0])-world.player.cell.x),signi(int(nearest.cell[1])-world.player.cell.y))
	if direction!=Vector2i.ZERO:world.player.direction=ClassicNavigation.DIRECTIONS.find(direction)
	pending_attack={"id":nearest.id,"generation":nearest.generation,"at":elapsed+0.255,"damage":rules.roll_melee_damage()}

func resolve_attack() -> void:
	if pending_attack.is_empty() or elapsed<float(pending_attack.at):return
	var attack:=pending_attack.duplicate(true);pending_attack.clear()
	if rules.state.hp<=0:return
	var hits: Array=attack.get("hits",[{"id":attack.id,"generation":attack.generation}])
	var impact_played:=false
	for hit in hits:
		for entity in world.entities:
			if entity.id!=hit.id or entity.get("generation",-1)!=hit.generation or entity.get("hp",0)<=0:continue
			if not gameplay.can_target(entity):continue
			var target:=Vector2i(entity.cell[0],entity.cell[1]);var d:=target-world.player.cell
			if attack.has("area_cell"):
				var center:=Vector2i(attack.area_cell[0],attack.area_cell[1])
				if maxi(absi(target.x-center.x),absi(target.y-center.y))>1:continue
			if maxi(absi(d.x),absi(d.y))>int(attack.get("range",1)) or not gameplay.line_clear(world.player.cell,target):continue
			if EditionRegion.safe(world.metadata.id,world.player.cell) or EditionRegion.safe(world.metadata.id,target):continue
			var applied:=apply_attack_hit(entity,attack)
			if applied and not impact_played and attack.has("skill"):gameplay.play_skill_stage(attack.skill,2);impact_played=true
			break

func apply_attack_hit(entity: Dictionary,attack: Dictionary) -> bool:
	if not gameplay.can_target(entity) or rules.state.hp<=0:return false
	if EditionRegion.safe(world.metadata.id,world.player.cell) or EditionRegion.safe(world.metadata.id,Vector2i(entity.cell[0],entity.cell[1])):return false
	if attack.get("skill","")=="trap":
		var learned=rules.state.skills.get("trap",{})
		var rank:=int(learned.get("rank",1)) if learned is Dictionary else 1
		var status: Dictionary=preload("res://scripts/edition2011/trap_status.gd").create(entity,int(rules.state.level),rank,elapsed)
		if not status.is_empty():entity.trap_status=status;pending_message="困魔咒困住了"+str(entity.name)
		return not status.is_empty()
	if entity.kind=="traveler":
		var hp_before:int=entity.hp
		gameplay.hit_traveler(entity,attack)
		if int(entity.hp)<hp_before:show_hit_effect(entity,attack)
		return int(entity.hp)<hp_before
	if not attack.has("skill") and not rules.melee_hits(int(entity.get("speed",0))):
		pending_message="对"+str(entity.get("name","目标"))+"的普通攻击未命中"
		return false
	var defense:=int(entity.get("mac",0)) if EditionSkills.DEFINITIONS.get(attack.get("skill",""),{}).get("job","战士")!="战士" else int(entity.get("ac",0))
	if attack.get("skill")=="thrust" and Vector2(entity.cell[0]-world.player.cell.x,entity.cell[1]-world.player.cell.y).length()>=2:defense=0
	var remaining:=maxi(0,int(entity.hp)-maxi(1,int(attack.damage)-defense))
	if remaining==0:
		if not rules.reward_kill(Crypto.new().generate_random_bytes(16).hex_encode(),entity.get("species",""),entity.merged({"map":world.metadata.id},true),elapsed):
			pending_message="奖励未写入，击杀未结算："+rules.message;return false
		entity.hp=0
		entity.respawn=float(rules.state.regional_deaths[entity.id]) if entity.has("spawn_id") else elapsed+float(entity.get("respawn_seconds",30));entity.generation+=1
		entity.motion="die";entity.motion_time=world.elapsed
		world.actors.sound(entity,"die")
		pending_message=rules.message
	else:
		entity.hp=remaining
		EditionMonsterAI.react_to_hit(entity,world.elapsed,bool(attack.get("periodic",false)))
		play_sound_id(73);world.actors.sound(entity,"hurt")
	# Do not mutate status or mana before a lethal reward transaction succeeds.
	if attack.get("skill")=="poison" and not attack.get("periodic",false):entity.poison_until=elapsed+10;entity.poison_next=elapsed+1.5
	if attack.get("skill")=="manafire":entity.mp=maxi(0,int(entity.get("mp",0))-20)
	show_hit_effect(entity,attack)
	return true

func show_hit_effect(entity: Dictionary,attack: Dictionary) -> void:
	if not attack.get("periodic",false) and not attack.get("visual_played",false):
		gameplay.skill_effects.add(str(attack.get("skill","")),attack.get("effect_at",world.actors.anchor(entity)))
		if EditionSkills.DEFINITIONS.get(attack.get("skill",""),{}).get("kind","")=="area":attack.visual_played=true

func save_world() -> bool:
	if not automation.is_empty():return true
	var ok:=rules.save_location(world.metadata.id,world.player.cell,elapsed,chat_history,false,region.special_snapshots(world),cook_trials.snapshot(),region.trap_snapshots(world))
	if not ok:pending_message=rules.message
	elif not store.backup():pending_message=store.error;return false
	return ok

func stop_audio() -> void:
	# Stop while players are still in the tree, before normal application exit.
	music.stop();music.stream=null
	for sound in effects:sound.stop();sound.stream=null
	resources.sounds.clear()

func quit_application(exit_code: int=0) -> void:
	stop_audio()
	get_tree().quit(exit_code)

func _exit_tree() -> void:
	if thread.is_started():thread.wait_to_finish()
	stop_audio()
	store.close()
	# Startup can fail before these owned nodes are attached to the scene.
	for owned in [gameplay,world]:
		if is_instance_valid(owned) and owned.get_parent()==null:owned.free()

func fatal(text: String) -> void:
	mode="error";reset_panel("无法启动");info(text);button("退出",func():quit_application(1))

func _unhandled_input(event: InputEvent) -> void:
	if mode!="game":return
	if event is InputEventJoypadButton and event.pressed:
		controller_button(event.button_index);return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE and not windows.has_modal():
		close_panel();get_viewport().set_input_as_handled();return
	if world.paused:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_P and windows.pause_reason.is_empty() and not typing():world.paused=false
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not pointer_blocked():
		if not gameplay.click(event.position):world.handle_click(event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if typing():return
		if rules.state.hp<=0:return
		match event.physical_keycode:
			KEY_B:
				if not windows.order.is_empty() and windows.order.back()=="冒险面板" and windows.windows["冒险面板"].body.get_child(1).current==0:windows.close("冒险面板")
				else:show_bag()
			KEY_I:show_character()
			KEY_K:show_skills()
			KEY_H:gameplay.show_assist()
			KEY_Q:gameplay.cast_current()
			KEY_R:gameplay.cycle_skill()
			KEY_G:gameplay.pickup_nearby()
			KEY_M:show_map_info()
			KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6:classic_hud.use_quick(event.physical_keycode-KEY_1)
			KEY_SPACE:attack_target()
			KEY_T:gameplay.cycle_attack_mode()
			KEY_P:world.paused=not world.paused;pending_message="已暂停" if world.paused else "继续冒险"
			KEY_E:
				var nearest: Dictionary={};var distance:=5.0
				for e in world.entities:
					if e.kind!="npc":continue
					var d:=(Vector2(e.cell[0],e.cell[1])-Vector2(world.player.cell)).length()
					if d<distance:nearest=e;distance=d
				if not nearest.is_empty():interact(nearest)

func controller_button(key: int) -> void:
	if key==JOY_BUTTON_START:
		if windows.pause_reason.is_empty() and not windows.has_modal():world.paused=not world.paused
		return
	if key==JOY_BUTTON_B:
		if not windows.has_modal():close_panel()
		return
	if world.paused or rules.state.hp<=0 or typing() or windows.has_modal():return
	if key==JOY_BUTTON_BACK:show_controller_panel();return
	# Open windows own controller focus; gameplay must not receive their buttons.
	if not windows.windows.is_empty():return
	match key:
		JOY_BUTTON_X:attack_target()
		JOY_BUTTON_Y:gameplay.cast_current()
		JOY_BUTTON_LEFT_SHOULDER:gameplay.cycle_skill(-1)
		JOY_BUTTON_RIGHT_SHOULDER:gameplay.cycle_skill(1)
		JOY_BUTTON_DPAD_UP:classic_hud.use_quick(0)
		JOY_BUTTON_DPAD_DOWN:classic_hud.use_quick(1)
		JOY_BUTTON_BACK:show_controller_panel()
		JOY_BUTTON_A:
			gameplay.pickup_nearby()
			var nearest: Dictionary={};var distance:=3.0
			for e in world.entities:
				if e.kind!="npc":continue
				var d: float=Vector2(e.cell[0]-world.player.cell.x,e.cell[1]-world.player.cell.y).length()
				if d<distance:nearest=e;distance=d
			if not nearest.is_empty():controller_interact(nearest)

func _process(delta: float) -> void:
	update_display_density()
	update_benchmark(delta)

	if not capture_path.is_empty():
		capture_frames+=1
		if capture_frames==90:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
			print("Captured ",capture_path," resource errors: ",resources.errors)
			store.close();quit_application()
	if is_instance_valid(panel) and not panel is EditionWindow:panel.position=((get_viewport_rect().size-panel.size)/2).max(Vector2(12,110) if mode=="game" else Vector2(12,12))
	if thread.is_started() and not thread.is_alive():
		entry.finish_auth(bool(thread.wait_to_finish()))

	if mode=="game":
		var ui_zoom:=EditionDisplay.ui_zoom(get_viewport_rect().size,windows.requested_scale,display_density)
		status.scale=Vector2.ONE*ui_zoom;status.position=Vector2(18,12)*ui_zoom
		if not world.paused:
			elapsed+=delta;save_elapsed+=delta;fight_timer=maxf(0,fight_timer-delta)
			resolve_attack()
		world.display_density=display_density
		world.equipment=rules.state.equipment;world.party=rules.state.party;world.player_alive=rules.state.hp>0;world.player_stoned=rules.stoned(elapsed);world.player_poison_until=float(rules.state.get("green_poison",{}).get("until",0))
		var marker_key: String=str(rules.character.get("id",""))+":"+str(rules.state.revision)
		if marker_key!=task_marker_key:
			task_marker_key=marker_key;world.task_markers=EditionRules.Story.npc_markers(rules.state)
		if not world.paused:
			region.populate(world,rules,delta,elapsed)
		world.controller_allowed=windows.windows.is_empty()
		world.update_world(delta,get_viewport_rect().size,rules.state.hp>0 and not typing() and not windows.has_modal() and not get_viewport().gui_is_dragging(),not pointer_blocked())
		if not world.paused and rules.state.hp>0:
			var passage:=resources.connections.poll(world.player)
			if not passage.is_empty():cross_passage(passage)
		fire_dragon.update()
		dark_temple.update()
		cook_trials.update()
		gameplay.update(delta)
		if death_return_at>=0 and elapsed+0.001>=death_return_at and not world.paused:
			gameplay.revive_after_wait()
		if save_elapsed>=30:save_elapsed=0;save_world()
		if not world.paused and rules.state.hp>0 and rules.novice_patrol(world.metadata.id,world.player.cell):pending_message=rules.message
		if is_instance_valid(status):
			var status_text: String="%s  Lv.%d · %s%s\n%s"%[rules.character.name,rules.state.level,world.zone_name()," · 安全区" if EditionRegion.safe(world.metadata.id,world.player.cell) else "",pending_message]
			var expedition_time: String=fire_dragon.time_text()
			if expedition_time.is_empty():expedition_time=dark_temple.time_text()
			if expedition_time.is_empty():expedition_time=cook_trials.time_text()
			if not expedition_time.is_empty():status_text=expedition_time+" · "+status_text
			var active: String=gameplay.current_skill()
			if not active.is_empty():status_text+=" · Q/Y："+EditionGameplay.SKILLS[active].name+"（R/肩键切换）"
			if rules.state.has("green_poison"):status_text+=" · 绿毒 %d秒"%maxi(0,ceili(float(rules.state.green_poison.until)-elapsed))
			if rules.stoned(elapsed):status_text+=" · 石化 %d秒"%ceili(float(rules.state.stone_until)-elapsed)
			if status.text!=status_text:status.text=status_text
			status.clip_text=true;status.size=Vector2(get_viewport_rect().size.x/ui_zoom-36,46)
	queue_redraw()

func _draw() -> void:
	if entry.visible or mode=="game" or resources.maps.is_empty():return
	var image:=resources.frame("chrsel",22)
	if image.is_empty():return
	var screen:=get_viewport_rect().size
	var factor:=maxf(screen.x/800.0,screen.y/600.0)
	draw_texture_rect(image.texture,Rect2((screen-Vector2(800,600)*factor)/2,Vector2(800,600)*factor),false)

func typing() -> bool:
	var focus:=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit or windows.has_modal()

func pointer_blocked() -> bool:
	return windows.blocks_pointer() or (is_instance_valid(classic_hud) and classic_hud.blocks_pointer())

func show_skills() -> void:gameplay.show_skills()

func show_skill_catalog() -> void:gameplay.show_skills()

func initialize_sound_buses() -> void:
	for bus in ["Music","Interface","Combat","Environment"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
		var saved:=store.read_metadata("volume:"+bus)
		var value:=clampf(float(saved),-40,0) if saved.is_valid_float() else -6.0
		sound_levels[bus]=value;AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),value)

func set_sound_level(bus: String,value: float) -> bool:
	if not sound_levels.has(bus):return false
	var level:=clampf(value,-40,0)
	if not store.put_metadata("volume:"+bus,str(level)):info("音量保存失败："+store.error);return false
	sound_levels[bus]=level
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),sound_levels[bus])
	return true

func update_benchmark(delta: float) -> void:
	if benchmark_seconds<=0 or mode!="game":return
	benchmark_elapsed+=delta;benchmark_sample+=delta
	if world.player.route.is_empty():
		var spots: Array=world.metadata.service_spots
		var at: Array=spots[int(benchmark_elapsed/4)%spots.size()]
		world.player.go_to(Vector2i(at[0],at[1]))
	if benchmark_sample>=1:
		benchmark_sample=0
		var sample:={"time":benchmark_elapsed,"fps":Engine.get_frames_per_second(),"static_memory":OS.get_static_memory_usage(),"texture_cache":resources.memory_bytes,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		benchmark_samples.append(sample);print("BENCH ",JSON.stringify(sample))
	if benchmark_elapsed>=benchmark_seconds:
		if not benchmark_output.is_empty():
			var output:=FileAccess.open(benchmark_output,FileAccess.WRITE)
			if output!=null:output.store_string(JSON.stringify({"architecture":Engine.get_architecture_name(),"seconds":benchmark_elapsed,"samples":benchmark_samples,"errors":resources.errors},"  "))
		quit_application()
