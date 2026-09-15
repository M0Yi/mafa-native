extends SceneTree
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func click(at: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
	await settle()
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-alignment-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"align","name":"对齐测试","job":"战士","gender":"男"});app.world.paused=true
	app.rules.novice_quest("nv_arrival");app.rules.novice_quest("nv_arrival");app.rules.use_item("wood_sword");app.rules.use_item("robe")
	# Measured borders in raw Prguse 376/377; independent of control definitions.
	var baked:={3:Rect2(130,35,36,32),4:Rect2(130,124,36,32),5:Rect2(4,124,36,32),6:Rect2(130,163,36,32),7:Rect2(4,163,36,32),11:Rect2(130,74,36,32)}
	for screen in [Vector2i(800,600),Vector2i(1280,800),Vector2i(2560,1600)]:
		root.size=screen;app.display_density=2 if screen.x==2560 else 1
		app.show_bag();await settle()
		var bag: Control=app.panel.body.get_child(1)
		expect(bag.caption.get_rect().end.y<=bag.detail.position.y,"bag caption does not overlap detail")
		for child in bag.get_children():
			if child is Button and child.text in ["整理","拆分","翻页"]:expect(child.size==Vector2(56,19),"bag button sheds previous theme minimum size")
		app.windows.close_all()
		for gender in ["男","女"]:
			app.rules.character.gender=gender;app.show_character();await settle()
			var panel: Control=app.panel.body.get_child(1)
			var body: Dictionary=app.resources.frame("prguse",376 if gender=="男" else 377)
			expect(panel.BODY_ORIGIN==panel.LAYER_ORIGIN+body.offset,"body and equipped layers share sprite registration: "+gender)
			expect(Rect2(35,51,173,201).encloses(Rect2(panel.BODY_ORIGIN,body.size)),"paperdoll contained in original interior, not over title/border")
			for i in baked:
				var expected: Rect2=baked[i];expected.position+=panel.BODY_ORIGIN
				expect(panel.slots[i].get_rect()==expected,"accessory hit region matches baked border "+str(i))
				expect(panel.slots.all(func(slot):return slot.get_theme_stylebox("normal") is StyleBoxEmpty),"no duplicate grid or dark rectangle over body")
			for i in [8,9,10,12]:expect(panel.slots[i].position.y>=260,"extra equipment stays in footer")
			for label in panel.extra_labels:expect(label.get_rect().end.y<=280,"footer label above equipment slot")
			for i in range(13):
				for j in range(i+1,13):expect(not panel.slots[i].get_rect().intersects(panel.slots[j].get_rect()),"equipment targets cannot overlap "+str(i)+" / "+str(j)+" "+str(panel.slots[i].get_rect())+" "+str(panel.slots[j].get_rect()))
			app.windows.close_all()
		app.show_quests();await settle()
		var win: EditionWindow=app.panel
		var quests: Control=win.body.get_child(1)
		for index in range(5):
			await click(quests.tabs.get_child(index).get_global_rect().get_center())
			expect(quests.selected==index,"real viewport click selects quest tab")
			expect(win.body.size.y<=win.scroll.size.y,"quest page and action buttons visible without bottom clipping")
			var previous_end:=0.0
			for label in quests.content.get_children():
				expect(label.position.y>=previous_end,"quest text blocks do not overlap")
				previous_end=label.position.y+label.size.y
				expect(label.get_line_count()==label.get_visible_line_count(),"all wrapped quest lines visible")
		app.windows.close_all()
	expect(app.resources.errors.is_empty(),"alignment resources readable")
	var result:={"checks":checks,"failures":failures}
	FileAccess.open("res://../artifacts/alignment-0.8.1/tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
