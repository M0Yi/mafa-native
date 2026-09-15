extends SceneTree
func _initialize() -> void:
 var folder:="/tmp/mafa-map-catalog-"+Crypto.new().generate_random_bytes(8).hex_encode()
 assert(DirAccess.make_dir_recursive_absolute(folder)==OK)
 var original:=EditionResources.BASE;var extra:=EditionResources.SUPPLEMENT_BASE
 EditionResources.BASE=folder+"/";EditionResources.SUPPLEMENT_BASE=folder+"/supplement/"
 var file:=FileAccess.open(folder+"/manifest.json",FileAccess.WRITE);file.store_string('{"resource_version":"2.0.1.11"}');file.close()
 for fixture in [[null,"数组"],[{},"数组"],[[null],"记录 0"],[[{"id":4}],"记录 0"],[[{"id":" "}],"记录 0"],[[{"id":"0"},{"id":"0"}],"重复"],[[],"数量不完整"]]:
  file=FileAccess.open(folder+"/maps.json",FileAccess.WRITE);file.store_string(JSON.stringify({"maps":fixture[0]}));file.close()
  var resources:=EditionResources.new()
  assert(not resources.initialize())
  assert(resources.errors.get(folder+"/maps.json","").contains(fixture[1]))
  assert(resources.map_by_id.is_empty())
 EditionResources.BASE=original;EditionResources.SUPPLEMENT_BASE=extra
 for name in ["manifest.json","maps.json"]:DirAccess.remove_absolute(folder+"/"+name)
 DirAccess.remove_absolute(folder)
 print("PASS: malformed map arrays, records, duplicate IDs and incomplete counts return located errors before world initialization")
 quit()
