extends SceneTree
func _initialize() -> void:
	var failures: Array=[];var checks:=0
	for fps in [30,60,120]:
		var animation:=EditionAnimation.new()
		animation.start({"start":23,"count":10,"skip":0,"ms":300,"loop":false,"events":[{"id":"door","time":0.0},{"id":"hit","time":0.255}]})
		var events: Array=[]
		for _i in range(fps*4):events.append_array(animation.advance(1.0/fps))
		checks+=2
		if events.size()!=2:failures.append("events replayed at "+str(fps))
		if animation.frame()!=32 or not animation.finished:failures.append("final frame at "+str(fps))
	for action in EditionAnimation.HUMAN.values():
		for direction in range(8):
			checks+=1
			var first:=EditionAnimation.index(action,direction,0)
			if first!=action.start+direction*(action.count+action.skip):failures.append("direction stride")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
