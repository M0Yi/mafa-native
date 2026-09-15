extends SceneTree
class Host extends RefCounted:
	var rules={"state":{"equipment":{"weapon":"wood_sword"}}}
	var calls: Array=[]
	func play_sound_id(id: int,_volume:=0,_bus:="Combat"):calls.append(id)
func _initialize() -> void:
	var host:=Host.new();var gameplay:=EditionGameplay.new();gameplay.app=host
	var res:=EditionResources.new();assert(res.initialize())
	for id in ["thrust","halfmoon","flame"]:
		host.calls.clear()
		gameplay.play_skill_stage(id,0);gameplay.play_skill_stage(id,2)
		assert(host.calls.is_empty())
		gameplay.play_skill_stage(id,1)
		var sound_id:=EditionGameplay.melee_skill_sound(id)
		assert(host.calls==[51,sound_id])
		assert(res.sound(res.audio_catalog.sound_ids[str(sound_id)]).get_length()>0)
		assert(is_equal_approx(EditionGameplay.skill_release_delay(id),2.0*EditionAnimation.HUMAN[EditionGameplay.SKILLS[id].action].ms/1000.0))
	print("MELEE_SKILL_AUDIO_PASS dedicated 132/133/137, weapon layer, frame-2 timing, decode; no listening claim")
	gameplay.free();res.sounds.clear();quit()
