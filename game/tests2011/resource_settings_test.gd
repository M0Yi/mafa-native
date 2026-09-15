extends SceneTree
class Probe extends "res://scripts/edition2011/bootstrap.gd":
	var accepted:=""
	func _ready() -> void:build_ui()
	func launch(path: String) -> void:accepted=path
var failures: Array=[]
func _initialize():call_deferred("run")
func check(condition: bool,message: String) -> void:
	if not condition:failures.append(message)
func run() -> void:
	var folder:="/tmp/mafa-settings-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(folder)
	var node:=Probe.new();node.settings_path=folder.path_join("resources.cfg");root.add_child(node)
	var cfg:=ConfigFile.new();cfg.set_value("resources","root","old");cfg.set_value("future","keep",42);cfg.save(node.settings_path)
	node.save_and_launch("new")
	cfg.load(node.settings_path)
	check(node.accepted=="new" and cfg.get_value("resources","root")=="new","successful save did not launch")
	check(cfg.get_value("future","keep")==42,"unrelated settings lost")
	node.accepted=""
	FileAccess.open(node.settings_path,FileAccess.WRITE).store_string("[broken")
	node.save_and_launch("replacement")
	check(node.accepted.is_empty(),"corrupt configuration launched")
	check(FileAccess.get_file_as_string(node.settings_path)=="[broken","corrupt configuration overwritten")
	node.settings_path=folder.path_join("absent/resources.cfg")
	node.save_and_launch("unwritable")
	check(node.accepted.is_empty() and node.status.text.contains("无法保存"),"write failure not surfaced")
	check(DirAccess.get_files_at(folder).size()==1,"temporary settings leaked")
	DirAccess.remove_absolute(folder.path_join("resources.cfg"));DirAccess.remove_absolute(folder)
	var report:={"failures":failures,"scope":"isolated real config writes; preserve unrelated fields, preserve corrupt config, missing-parent write failure; no user settings touched"}
	FileAccess.open("res://../artifacts/closeout-resource-settings.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	node.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
