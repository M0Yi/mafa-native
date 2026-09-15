extends SceneTree
const Damage=preload("res://scripts/edition2011/weapon_damage.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note)
func _initialize() -> void:
	var weapon:=EditionInventory.make_item("ref:35",1,"equipment",0,37);weapon.blessing=3;weapon.curse=1
	var state:={"items":[weapon]}
	check(Damage.bounds(state,25)==Vector2i(25,52),"real weapon DC bounds plus reconstructed base")
	check(Damage.luck(state)==2,"blessing minus curse")
	weapon.container="warehouse"
	check(Damage.bounds(state,25)==Vector2i(25,25) and Damage.luck(state)==0,"stored weapon has no combat effect")
	weapon.container="equipment";weapon.durability=0
	check(Damage.bounds(state,25)==Vector2i(25,25) and Damage.luck(state)==0,"broken weapon has no combat effect")
	var rng:=RandomNumberGenerator.new();rng.seed=97021
	var min_seen:=false;var max_seen:=false;var neutral_max:=0;var lucky_max:=0
	for i in range(2000):
		var neutral:=Damage.roll(Vector2i(10,20),0,rng)
		min_seen=min_seen or neutral==10;max_seen=max_seen or neutral==20
		if neutral==20:neutral_max+=1
		if Damage.roll(Vector2i(10,20),7,rng)==20:lucky_max+=1
		check(neutral>=10 and neutral<=20,"neutral stays in interval")
		check(Damage.roll(Vector2i(10,20),9,rng)==20,"luck9 forces upper endpoint")
		check(Damage.roll(Vector2i(10,20),-9,rng)==10,"curse9 forces lower endpoint")
	check(min_seen and max_seen,"neutral can reach both endpoints")
	check(lucky_max>neutral_max*2,"seeded luck7 meaningfully increases maximum frequency")
	var report={"checks":checks,"failures":failures,"neutral_max":neutral_max,"lucky_max":lucky_max,"scope":"seeded damage model and real item metadata; not in-world combat or statistical certification"}
	FileAccess.open("res://../artifacts/world-story/weapon-damage-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
