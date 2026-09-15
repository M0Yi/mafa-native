extends SceneTree

class CountingResources extends EditionResources:
	var lookups:=0
	func frame_location(bank: String,index: int) -> Dictionary:
		lookups+=1
		return super.frame_location(bank,index)

func _initialize() -> void:
	var res:=CountingResources.new()
	var first:=res.frame("tiles",0)
	assert(not first.is_empty())
	var used: int=first.used
	var again:=res.frame("TILES",0)
	assert(again.texture==first.texture and again.used>used)
	assert(res.lookups==1)
	# Aliases must retain the resolved image and re-resolve after cache eviction.
	res.finish_fallbacks={"aliases":{"closeout_missing:0":{"bank":"tiles","index":0}}}
	var alias:=res.frame("closeout_missing",0)
	assert(alias.size==first.size and alias.offset==first.offset)
	assert(res.fallback_used.has("closeout_missing:0"))
	var count: int=res.lookups
	assert(res.frame("closeout_missing",0).texture==alias.texture)
	assert(res.lookups==count)
	res.clear_scene_cache()
	assert(res.memory_bytes==0 and res.textures.is_empty())
	assert(not res.frame("tiles",0).is_empty() and res.lookups==count+1)
	assert(res.frame("tiles",-1).is_empty())
	res.clear_scene_cache()
	print("FRAME_CACHE_CLOSEOUT_PASS cached lookup, LRU age, case normalization, fallback, eviction, invalid index")
	quit()
