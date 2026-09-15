extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var cached=JSON.parse_string(FileAccess.get_file_as_string("res://../.cache/frozen-import-test/import-status.json"))
	EditionResources.BASE=str(cached.root).path_join("client2011/")
	EditionResources.SUPPLEMENT_BASE=str(cached.root).path_join("supplement16/")
	var resources:=EditionResources.new()
	if not resources.initialize():printerr(resources.errors);quit(1);return
	var names: Dictionary={}
	for row in resources.audio_catalog.files:names[str(row.file).to_lower()]=true
	for name in resources.supplement.get("audio",{}):names[name]=true
	var failures: Array=[];var decoded:=0
	for name in names:
		print("DECODE_FILE ",name)
		var stream=resources.sound(name)
		if stream==null or stream.get_length()<=0:failures.append({"file":name,"reason":"decode failed or empty duration"})
		else:decoded+=1
		if (decoded+failures.size())%100==0:await process_frame
	for name in ["flashbox.wav","newysound3.wav"]:
		var original:=FileAccess.get_file_as_bytes(EditionResources.BASE+"audio/"+name)
		var expected:=original.slice(0,original.size()-44)
		expected.encode_u32(4,expected.size()-8)
		if resources.wav_runtime_bytes(original)!=expected:failures.append({"file":name,"reason":"normalization changed more than empty trailing sampler metadata"})
		var with_loop:=original.duplicate()
		with_loop.encode_u32(with_loop.size()-8,1)
		if resources.wav_runtime_bytes(with_loop)!=with_loop:failures.append({"file":name,"reason":"nonempty loop metadata altered"})
	var missing: Dictionary={}
	for id in resources.audio_catalog.sound_ids:
		var name: String=resources.audio_catalog.sound_ids[id]
		if not name.is_empty() and not names.has(name.to_lower()):missing[id]=name
	var report:={"files":names.size(),"decoded":decoded,"failures":failures,"missing_index_references":missing,"scope":"runtime AudioStream WAV decode and nonzero duration from external base/supplement cache; missing index references may be unused; no audible playback or timing acceptance"}
	FileAccess.open("res://../artifacts/closeout-audio-decode.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
