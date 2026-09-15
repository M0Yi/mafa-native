extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-mute-feedback-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.play_sound_id(108)
 var player: AudioStreamPlayer=app.effects[(app.effect_index-1)%app.effects.size()]
 assert(player.stream!=null)
 var stream=player.stream
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 assert(not app.toggle_mute() and not app.muted and player.stream==stream)
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 assert(app.toggle_mute() and app.muted and app.music.stream_paused)
 assert(player.stream==null and not player.playing)
 var index: int=app.effect_index
 app.play_sound_id(108);assert(app.effect_index==index)
 app.music_name("field2.wav")
 var current_music=app.resources.sound("field2.wav")
 assert(current_music!=null and app.music.stream==current_music and not app.music.playing)
 assert(app.toggle_mute() and not app.muted and not app.music.stream_paused)
 assert(app.music.stream==current_music and app.music.playing)
 assert(player.stream==null and not player.playing)
 assert(app.store.read_metadata("muted")=="false")
 app.play_sound_id(108);assert(app.effect_index==index+1)
 print("PASS: music changed while muted resumes the current track")
 print("PASS: mute stops transient audio, unmute does not replay stale effects; save failure preserves state and retry persists")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
