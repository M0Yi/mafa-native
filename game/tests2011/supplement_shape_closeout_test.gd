extends SceneTree
func _initialize() -> void:
 var folder:="/tmp/mafa-supplement-shape-"+Crypto.new().generate_random_bytes(8).hex_encode()
 DirAccess.make_dir_recursive_absolute(folder+"/extra")
 var original:=EditionResources.BASE;var extra:=EditionResources.SUPPLEMENT_BASE
 EditionResources.BASE=folder+"/";EditionResources.SUPPLEMENT_BASE=folder+"/extra/"
 for value in [null,"supplement16",{},[1]]:
  write_json(folder+"/manifest.json",{"resource_version":"2.0.1.11","supplements":value})
  var resources:=EditionResources.new();assert(not resources.initialize())
  assert(resources.errors[folder+"/manifest.json"].contains("supplements"))
 write_json(folder+"/manifest.json",{"resource_version":"2.0.1.11","supplements":["supplement16"]})
 for fields in [{"frames":null},{"audio":[]},{"frames":{"npc":[]}}]:
  var manifest:={"format_version":1,"base_resource_version":"2.0.1.11"};manifest.merge(fields)
  write_json(folder+"/extra/manifest.json",manifest)
  var resources:=EditionResources.new();assert(not resources.initialize())
  assert(resources.errors.has(folder+"/extra/manifest.json"))
 EditionResources.BASE=original;EditionResources.SUPPLEMENT_BASE=extra
 for name in ["manifest.json","extra/manifest.json"]:DirAccess.remove_absolute(folder+"/"+name)
 DirAccess.remove_absolute(folder+"/extra");DirAccess.remove_absolute(folder)
 print("PASS: malformed supplement declarations and library containers return located errors")
 quit()
func write_json(path: String,data: Dictionary) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
