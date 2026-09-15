extends SceneTree
func _initialize() -> void:
 var folder:="/tmp/mafa-pack-bounds-"+Crypto.new().generate_random_bytes(8).hex_encode()
 DirAccess.make_dir_recursive_absolute(folder+"/libraries")
 var original:=EditionResources.BASE;EditionResources.BASE=folder+"/"
 var image:=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.RED)
 var png:=image.save_png_to_buffer()
 var file:=FileAccess.open(folder+"/libraries/probe.pngpack",FileAccess.WRITE);file.store_buffer(png);file.close()
 for entry in [[-1,png.size(),2,2,0,0],[0,0,2,2,0,0],[0,png.size()+1,2,2,0,0],[png.size()+1,1,2,2,0,0],[0,png.size(),3,2,0,0],[0,png.size(),2,2,0.5,0]]:
  var resources:=EditionResources.new();resources.libraries.probe={"frames":[entry]}
  assert(resources.frame("probe",0).is_empty())
  assert(resources.errors.has("probe:0") and resources.textures.is_empty() and resources.memory_bytes==0)
 for entry in [null,"bad",[0,1],[0,1,2,2,"bad",0],[0,1,0,2,0,0]]:
  for supplemental in [false,true]:
   var resources:=EditionResources.new()
   resources.libraries.probe={"frames":[] if supplemental else [entry]}
   if supplemental:resources.supplement={"frames":{"probe":{"0":entry}}}
   assert(resources.frame_bounds("probe",0)==Rect2())
   assert(resources.errors.has("probe:0"))
 var valid:=EditionResources.new();valid.libraries.probe={"frames":[[0,png.size(),2,2,-1,-2]]}
 assert(not valid.frame("probe",0).is_empty());assert(valid.frame("probe",0).offset==Vector2(-1,-2))
 valid.packs.clear();valid.clear_scene_cache();EditionResources.BASE=original
 DirAccess.remove_absolute(folder+"/libraries/probe.pngpack");DirAccess.remove_absolute(folder+"/libraries");DirAccess.remove_absolute(folder)
 print("PASS: corrupt frame ranges and dimensions rejected without caching; valid PNG and negative sprite offsets preserved")
 quit()
