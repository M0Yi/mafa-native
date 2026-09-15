extends SceneTree
func _initialize():call_deferred("run")
func run():
 var temporary:="/tmp/mafa-bootstrap-empty-"+Crypto.new().generate_random_bytes(8).hex_encode()
 assert(DirAccess.make_dir_recursive_absolute(temporary)==OK)
 var config_path:=temporary+"/resources.cfg"
 var cfg:=ConfigFile.new()
 cfg.set_value("resources","root",temporary+"/missing-client")
 assert(cfg.save(config_path)==OK)
 var original:=FileAccess.get_file_as_bytes(config_path)
 var app=load("res://bootstrap.tscn").instantiate()
 app.settings_path=config_path;app.cache_parent=temporary+"/cache"
 root.add_child(app)
 await process_frame
 assert(is_instance_valid(app.choose) and not app.choose.disabled)
 assert(app.status.text.contains("缓存不存在或不完整"))
 assert(app.pid==-1 and app.output.is_empty())
 assert(not DirAccess.dir_exists_absolute(app.cache_parent))
 assert(FileAccess.get_file_as_bytes(config_path)==original)
 assert(DirAccess.get_files_at(temporary)==PackedStringArray(["resources.cfg"]))
 assert(app.source.editable and app.supplement_source.editable)
 app.queue_free();await process_frame
 DirAccess.remove_absolute(config_path);DirAccess.remove_absolute(temporary)
 print("PASS: missing client cache keeps resource setup interactive; no worker, cache or save created; settings preserved")
 quit()
