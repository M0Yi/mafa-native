extends SceneTree

var failures: Array[String]=[]
var checks:=0
var app: Node
var t: ClassicTrial
var spawn:=Vector2i(64,64)

func check(value: bool,text: String) -> void:
	checks+=1
	if not value:failures.append(text);printerr("FAIL ",text)

func _initialize() -> void:call_deferred("run")

func step(seconds: float) -> void:
	for i in range(ceili(seconds*60)):t.update(1.0/60)

func prepare(name: String) -> void:
	app.player.reset(spawn)
	var skill:=t.find_skill(name)
	t.select_job(skill.job);t.enabled=true;t.reset_targets()
	t.selected=t.skills.find(skill)

func target(kind := "chicken") -> Dictionary:
	for a in t.actors:
		if a.kind==kind:return a
	return {}

func cast(name: String,cell: Vector2i) -> void:
	t.selected=t.skills.find(t.find_skill(name));t.cooldown=0;t.cast_time=0
	check(t.cast(cell),name+" accepts target")
	step(1.05)

func run() -> void:
	app=load("res://main.tscn").instantiate()
	app.saves.directory="user://skill-tests-%d" % OS.get_process_id()
	root.add_child(app);await process_frame
	app.set_process(false);app.audio.muted=true;app.audio.apply_volumes()
	check(app.ready_to_play,"scene/resources/audio initializes")
	if not app.ready_to_play:quit(1);return
	t=app.trial
	check(t.catalog.skills.size()==33,"33 classic skills")
	app.player.reset(Vector2i(78,24));t.enabled=true;t.reset_targets()
	check(t.actors.size()>1,"cliff spawn has practice targets")
	for actor in t.actors:check(t.line_clear(app.player.cell,actor.cell),"practice target has clear line of sight")
	for job in ["战士","法师","道士"]:
		t.select_job(job);check(t.skills.size()==({"战士":6,"法师":14,"道士":13}[job]),job+" complete catalog")
	for s in t.catalog.skills:
		prepare(s.name)
		if s.kind in ["passive","empower"]:
			check(not t.cast(spawn),s.name+" is passive");continue
		var cell: Vector2i=target().cell
		if s.kind in ["heal","group_heal","shield","magic_armor","armor","invisible","group_invisible"]:cell=spawn
		if s.kind=="holy":cell=target("skeleton").cell
		cast(s.name,cell)
		check(app.nav.walkable(app.player.cell),s.name+" retains valid player position")
	prepare("雷电术");var a:=target();var before: float=a.hp
	cast("雷电术",a.cell);check(a.hp<before,"bolt damages actual target")
	check(app.audio.events.has("040000B0"),"lightning cast sound event")
	prepare("火球术");a=target();before=a.hp
	t.cast(a.cell);step(0.15);check(a.hp==before,"projectile damage waits for travel")
	step(1);check(a.hp<before,"projectile damages on arrival")
	check(app.audio.events.has("04000010") and app.audio.events.has("04000011") and app.audio.events.has("04000012"),"fireball has start/travel/impact audio")
	prepare("施毒术");a=target();before=a.hp
	cast("施毒术",a.cell);step(2);check(a.hp<before and a.statuses.has("绿毒"),"green poison ticks")
	t.red_poison=true;cast("施毒术",a.cell);check(a.statuses.has("红毒"),"red poison separate debuff");t.red_poison=false
	prepare("火墙");a=target();before=a.hp
	cast("火墙",a.cell);step(2);check(a.hp<before and t.fields.size()==1,"firewall ticks")
	prepare("治愈术");t.hp=100;cast("治愈术",spawn);step(2);check(t.hp>100,"healing over time")
	prepare("群体治愈术");t.hp=100;var pet:=t.spawn_actor("pet_skeleton",spawn+Vector2i(0,1),true);pet.hp=100
	cast("群体治愈术",spawn);step(2);check(t.hp>100 and pet.hp>100,"group heal affects allies")
	prepare("心灵启示");a=target();cast("心灵启示",a.cell);check(a.statuses.has("洞察"),"reveal works despite documented missing art")
	prepare("困魔咒");a=target();cast("困魔咒",a.cell);check(a.statuses.has("禁锢"),"trap applied")
	t.hurt(a,1);check(not a.statuses.has("禁锢"),"damage breaks trap")
	prepare("圣言术");a=target("skeleton");cast("圣言术",a.cell);check(a.hp==0,"holy kills trial undead")
	prepare("圣言术");a=target();cast("圣言术",a.cell);check(a.hp==240,"holy cannot kill living creature")
	prepare("诱惑之光");a=target();cast("诱惑之光",a.cell);cast("诱惑之光",a.cell);check(a.ally,"charm recruits creature")
	prepare("召唤神兽");cast("召唤神兽",spawn);check(t.actors.any(func(e):return e.kind=="beast" and e.ally),"beast summoned")
	var enemy:=target();before=enemy.hp;step(5);check(enemy.hp<before,"summon attacks autonomously")
	prepare("召唤骷髅");cast("召唤骷髅",spawn);cast("召唤骷髅",spawn);check(t.actors.filter(func(e):return e.get("summoned",false)).size()==1,"summons bounded")
	prepare("隐身术");cast("隐身术",spawn);check(t.buffs.has("隐身"),"invisibility buff")
	app.player.action="walk";step(0.1);check(not t.buffs.has("隐身"),"movement breaks invisibility")
	prepare("魔法盾");cast("魔法盾",spawn);check(t.buffs.has("魔法盾"),"shield applied")
	prepare("烈火剑法");cast("烈火剑法",spawn);check(t.buffs.has("烈火"),"fireblade arms next attack")
	a=target();t.cooldown=0;check(t.strike(a.cell),"armed strike accepted");step(0.3);check(not t.buffs.has("烈火") and a.hp<160,"fireblade consumed for bonus damage")
	prepare("雷电术");t.mp=0;check(not t.cast(target().cell),"insufficient MP rejected")
	t.mp=300;check(not t.cast(Vector2i(-1,-1)),"outside map rejected")
	prepare("瞬息移动");cast("瞬息移动",spawn);check(app.nav.walkable(app.player.cell) and app.player.cell!=spawn,"teleport valid destination")
	# Asset sound decode lengths, independently of the event log.
	check(app.audio.streams.size()>40,"substantial audio bank loaded")
	for key in app.audio.streams:check(app.audio.streams[key].get_length()>0,"decoded sound "+key)
	var master: float=app.audio.master
	app.audio.master=0.31;app.audio.music_volume=0.22;app.audio.effects_volume=0.62
	check(app.audio.save_settings(),"audio settings write")
	app.audio.master=0.9;app.audio.load_settings();check(is_equal_approx(app.audio.master,0.31),"audio settings restore")
	var file:=FileAccess.open(app.audio.directory.path_join("audio.cfg"),FileAccess.WRITE);file.store_string("corrupt[");file.close()
	app.audio.load_settings();check(not app.audio.error_message.is_empty(),"corrupt audio settings reported")
	app.audio.master=master
	# Let every delayed event and finite effect drain; repeated casts cannot leak objects.
	prepare("火球术")
	for i in range(120):
		t.cooldown=0;t.cast_time=0;t.mp=300
		if t.actors.is_empty():t.reset_targets()
		t.cast(t.actors[0].cell);step(1.2)
	step(20);check(t.pending.is_empty() and t.effects.is_empty() and t.fields.is_empty(),"effect queues drain after repeated casts")
	var report: Dictionary={"checks":checks,"failures":failures,"audio_streams":app.audio.streams.size(),"skill_count":33,"casts":t.total_casts}
	print("SKILL_TESTS ",JSON.stringify(report))
	t=null
	app.queue_free();await process_frame
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)
