extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-story-filter-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"filter","name":"委托筛选","job":"战士","gender":"女"})
 var q: Dictionary=Story.quest("story_book")
 var view=load("res://scripts/edition2011/ui/story_panel.gd").new();app.add_child(view);view.setup(app)
 var calls: Array=[]
 var obsolete: Button=view.action(view.details,"临时操作",func():calls.append("called"))
 obsolete.disabled=true;obsolete.pressed.emit();assert(calls.is_empty())
 obsolete.disabled=false;obsolete.pressed.emit();assert(calls==["called"]);calls.clear()
 view.refresh();obsolete.pressed.emit();assert(calls.is_empty())
 var next: Dictionary=app.rules.state.duplicate(true)
 for id in q.requires:next.quests[id]="done"
 assert(app.rules.apply(next,"prerequisite_fixture"));view._process(0.1)
 view.available_only=true;view.refresh()
 assert(view.filtered_choices().any(func(row):return row.id==q.id))
 next=app.rules.state.duplicate(true);next.quests[q.id]="accepted"
 assert(app.rules.apply(next,"accepted_fixture"));view._process(0.1)
 assert(not view.visible_quest_ids.has(q.id))
 view.available_only=false;view.active_only=true;view.refresh()
 assert(view.visible_quest_ids.has(q.id))
 view.selected=q.id;view.refresh()
 var abandon: Button=null
 for child in view.details.get_children():
  if child is Button and child.text=="放弃此任务":abandon=child
 assert(abandon!=null);abandon.pressed.emit()
 var before: Dictionary=app.rules.state.duplicate(true)
 app.world.paused=true;app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(app.rules.state==before and app.pending_message.contains("继续游戏"))
 app.world.paused=false
 print("PASS: pausing after opening abandon confirmation preserves the task")
 next=app.rules.state.duplicate(true);next.quests[q.id]="done"
 assert(app.rules.apply(next,"completed_fixture"));view._process(0.1)
 assert(not view.visible_quest_ids.has(q.id))
 view.active_only=false;view.status_filter="已完成";view.refresh()
 assert(view.visible_quest_ids.has(q.id))
 for row in view.filtered_choices():assert(app.rules.state.quests.get(row.id)=="done")
 print("PASS: story filters update after acceptance and completion; completed archive contains only completed quests")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
