extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var folder:="/tmp/mafa-resource-entry-"+Crypto.new().generate_random_bytes(8).hex_encode()
 assert(DirAccess.make_dir_recursive_absolute(folder)==OK)
 var original: String=EditionResources.BASE;EditionResources.BASE=folder+"/"
 var file:=FileAccess.open(folder+"/manifest.json",FileAccess.WRITE);file.store_string('{"resource_version":"wrong-version"}');file.close()
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.store.path=folder+"/world.sqlite"
 root.add_child(app)
 assert(app.mode=="error")
 assert(app.pending_message.contains("manifest.json") and app.pending_message.contains("wrong-version") and app.pending_message.contains("2.0.1.11"))
 assert(not app.store.opened and not FileAccess.file_exists(app.store.path))
 var owned: Array=[weakref(app.world),weakref(app.gameplay),weakref(app.entry.canvas)]
 app.queue_free();await process_frame
 assert(owned.all(func(reference):return reference.get_ref()==null))
 DirAccess.remove_absolute(folder+"/manifest.json")
 var missing:=EditionResources.new();assert(not missing.initialize())
 assert(missing.errors[folder+"/manifest.json"]=="文件缺失")
 EditionResources.BASE=original;DirAccess.remove_absolute(folder)
 print("PASS: incompatible manifest names file and versions; missing manifest keeps original error; startup leaves no save or orphan nodes")
 quit()
