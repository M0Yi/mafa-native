extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-skill-refresh-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"refresh","name":"技能刷新","job":"法师","gender":"女"});app.world.paused=false
 var view=load("res://scripts/edition2011/ui/skill_panel.gd").new();app.add_child(view);view.setup(app)
 view.selected="fireball";view.refresh()
 var next: Dictionary=app.rules.state.duplicate(true);next.gold=10000
 assert(app.rules.apply(next,"money_fixture"));assert(app.rules.shop("ref:14",1))
 view._process(0.1)
 assert(view.observed_state.books.get("ref:14",0)==1)
 var buttons: Array=view.details.get_children().filter(func(c):return c is Button and c.text.begins_with("使用《"))
 assert(buttons.size()==1 and buttons[0].disabled)
 next=app.rules.state.duplicate(true);next.level=7
 assert(app.rules.apply(next,"level_fixture"));view._process(0.1)
 buttons=view.details.get_children().filter(func(c):return c is Button and c.text.begins_with("使用《"))
 assert(buttons.size()==1 and not buttons[0].disabled)
 var book: Dictionary={}
 for item in app.rules.state.items:
  if item.type=="ref:14":book=item;break
 assert(app.rules.learn_book(book));view._process(0.1)
 assert(view.selected=="fireball" and view.observed_state.skills.has("fireball"))
 assert(not view.details.get_children().any(func(c):return c is Button and c.text.begins_with("使用《")))
 var first: Node=view.details.get_child(0)
 next=app.rules.state.duplicate(true);next.gold+=1;next.skills.fireball.proficiency+=1
 assert(app.rules.apply(next,"unrelated_reward"));view._process(0.1)
 assert(view.details.get_child(0)==first)
 app.start_character({"id":"accuracy","name":"准确刷新","job":"道士","gender":"女"})
 view.selected="spirit";view.refresh()
 var baseline: int=app.rules.melee_accuracy()
 next=app.rules.state.duplicate(true)
 var gear: Dictionary={}
 for type in EditionRules.ITEMS:
  if EditionRules.item_accuracy(type)>0:
   var slot: int=EditionInventory.equip_slot(next,type)
   if slot<0:continue
   next.items=next.items.filter(func(item):return item.container!="equipment" or int(item.slot)!=slot)
   gear=EditionInventory.make_item(type,1,"equipment",slot);next.items.append(gear);break
 assert(not gear.is_empty());EditionInventory.mirror(next)
 assert(app.rules.apply(next,"accuracy_equipment_fixture"));view._process(0.1)
 assert(view.observed_state.accuracy>baseline)
 assert(view.details.get_children().any(func(c):return c is Label and c.text.contains("当前准确：%d"%app.rules.melee_accuracy())))
 next=app.rules.state.duplicate(true);EditionInventory.find_item(next,gear.uid).durability=0;EditionInventory.mirror(next)
 assert(app.rules.apply(next,"broken_equipment_fixture"));view._process(0.1)
 assert(view.observed_state.accuracy==baseline)
 print("PASS: spirit description follows equipment accuracy and broken durability")
 print("PASS: open skill panel follows book purchase, level and external learning; unrelated rewards preserve controls")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
