class_name ClassicAudio
extends Node

var streams: Dictionary = {}
var music := AudioStreamPlayer.new()
var voices: Array[AudioStreamPlayer] = []
var master := 0.75
var music_volume := 0.38
var effects_volume := 0.85
var muted := false
var directory := "user://"
var error_message := ""
var next_voice := 0
var foot_stamp := ""
var events: Dictionary = {}
var last_frames: Dictionary = {}

func configure(base := "res://assets/generated", autoplay := true) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(base+"/audio.json"))
	if not data is Dictionary or data.get("format_version") != 1:
		error_message = "音频清单无效："+base+"/audio.json"
		return false
	for key in data.sounds:
		var path: String = base+"/"+str(data.sounds[key].file)
		if not ResourceLoader.exists(path):
			error_message = "缺少声音资源："+path
			return false
		var stream := load(path) as AudioStream
		if stream == null or stream.get_length() <= 0:
			error_message = "无法解码声音："+path
			return false
		streams[key] = stream
	add_child(music)
	music.stream = streams[str(data.music)].duplicate()
	if music.stream is AudioStreamMP3: music.stream.loop = true
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	load_settings()
	apply_volumes()
	if autoplay: music.play()
	return true

func load_settings() -> void:
	var path := directory.path_join("audio.cfg")
	if not FileAccess.file_exists(path): return
	var config := ConfigFile.new()
	var valid := config.load(path) == OK
	if valid:
		for key in ["master","music","effects"]:
			var v = config.get_value("audio",key,-1)
			if not (v is float or v is int) or not is_finite(float(v)) or float(v) < 0 or float(v) > 1: valid = false
		if not config.has_section_key("audio","muted") or not config.get_value("audio","muted",false) is bool: valid = false
	if not valid:
		master=0.75; music_volume=0.38; effects_volume=0.85; muted=false
		DirAccess.rename_absolute(path,path+".corrupt-%d" % Time.get_unix_time_from_system())
		error_message = "音量设置损坏，已保留备份并恢复默认音量。"
		return
	master = float(config.get_value("audio","master"))
	music_volume = float(config.get_value("audio","music"))
	effects_volume = float(config.get_value("audio","effects"))
	muted = config.get_value("audio","muted")

func save_settings() -> bool:
	DirAccess.make_dir_recursive_absolute(directory)
	var config := ConfigFile.new()
	config.set_value("audio","master",master)
	config.set_value("audio","music",music_volume)
	config.set_value("audio","effects",effects_volume)
	config.set_value("audio","muted",muted)
	var path := directory.path_join("audio.cfg")
	return config.save(path+".tmp") == OK and DirAccess.rename_absolute(path+".tmp",path) == OK

func apply_volumes() -> void:
	music.volume_db = linear_to_db(maxf(0.00001,master*music_volume if not muted else 0.0))
	for voice in voices:
		voice.volume_db = linear_to_db(maxf(0.00001,master*effects_volume if not muted else 0.0))-6.0

func play_sound(key: String, gain := 1.0) -> void:
	if not streams.has(key): return
	var frame := Engine.get_process_frames()
	if int(last_frames.get(key,-1))==frame: return
	last_frames[key]=frame
	var voice := voices[next_voice]
	next_voice = (next_voice+1) % voices.size()
	voice.stop()
	voice.stream = streams[key]
	voice.volume_db = linear_to_db(maxf(0.00001,master*effects_volume*gain if not muted else 0.0))-6.0
	voice.play()
	events[key] = int(events.get(key,0))+1

func footsteps(player: ClassicPlayer) -> void:
	if player.action not in ["walk","run"]: return
	var frame := player.frame()
	if frame not in [1,4]: return
	var stamp := "%s/%d/%d" % [player.action,player.completed_steps,frame]
	if stamp == foot_stamp: return
	foot_stamp = stamp
	var id := 0x01000003 if player.action == "run" else 0x01000001
	play_sound("%08X" % (id+int(frame==4)),0.6)

func skill_sound(skill: Dictionary, phase: int) -> void:
	var key: String = skill.sounds.get(str(phase),"")
	if not key.is_empty(): play_sound(key)

func _exit_tree() -> void:
	music.stop()
	music.stream=null
	for voice in voices:
		voice.stop()
		voice.stream=null
	streams.clear()
