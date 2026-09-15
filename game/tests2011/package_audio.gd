extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var resources:=EditionResources.new();var failures: Array=[]
	if not resources.initialize():printerr(resources.errors);quit(1);return
	var count:=0
	for item in resources.audio_catalog.files:
		var stream:=resources.sound(item.file)
		if stream==null or stream.get_length()<=0:failures.append(item.file)
		else:count+=1
	var report={"package_audio_check":true,"audio_streams":count,"failures":failures,"resource_errors":resources.errors,"architecture":Engine.get_architecture_name(),"legacy_assets_present":FileAccess.file_exists("res://assets/generated/manifest.json")}
	print(JSON.stringify(report));quit(0 if count==780 and failures.is_empty() else 1)
