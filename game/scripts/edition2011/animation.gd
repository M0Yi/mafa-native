class_name EditionAnimation
extends RefCounted
# Reference: mirgo/cmd/client/actor.go HA. Format agreement is verified per bank;
# these templates do not imply every costume/monster/skill has been integrated.
const HUMAN := {
	"stand":{"start":0,"count":4,"skip":4,"ms":200,"loop":true},
	"walk":{"start":64,"count":6,"skip":2,"ms":90,"loop":true},
	"run":{"start":128,"count":6,"skip":2,"ms":120,"loop":true},
	"battle":{"start":192,"count":1,"skip":0,"ms":200,"loop":true},
	"attack":{"start":200,"count":6,"skip":2,"ms":85,"loop":false},
	"heavy_attack":{"start":264,"count":6,"skip":2,"ms":90,"loop":false},
	"wide_attack":{"start":328,"count":8,"skip":0,"ms":70,"loop":false},
	"cast":{"start":392,"count":6,"skip":2,"ms":60,"loop":false},
	"sit":{"start":456,"count":2,"skip":0,"ms":300,"loop":true},
	"hurt":{"start":472,"count":3,"skip":5,"ms":70,"loop":false},
	"die":{"start":536,"count":4,"skip":4,"ms":120,"loop":false}
}
var definition: Dictionary={}
var elapsed:=0.0
var emitted: Dictionary={}
var finished:=false

func start(value: Dictionary) -> void:
	definition=value;elapsed=0;emitted.clear();finished=false

func advance(delta: float) -> Array:
	var events: Array=[]
	if finished or delta<=0 or definition.is_empty():return events
	elapsed+=delta
	for event in definition.get("events",[]):
		var id: String=event.id
		if not emitted.has(id) and elapsed>=float(event.time):emitted[id]=true;events.append(event)
	if not definition.get("loop",false) and elapsed>=duration():finished=true
	return events

func duration() -> float:return float(definition.get("count",1))*float(definition.get("ms",100))/1000.0
func frame(direction:=0) -> int:
	return index(definition,direction,elapsed)

static func index(action: Dictionary,direction: int,seconds: float) -> int:
	var count:=maxi(1,int(action.get("count",1)))
	var frame:=int(maxf(0,seconds)*1000/maxf(1,float(action.get("ms",100))))
	frame=frame%count if action.get("loop",true) else mini(count-1,frame)
	return int(action.get("start",0))+clampi(direction,0,7)*(count+int(action.get("skip",0)))+frame
