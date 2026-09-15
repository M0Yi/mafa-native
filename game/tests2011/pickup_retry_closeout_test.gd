extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	var path:="/tmp/mafa-pickup-retry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	app.store.path=path;root.add_child(app);app.set_process(false)
	app.start_character({"id":"retry","name":"拾取重试","job":"战士","gender":"女"})
	app.world.paused=false
	var next: Dictionary=app.rules.state.duplicate(true);next.items=[]
	for slot in range(48):next.items.append(EditionInventory.make_item("potion",1,"inventory",slot))
	EditionInventory.mirror(next)
	var cell: Vector2i=app.world.player.cell
	var source:={"cell":[cell.x,cell.y]}
	app.rules.add_ground(next,source,"ore",1);app.rules.add_ground(next,source,"gold",7)
	assert(app.rules.apply(next,"pickup_retry_fixture"))
	var gold: int=app.rules.state.gold
	app.gameplay.assist_left=0.3
	app.gameplay.auto_pickup_underfoot({"pickup":true})
	assert(app.gameplay.assist_left==0.3)
	assert(app.gameplay.pickup_retry_left==2)
	assert(app.rules.state.gold==gold+7 and app.rules.state.ground_loot.size()==1)
	assert(app.rules.state.ground_loot[0].type=="ore")
	app.pending_message="sentinel"
	app.gameplay.auto_pickup_underfoot({"pickup":true})
	assert(app.pending_message=="sentinel")
	app.world.paused=true;app.gameplay.update(1)
	assert(app.gameplay.pickup_retry_left==2)
	app.world.paused=false;app.gameplay.update(0.25)
	assert(app.gameplay.pickup_retry_left==1.75)
	next=app.rules.state.duplicate(true);next.hp=1
	assert(app.rules.apply(next,"low_hp_fixture"))
	assert(app.rules.set_assist("hp",true))
	assert(app.rules.set_assist("pickup",true))
	var potions: int=app.rules.state.inventory.potion
	app.gameplay.assist_left=0
	app.gameplay.update(0.1)
	assert(app.gameplay.pickup_retry_left>0)
	assert(app.rules.state.hp>1 and app.rules.state.inventory.potion==potions-1)
	assert(app.rules.state.ground_loot.size()==1)
	print("PASS: full bag preserves ore, gold still collected, retry does not delay assist, repeated attempt quiet, pause freezes retry, actual auto potion heals and consumes once during pickup backoff")
	app.queue_free();await process_frame;await create_timer(0.2).timeout
	for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
	quit()
