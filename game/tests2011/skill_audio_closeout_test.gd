extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	var res:=EditionResources.new()
	if not res.initialize():printerr(res.errors);quit(1);return
	var rows: Array=[];var missing: Array=[]
	var evidence_path:="res://../release/SKILL_AUDIO_SOURCE_EVIDENCE.json"
	var evidence=JSON.parse_string(FileAccess.get_file_as_string(evidence_path))
	if not evidence is Dictionary or not evidence.get("single_stage_skills") is Dictionary:
		printerr("Invalid skill audio source evidence: "+evidence_path);quit(1);return
	var source_gaps: Array=[]
	for skill in EditionGameplay.SKILLS:
		var spec: Dictionary=EditionGameplay.SKILLS[skill]
		for stage in range(3):
			var id:=10000+int(spec.serial)*10+stage
			var melee:=EditionGameplay.melee_skill_sound(skill)
			if melee>=0:id=melee if stage==1 else -1
			var name: String=res.audio_catalog.sound_ids.get(str(id),"")
			var status:="passive" if spec.get("passive",false) else "silent_index" if name.is_empty() and res.audio_catalog.sound_ids.has(str(id)) else "unlisted" if name.is_empty() else "available"
			if melee>=0 and stage!=1:status="melee_action_no_separate_stage"
			if status=="available":
				var sound:=res.sound(name)
				if sound==null or sound.get_length()<=0:status="missing_or_invalid"
			var row:={"skill":skill,"stage":stage,"id":id,"file":name,"status":status}
			var source_spec: Dictionary=evidence.single_stage_skills.get(skill,{})
			if status=="unlisted" and float(id) in source_spec.get("absent",[]):
				row["source_classification"]="absent_in_both_client_indexes"
				row["evidence"]="release/SKILL_AUDIO_SOURCE_EVIDENCE.json"
				row["resolution"]="pending playback/reference review; source absence does not establish intended silence"
				source_gaps.append(row)
			rows.append(row)
			if status in ["unlisted","missing_or_invalid"]:missing.append(row)
	var report:={"scope":"implemented skill serials, stages 0/1/2 from current cast scheduling; mapping and decode only, not audible timing","rows":rows,"missing":missing,"source_documented_gaps":source_gaps,"passed":missing.is_empty()}
	FileAccess.open("res://../artifacts/closeout-skill-audio.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"stages":rows.size(),"missing":missing}))
	res.sounds.clear();quit(0 if missing.is_empty() else 1)
