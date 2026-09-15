extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-controller-stale-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"stale","name":"旧物品选择","job":"战士","gender":"女"})
 app.game_panel("手柄操作")
 var view=load("res://scripts/edition2011/ui/controller_panel.gd").new();app.form.add_child(view);view.setup(app)
 app.world.paused=false
 var pause_event:=InputEventJoypadButton.new();pause_event.button_index=JOY_BUTTON_START;pause_event.pressed=true
 root.push_input(pause_event,true)
 assert(app.world.paused,"Start must reach global pause with controller panel open")
 var paused_state:Dictionary=app.rules.state.duplicate(true)
 for key in [JOY_BUTTON_A,JOY_BUTTON_Y]:
  var action_event:=InputEventJoypadButton.new();action_event.button_index=key;action_event.pressed=true
  root.push_input(action_event,true)
 assert(app.rules.state==paused_state,"Paused panel must not use or bind inventory items")

 root.push_input(pause_event,true)
 assert(not app.world.paused,"Start must resume with controller panel open")
 print("PASS: viewport Start input pauses and resumes while controller panel is open")
 print("PASS: paused viewport confirm and bind inputs preserve inventory state")
 app.gameplay.show_assist()
 root.push_input(pause_event,true);assert(app.world.paused)
 root.push_input(pause_event,true);assert(not app.world.paused)
 app.windows.close("内挂设置")
 print("PASS: viewport Start input pauses and resumes with assist settings open")
 var initial: Dictionary=app.rules.state.duplicate(true)
 app.windows.confirm("物品确认隔离",func():pass)
 view.list.item_activated.emit(0);view.operate(true)
 assert(app.rules.state==initial)
 app.windows.modal.canceled.emit();app.windows.modal.hide()
 var row: Dictionary=view.rows[0].duplicate(true)
 assert(app.rules.inventory_action("move",{"uid":row.uid,"container":"warehouse","slot":0}))
 var before: Dictionary=app.rules.state.duplicate(true)
 view.operate()
 assert(app.rules.state==before and app.pending_message.contains("物品已移动"))
 view.rows=[row];view.cursor=0;view.operate(true)
 assert(app.rules.state==before)
 view.refresh();assert(view.rows.size()>=2)
 view.cursor=1;view.list.select(1)
 var selected_uid: String=view.rows[1].uid
 var earlier_uid: String=view.rows[0].uid
 assert(app.rules.inventory_action("move",{"uid":earlier_uid,"container":"warehouse","slot":1}))
 view._process(0.1)
 assert(view.cursor==0 and view.rows[view.cursor].uid==selected_uid)
 assert(view.list.get_selected_items()==PackedInt32Array([0]))
 before=app.rules.state.duplicate(true)
 print("PASS: controller selection follows item identity when an earlier row disappears")
 app.windows.close("手柄操作");view.rows=[row];view.cursor=0;view.operate()
 assert(app.rules.state==before)
 app.show_controller_story(app.rules.story_npc("border:elder"))
 var tasks=app.form.get_child(1)
 assert(not tasks.rows.is_empty())
 var task_id: String=tasks.rows[0].id
 tasks.navigation_history.append({"related_from":"","cursor":999,"selected_id":task_id,"reading":true,"prerequisites":false})
 tasks.reading=false;tasks.back()
 assert(tasks.reading and tasks.rows[tasks.cursor].id==task_id)
 tasks.reading=false
 tasks.navigation_history.append({"related_from":"","cursor":0,"selected_id":"missing-history-task","reading":true,"prerequisites":false})
 tasks.back();assert(not tasks.reading and tasks.list.visible)
 print("PASS: task history restores identity and never opens a replacement task")
 before=app.rules.state.duplicate(true)
 app.windows.confirm("任务确认隔离",func():pass);tasks.operate();assert(app.rules.state==before)
 app.windows.modal.canceled.emit();app.windows.modal.hide()
 app.windows.close("手柄人物委托");tasks.operate();assert(app.rules.state==before)
 app.show_controller_story(app.rules.story_npc("border:elder"))
 var replacement=app.windows.windows["手柄人物委托"]
 tasks.reading=false;tasks.navigation_history.clear();tasks.back()
 var back_event:=InputEventJoypadButton.new();back_event.button_index=JOY_BUTTON_B;back_event.pressed=true
 tasks._input(back_event)
 assert(app.windows.windows.get("手柄人物委托")==replacement)
 assert(app.rules.state==before)
 print("PASS: closed controller task back callbacks preserve replacement window")
 for spec in [["controller_panel","手柄操作"],["controller_warehouse","手柄仓库"],["controller_skill_guide","手柄技能指引"]]:
  app.game_panel(spec[1])
  var old=load("res://scripts/edition2011/ui/"+spec[0]+".gd").new()
  app.form.add_child(old)
  if spec[0]=="controller_panel":old.setup(app)
  elif spec[0]=="controller_warehouse":old.setup(app,{"id":"fixture","name":"测试仓库"})
  else:old.setup(app,{})
  old.set_process(false)
  app.windows.close(spec[1]);app.game_panel(spec[1])
  var current=app.windows.windows[spec[1]]
  old._input(back_event)
  assert(app.windows.windows.get(spec[1])==current and app.rules.state==before)
 app.game_panel("手柄操作")
 var tracking=load("res://scripts/edition2011/ui/controller_panel.gd").new();app.form.add_child(tracking);tracking.setup(app)
 var tracked_id: String=EditionRules.Story.data().quests[0].id
 var tracked: Dictionary=app.rules.state.duplicate(true);tracked.quests[tracked_id]="accepted";tracked.tracked_story=tracked_id
 assert(app.rules.apply(tracked,"controller_tracking_fixture"))
 tracking.page=3;tracking.refresh()
 var untrack:=InputEventJoypadButton.new();untrack.button_index=JOY_BUTTON_Y;untrack.pressed=true
 before=app.rules.state.duplicate(true)
 app.world.paused=true;tracking._input(untrack)
 assert(app.rules.state==before)
 app.world.paused=false
 var dead: Dictionary=app.rules.state.duplicate(true);dead.hp=0
 assert(app.rules.apply(dead,"controller_dead_tracking_fixture"))
 before=app.rules.state.duplicate(true);tracking._input(untrack);assert(app.rules.state==before)
 var alive: Dictionary=app.rules.state.duplicate(true);alive.hp=app.rules.max_hp()
 assert(app.rules.apply(alive,"controller_resume_tracking_fixture"))
 tracking._input(untrack);assert(app.rules.state.tracked_story=="")
 assert(app.store.load_world("stale").tracked_story=="")
 print("PASS: controller untrack preserves state while paused or dead and saves after resume")
 print("PASS: detached controller inventory, warehouse and skill-guide inputs preserve new windows")
 print("PASS: controller task callback cannot execute behind modal or after closing")
 print("PASS: stale controller item cannot use or bind after warehouse transfer; detached panel cannot operate")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
