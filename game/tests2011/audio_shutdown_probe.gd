extends SceneTree
# Diagnostic only: compare explicit stop while in tree with parent exit cleanup.
class AudioHost extends Node:
 var players: Array=[]
 func stop_audio() -> void:
  for player in players:player.stop();player.stream=null
 func _exit_tree() -> void:stop_audio()
func _initialize():call_deferred("run")
func run() -> void:
 var host:=AudioHost.new();root.add_child(host)
 for file in ["field2.wav","108.wav"]:
  var player:=AudioStreamPlayer.new();host.add_child(player)
  player.stream=load("res://assets/client2011/audio/"+file);player.play();host.players.append(player)
 if not "--same-frame" in OS.get_cmdline_user_args():await create_timer(0.1).timeout
 var early: bool="--early-stop" in OS.get_cmdline_user_args()
 if early:host.stop_audio()
 host.queue_free()
 await process_frame
 await create_timer(0.2).timeout
 print("PROBE: audio parent freed; early stop = ",early,"; same frame = ","--same-frame" in OS.get_cmdline_user_args())
 quit()
