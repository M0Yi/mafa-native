extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var res:=EditionResources.new();var failures: Array=[];var checks:=0
	if not res.initialize():failures.append("initialize")
	for bank in res.supplement.get("frames",{}):
		for key in res.supplement.frames[bank]:
			checks+=1
			var expected: Array=res.supplement.frames[bank][key];var f:=res.frame(bank,int(key))
			if f.is_empty() or f.size!=Vector2(expected[2],expected[3]) or f.offset!=Vector2(expected[4],expected[5]):failures.append(bank+":"+key)
	checks+=1
	if res.frame_location("smtiles",0).get("pack")!="smtiles":failures.append("base frame was replaced")
	checks+=1
	if res.frame_location("smtiles2",1120).get("pack")!="@supplement16":failures.append("supplement pack not used")
	checks+=1
	var sound:=res.sound("m11-1.wav")
	if sound==null or sound.get_length()<=0:failures.append("missing recovered lightning sound")
	checks+=1
	if not res.world_catalog.hjsbk.missing_references.is_empty():failures.append("resolved chamber still marked missing")
	checks+=1
	if res.world_catalog.d2083.missing_references.is_empty():failures.append("unresolved raw boundary gaps were hidden")
	var report:={"checks":checks,"failures":failures,"resource_errors":res.errors,"lightning_seconds":sound.get_length() if sound!=null else 0}
	FileAccess.open("res://../artifacts/client16/runtime-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	quit(0 if failures.is_empty() and res.errors.is_empty() else 1)
