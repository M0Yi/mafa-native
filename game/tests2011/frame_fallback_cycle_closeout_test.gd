extends SceneTree
func _initialize() -> void:
 for aliases in [{"probe:0":{"bank":"probe","index":0}},{"probe:0":{"bank":"other","index":0},"other:0":{"bank":"probe","index":0}}]:
  var resources:=EditionResources.new();resources.libraries={"probe":{"frames":[]},"other":{"frames":[]}};resources.finish_fallbacks={"aliases":aliases}
  assert(resources.frame_bounds("probe",0)==Rect2())
  assert(resources.errors["probe:0"].contains("循环"))
  assert(resources.textures.is_empty())
 var valid:=EditionResources.new();valid.libraries={"probe":{"frames":[]},"other":{"frames":[[0,10,2,3,-1,-2]]}}
 valid.finish_fallbacks={"aliases":{"probe:0":{"bank":"other","index":0}}}
 assert(valid.frame_bounds("probe",0)==Rect2(-1,-2,2,3))
 assert(valid.frame_bounds("probe",0)==Rect2(-1,-2,2,3) and valid.errors.is_empty())
 print("PASS: self and two-bank fallback cycles report errors; repeated valid fallback bounds resolve")
 quit()
