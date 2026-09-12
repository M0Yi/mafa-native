extends CanvasLayer
const CHAPTERS={"story_letter:accept":"离开村庄","story_dragon_survey:accept":"火龙神殿 · 出征","story_dragon_trial:submit":"从烈焰中归来"}
const VOICE={"战士":"握紧武器，守住退路。下一场战斗，需要的不只是勇气。","法师":"火光之外仍有未知。记住来路，也记住每一次施法的代价。","道士":"生者的归途比战果更重要。备好符药，再踏入这片土地。"}
var app
var elapsed:=0.0
var previous_pause:=false
var previous_ui:=true
var previous_pan:=Vector2.ZERO
var finished:=false
var caption: Label
var beats: Array[String]=[]
static func play(host,quest: Dictionary,operation: String) -> void:
	var key: String=str(quest.id)+":"+operation
	if not CHAPTERS.has(key) or host.get_tree().get_nodes_in_group("story_cinematic").size()>0:return
	var scene=load("res://scripts/edition2011/ui/story_cinematic.gd").new()
	scene.app=host;scene.beats.assign([CHAPTERS[key],str(host.rules.character.name)+" · "+str(host.rules.character.job)+"\n"+str(VOICE.get(host.rules.character.job,"")),str(quest.dialogue if operation=="accept" else quest.completion)])
	host.add_child(scene)
func _ready() -> void:
	layer=100;add_to_group("story_cinematic")
	previous_pause=app.world.paused;app.world.paused=true
	previous_ui=app.layer.visible;app.layer.hide();previous_pan=app.world.cinematic_pan
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root);root.add_to_group("edition_blocking_dialog")
	var shade:=ColorRect.new();shade.color=Color(0,0,0,0.48);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(shade)
	var box:=VBoxContainer.new();box.set_anchors_and_offsets_preset(Control.PRESET_CENTER);box.grow_horizontal=Control.GROW_DIRECTION_BOTH;box.grow_vertical=Control.GROW_DIRECTION_BOTH;box.custom_minimum_size=Vector2(560,180);root.add_child(box)
	caption=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_override("font",app.font);caption.add_theme_font_size_override("font_size",24);caption.custom_minimum_size=Vector2(0,150);box.add_child(caption)
	var skip:=Button.new();skip.text="跳过 / 继续 · Esc / 手柄 B";skip.pressed.connect(finish);box.add_child(skip)
	_process(0)
func _process(delta: float) -> void:
	if finished:return
	elapsed+=delta
	app.world.cinematic_pan=previous_pan+Vector2(sin(elapsed/12.0*PI)*24,0)
	app.world.update_camera(get_viewport().get_visible_rect().size)
	app.world.queue_redraw()
	if elapsed>=12:finish();return
	caption.text=beats[mini(2,int(elapsed/4))]
	caption.modulate.a=clampf(minf(fmod(elapsed,4.0),4.0-fmod(elapsed,4.0))/0.4,0,1)
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_SPACE,KEY_ENTER]:get_viewport().set_input_as_handled();finish()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B]:get_viewport().set_input_as_handled();finish()
func finish() -> void:
	if finished:return
	finished=true
	app.world.paused=previous_pause or not app.windows.pause_reason.is_empty()
	app.layer.visible=previous_ui;app.world.cinematic_pan=previous_pan
	app.world.update_camera(get_viewport().get_visible_rect().size)
	queue_free()
