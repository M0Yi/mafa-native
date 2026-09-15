extends SceneTree
class Host extends Node:
	var mode:="game"
	var world:={"paused":false,"metadata":{"id":"0"}}
	var resources:={"memory_bytes":0}
func _initialize():call_deferred("run")
func run() -> void:
	var host:=Host.new();root.add_child(host)
	var recorder=load("res://tests2011/closeout_performance_recorder.gd").new()
	var path:="/tmp/mafa-performance-test-"+Crypto.new().generate_random_bytes(8).hex_encode()+".jsonl"
	if not recorder.setup(host,path):quit(1);return
	root.add_child(recorder)
	await create_timer(0.2).timeout
	recorder.sample_at=-5000
	for i in range(3):await process_frame
	var ok: bool=recorder.active_seconds==0 and recorder.active_frames==0
	recorder.set_process(false)
	recorder.previous=1000;recorder.previous_active=false
	recorder.record_interval(61000,true)
	ok=ok and recorder.active_seconds==0
	recorder.record_interval(62000,true)
	ok=ok and recorder.active_seconds==1
	recorder.record_interval(63000,false)
	recorder.record_interval(123000,true)
	ok=ok and recorder.active_seconds==1
	recorder.record_interval(124000,true)
	ok=ok and recorder.active_seconds==2
	recorder.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	recorder.record_interval(184000,true)
	ok=ok and recorder.active_seconds==2
	recorder.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	ok=ok and recorder.active_seconds==2
	host.free();recorder._process(0.1)
	ok=ok and recorder.active_seconds==2 and not recorder.previous_active and not recorder.is_processing()
	recorder.free()
	var lines:=FileAccess.get_file_as_string(path).strip_edges().split("\n")
	ok=ok and lines.size()>=2
	var events: Array=[]
	var current_map_recorded:=false
	for line in lines:
		var row=JSON.parse_string(line)
		if row.get("kind","")=="lifecycle":events.append(row.event)
		if row.get("kind","")=="sample":current_map_recorded=row.get("current_map","")=="0"
	ok=ok and current_map_recorded
	ok=ok and events==["window_close_request","recorder_exit_tree"]
	DirAccess.remove_absolute(path)
	print(JSON.stringify({"headless_active_time_excluded":ok,"log_lines":lines.size(),"resume_gap_excluded":ok}));quit(0 if ok else 1)
