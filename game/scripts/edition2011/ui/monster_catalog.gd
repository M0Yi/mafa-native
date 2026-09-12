class_name EditionMonsterCatalog
extends RefCounted

static func show(host,scope: String="all") -> void:
	host.game_panel("首领与精英刷新资料" if scope=="boss" else "本区怪物刷新" if scope=="map" else "怪物资料")
	var search: LineEdit=host.field("monster_filter","输入怪物名称")
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,280);host.form.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var refresh:=func(query: String):
		for child in list.get_children():list.remove_child(child);child.queue_free()
		for name in EditionRegion.data().monsters:
			var spec: Dictionary=EditionRegion.data().monsters[name]
			if not query.is_empty() and not str(name).contains(query):continue
			if scope=="boss" and spec.get("catalog_group")!="boss_elite":continue
			var rows: Array=EditionRegion.data().spawns.filter(func(s):return s.name==name and (scope!="map" or str(s.mapName).to_lower()==host.world.metadata.id))
			if scope=="map" and rows.is_empty():continue
			host.button("%s · Lv.%d · %d 处刷新%s"%[name,spec.raw.lvl,rows.size(),"" if spec.enabled else " · 动作待补"],func():detail(host,name),list)
	search.text_changed.connect(refresh);refresh.call("")
	host.label("依据项目内 Mir2-GeeM2 配置。首领/精英是浏览分组，不额外放大数值。")

static func detail(host,name: String) -> void:
	var spec: Dictionary=EditionRegion.data().monsters[name];var raw: Dictionary=spec.raw
	host.game_panel(name+" · Lv.%d"%raw.lvl)
	host.label("生命 %d　魔法 %d　经验 %d\n攻击 %d–%d　防御 %d　魔御 %d\n行走原值 %d ms　攻击间隔原值 %d ms"%[raw.hp,raw.mp,raw.exp,raw.dc,raw.dcMax,raw.ac,raw.mac,raw.walkSpeed,raw.attackSpd])
	var effective: Dictionary=spec.get("runtime_stats",{})
	if not effective.is_empty():host.label("服务端实际：行走 %d ms，攻击 %d ms；连走%d步，停顿%d ms"%[effective.walk_ms,effective.attack_ms,effective.walk_step,effective.walk_wait_ms])
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,200);host.form.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var rows: Array=EditionRegion.data().spawns.filter(func(s):return s.name==name)
	if rows.is_empty():
		var text:=Label.new();text.text="参考刷怪表没有固定刷新点；不擅自添加。";list.add_child(text)
	for row in rows:
		var mid: String=str(row.mapName).to_lower()
		var title: String=host.resources.map_names.get(mid,{}).get("name",mid+"（缺少地图）")
		var period: int=(int(row.interval) if int(row.interval)>0 else 10)*60
		host.button("%s [%d,%d] ±%d格 · %d只 / %d分钟 · %s"%[title,row.x,row.y,row.range,row.count,period/60,"已接入" if row.status=="enabled" else "存在缺口"],func():
			if mid!=host.world.metadata.id:host.info("请通过传送员或地图通路前往"+title);return
			host.world.approach(Vector2i(row.x,row.y));host.windows.close_all(),list)
		var note:=Label.new();note.add_theme_font_size_override("font_size",12);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		note.text="周期补足数量；下个检查点约 %.0f 秒后（打开时）。"%(EditionRegion.next_refresh(host.elapsed,period)-host.elapsed)
		list.add_child(note)
	host.button("查看全部原始配置字段",func():
		host.game_panel(name+" · 原始配置")
		var area:=ScrollContainer.new();area.custom_minimum_size=Vector2(0,320);host.form.add_child(area)
		var text:=Label.new();text.text=JSON.stringify(raw,"  ");text.add_theme_font_size_override("font_size",13);area.add_child(text)
		host.label("原值完整保留；特殊 AI、技能、准确/敏捷与扩展字段尚未全部参与规则。"))
	if not spec.enabled:host.label("此形象与当前素材的动作配置不匹配，尚未刷出；缺口已登记。")
	host.label("轻松档经验奖励 ×3；这里显示未经倍率放大的参考原值。")
