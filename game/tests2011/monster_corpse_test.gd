extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/monster-corpses-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app)
	for i in range(5):await process_frame
	app.set_process(false);app.start_character({"id":"corpses","name":"尸体核验","gender":"男","job":"战士"});app.world.paused=true
	var rows: Array=[];var seen: Dictionary={};var unresolved: Array=[];var fallback_count:=0
	for name in EditionRegion.data().monsters:
		var monster: Dictionary=EditionRegion.data().monsters[name]
		if not monster.enabled:continue
		var p: Dictionary=monster.profile;var key: String=str(p.bank)+":"+str(p.base)+":"+str(p.actions)+":"+str(monster.raw.raceImg)
		if seen.has(key):continue
		seen[key]=true
		var corpse: Dictionary=p.actions.get("corpse",{});var death: Dictionary=p.actions.get("die",{})
		for direction in range(8):
			var facing: int=EditionCreatures.body_direction({"race_image":monster.raw.raceImg,"direction":direction})
			var expected: int=-1;var declared: int=-1
			if int(corpse.get("count",0))>0:
				declared=int(p.base)+EditionAnimation.index(corpse,facing,2.0)
				var data: Dictionary=app.resources.frame(p.bank,declared)
				if not data.is_empty():
					var image: Image=data.texture.get_image()
					if image.get_width()*image.get_height()>4 and image.get_used_rect().get_area()>0:expected=declared
				if expected<0:
					for i in range(int(death.get("count",0))-1,-1,-1):
						var index: int=int(p.base)+int(death.get("start",0))+facing*(int(death.get("count",0))+int(death.get("skip",0)))+i
						data=app.resources.frame(p.bank,index)
						if data.is_empty():continue
						var image: Image=data.texture.get_image()
						if image.get_width()*image.get_height()>4 and image.get_used_rect().get_area()>0:expected=index;break
			var actual: int=app.world.visible_corpse_frame(p.bank,p,facing,2.0)
			expect(actual==expected,"visible corpse selection "+name+" direction "+str(direction))
			expect(app.world.visible_corpse_frame(p.bank,p,facing,2.0)==actual,"cached selection stable")
			if declared>=0 and actual<0:unresolved.append({"name":name,"direction":direction})
			if actual>=0 and actual!=declared:fallback_count+=1;rows.append({"name":name,"direction":direction,"declared":declared,"selected":actual})
	var p: Dictionary=EditionRegion.data().monsters["双头血魔"].profile
	var entity: Dictionary={"kind":"monster","bank":p.bank,"profile":p,"hp":0,"direction":0,"motion_time":app.world.elapsed-1000,"spawn_id":"fixture"}
	expect(app.world.actor_frame(entity)==-1,"expired corpse still disappears")
	var disabled: Dictionary=p.duplicate(true);disabled.actions.corpse.count=0
	expect(app.world.visible_corpse_frame(p.bank,disabled,0,2.0)==-1,"explicitly disabled corpse stays disabled")
	for name in ["触龙神","赤月恶魔","幻影蜘蛛"]:
		var definition: Dictionary=EditionRegion.data().monsters[name]
		var special: Dictionary={"kind":"monster","id":"special:"+name,"bank":definition.profile.bank,"profile":definition.profile,"hp":100,"race_image":definition.raw.raceImg,"direction":0,"cell":[20,20],"motion":"attack","motion_time":app.world.elapsed}
		var bounds: Rect2=app.world.actor_idle_bounds(special)
		for direction in range(8):
			special.direction=direction
			expect(app.world.actor_frame(special)==int(definition.profile.base)+(10 if name=="触龙神" else int(definition.profile.actions.attack.start)),"special attack locks body direction "+name)
			expect(app.world.actor_idle_bounds(special)==bounds,"special head bounds stay fixed "+name)
			special.hp=0;special.motion_time=app.world.elapsed-4
			var frame: int=app.world.actor_frame(special)
			expect(frame>=0 and app.resources.frame(special.bank,frame).get("body_visible",false),"special corpse visible for all requested facings "+name)
			special.hp=100;special.motion_time=app.world.elapsed
	for direction in range(8):expect(EditionCreatures.body_direction({"race_image":19,"direction":direction})==direction,"ordinary monster keeps eight directions")
	var centipede: Dictionary=EditionRegion.data().monsters["触龙神"].profile
	var attacker: Dictionary={"kind":"monster","bank":"mon15","profile":centipede,"hp":100,"race_image":33,"direction":7,"motion":"attack","motion_time":0.0}
	var original_elapsed: float=app.world.elapsed
	for i in range(6):
		app.world.elapsed=i*0.12+0.001
		var index: int=app.world.actor_frame(attacker)
		expect(index==10+i,"centipede attack uses critical sequence frame "+str(i))
		expect(app.resources.frame("mon15",index).get("body_visible",false),"critical frame actually visible")
	app.world.elapsed=original_elapsed
	expect(is_equal_approx(EditionCreatures.duration(attacker,"attack",1),0.72),"attack timing uses same six frame definition")
	var effects=load("res://scripts/edition2011/monster_effects.gd")
	for fps in [30,60,120]:
		for tick in range(fps):
			var seconds: float=float(tick)/fps+0.00001
			var effect: int=effects.attack_frame(attacker,seconds)
			expect(effect==(100 if seconds>=0.6 and seconds<0.72 else -1),"body-synced effect boundary at "+str(fps)+" FPS")
	attacker.motion="hurt";expect(effects.attack_frame(attacker,0.65)==-1,"hurt cancels attack layer")
	attacker.motion="attack";attacker.hp=0;expect(effects.attack_frame(attacker,0.65)==-1,"death cancels attack layer")
	attacker.hp=100;attacker.race_image=34;expect(effects.attack_frame(attacker,0.65)==-1,"other bosses do not inherit centipede effect")
	expect(app.resources.frame("mon15",100).get("body_visible",false),"effect image actually visible")
	expect(app.world.monster_effects.material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD,"world effect layer uses additive blending")
	var report:={"checks":checks,"failures":failures,"profiles":seen.size(),"fallback_directions":fallback_count,"fallbacks":rows,"unresolved":unresolved,"scope":"all enabled distinct regional profiles, actual image alpha/size, cached selection, explicit no-corpse and expiry; not per-monster visual pose or combat verification"}
	FileAccess.open("res://../artifacts/world-story/monster-corpse-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));report.erase("fallbacks");print(JSON.stringify(report));app.queue_free()
	for i in range(3):await process_frame
	quit(0 if failures.is_empty() else 1)
