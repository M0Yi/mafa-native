extends SceneTree

var app
var checks:=0
var failures: Array=[]
var sounds: Array=[]

func _initialize() -> void:call_deferred("run")
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr("FAIL: ",note)
func run() -> void:
	app=load("res://edition2011.tscn").instantiate()
	app.store.path=OS.get_environment("TMPDIR")+"mafa-selection-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app)
	await process_frame
	app.entry.set_process(false)
	app.sound_started.connect(func(id):sounds.append(id))
	var entry: EditionEntry=app.entry
	for job in range(3):
		for sex in range(2):
			app.accounts.data={"version":1,"accounts":[{"id":"f".repeat(32),"username":"selection","salt":"0".repeat(32),"hash":"0".repeat(64),"iterations":LocalAccounts.ITERATIONS,"characters":[]}]}
			app.accounts.current_id="f".repeat(32)
			var c: Dictionary=app.accounts.create_character("选角测试",LocalAccounts.JOBS[job],LocalAccounts.GENDERS[sex])
			var other: Dictionary=app.accounts.create_character("另一个角色","战士","男")
			var base:=job*40+sex*120
			for fps in [30,60,120]:
				entry.selected_id="";entry.previous_id="";sounds.clear();entry.show_page("roster")
				entry._process(0)
				expect(entry.selection_effect.visible,"revival overlay starts with selection")
				expect(entry.portrait_frame(c)==60+base,"first stone frame")
				# Exercise the production process/render frame selectors for two idle cycles.
				var idle_frames: Dictionary={};var overlay_after_revival:=false;var invalid_idle:=false
				for tick in range(fps*11):
					entry._process(1.0/fps)
					if entry.selection_time>=0.65:
						overlay_after_revival=overlay_after_revival or entry.selection_effect.visible
						var frame:=entry.portrait_frame(c);idle_frames[frame]=true
						invalid_idle=invalid_idle or frame<40+base or frame>=56+base
						if not app.resources.frame("chrsel",frame).has("texture"):invalid_idle=true
				expect(not overlay_after_revival,"overlay stays hidden after revival at "+str(fps)+" FPS")
				expect(not invalid_idle and idle_frames.size()==16,"all sixteen idle frames loop for "+c.job+c.gender)
				expect(sounds==[101],"no repeated selection sound during idle")
				var elapsed:=entry.selection_time;entry.select_character(c.id)
				expect(entry.selection_time==elapsed and sounds==[101],"same selection cannot restart revival")
				entry.select_character(other.id);entry._process(0)
				expect(entry.selection_effect.visible,"new selection starts its revival")
				expect(entry.portrait_frame(c)==72+base,"previous character starts reverse freeze")
				entry._process(2.0)
				expect(not entry.selection_effect.visible and entry.portrait_frame(c)==60+base,"large time step finishes transition without replay")
	var result:={"checks":checks,"failures":failures,"scope":"six portraits, 30/60/120 FPS, two idle cycles, repeat selection and frame stalls"}
	FileAccess.open("res://../artifacts/ui-fix/selection-transition.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));app.queue_free();await process_frame;await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
