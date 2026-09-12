class_name EditionCombat
extends RefCounted
# Mode meanings follow mirgo/cmd/server/attackmode.go. Offline travelers
# have persisted health; no player-kill rewards or copied inventory.
const MODES={"peace":"和平","party":"编组","guild":"行会","all":"全体","red":"红名"}
static func eligible(state: Dictionary,target: Dictionary) -> bool:
	if EditionCreatures.underground(target) or int(target.get("hp",1))<=0:return false
	if target.get("kind")=="monster":return true
	if target.get("kind")!="traveler":return false
	match state.get("attack_mode","peace"):
		"all":return true
		"party":return target.get("name","") not in state.get("party",[])
		"guild":return target.get("name","") not in state.get("guild",{}).get("members",[])
		"red":return int(target.get("pk_points",0))>=200
	return false
