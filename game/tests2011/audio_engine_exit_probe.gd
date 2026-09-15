extends SceneTree
# Standalone diagnostic: no game, asset, SQLite, or account dependencies.
func _initialize():call_deferred("run")
func run() -> void:
 var player:=AudioStreamPlayer.new();root.add_child(player)
 player.stream=AudioStreamGenerator.new();player.play()
 player.stop();player.stream=null
 print("PROBE: generated audio stopped and cleared before SceneTree.quit; engine=",Engine.get_version_info().string)
 quit()
