extends SceneTree
var app
func _initialize() -> void:call_deferred("run")
func run() -> void:
	app=load("res://edition2011.tscn").instantiate();app.allow_focus_pause=false
	app.store.path=OS.get_environment("TMPDIR")+"mafa-novice-preview-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
	root.add_child(app)
	for i in range(6):await process_frame
	app.start_character({"id":"novice-preview","name":"边界村旅人","job":"战士","gender":"男"})
	print("NOVICE_PREVIEW_READY ",app.store.path)
