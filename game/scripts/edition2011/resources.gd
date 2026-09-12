class_name EditionResources
extends RefCounted

static var SUPPLEMENT_BASE := "res://assets/supplement16/"
var supplement: Dictionary={}
static var BASE := "res://assets/client2011/"
var libraries: Dictionary = {}
var packs: Dictionary = {}
var textures: Dictionary = {}
var memory_bytes := 0
var clock := 0
var errors: Dictionary = {}
var fallback_used: Dictionary={}
var finish_fallbacks: Dictionary={}
var maps: Array = []
var map_by_id: Dictionary = {}
var audio_catalog: Dictionary = {}
var world_catalog: Dictionary = {}
var npcs_by_map: Dictionary = {}
var sounds: Dictionary = {}
var map_names: Dictionary={}
var connections:=EditionConnections.new()

func json(path: String) -> Dictionary:
	var p := BASE+path
	if not FileAccess.file_exists(p):
		errors[p]="文件缺失";return {}
	var result=JSON.parse_string(FileAccess.get_file_as_string(p))
	if not result is Dictionary:
		errors[p]="JSON 格式错误";return {}
	return result

func initialize() -> bool:
	var manifest=json("manifest.json")
	if manifest.get("resource_version")!="2.0.1.11":return false
	var supplement_path:=SUPPLEMENT_BASE+"manifest.json"
	if FileAccess.file_exists(supplement_path):
		var raw=JSON.parse_string(FileAccess.get_file_as_string(supplement_path))
		if not raw is Dictionary or raw.get("format_version")!=1 or raw.get("base_resource_version")!="2.0.1.11":errors[supplement_path]="补充素材清单不兼容";return false
		supplement=raw
	elif manifest.get("supplements",[]).has("supplement16"):
		errors[supplement_path]="16周年补充素材清单缺失";return false
	maps=json("maps.json").get("maps",[])
	var naming=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/map-names.json"))
	if not naming is Dictionary:errors["map-names.json"]="地图名称目录缺失或损坏";return false
	for entry in naming.get("entries",[]):map_names[entry.id]=entry
	for map in maps:
		if not map_names.has(map.id) or str(map_names[map.id].get("name","")).strip_edges().is_empty():errors["map-name:"+map.id]="地图缺少名称";return false
		map.name=map_names[map.id].name
	for m in maps:map_by_id[m.id]=m
	var connection_error:=connections.load_catalog(map_by_id)
	if not connection_error.is_empty():errors["map-connections.json"]=connection_error;return false
	for id in connections.arrivals:
		map_by_id[id].spawn=connections.arrivals[id].spawn
		map_by_id[id].service_spots=connections.arrivals[id].service_spots
	audio_catalog=json("audio.json")
	for name in ["maps","npcs"]:
		var path: String="res://content/2011/"+name+".json"
		var content=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not content is Dictionary:errors[path]="世界内容目录无法读取";return false
		for entry in content.get("entries",[]):
			if name=="maps":
				var remaining: Array=[]
				for gap in entry.get("missing_references",[]):
					var unresolved: Dictionary=gap.duplicate(true)
					unresolved.indexes=gap.indexes.filter(func(index):return not supplement.get("frames",{}).get(gap.library,{}).has(str(int(index))))
					if not unresolved.indexes.is_empty():remaining.append(unresolved)
				entry.missing_references=remaining;world_catalog[entry.id]=entry
			else:
				if entry.id.ends_with(":guide"):entry.cell=map_by_id[entry.map].service_spots[0].duplicate()
				elif entry.id.ends_with(":merchant"):entry.cell=map_by_id[entry.map].service_spots[1].duplicate()
				if not npcs_by_map.has(entry.map):npcs_by_map[entry.map]=[]
				npcs_by_map[entry.map].append(entry)
	var rooms=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/room-services.json"))
	for id in npcs_by_map:
		if map_by_id[id].service_spots[0]==map_by_id[id].service_spots[1]:
			npcs_by_map[id]=npcs_by_map[id].filter(func(n):return not str(n.id).ends_with(":merchant"))
	if not rooms is Dictionary:errors["room-services.json"]="店铺服务目录缺失或损坏";return false
	for entry in rooms.get("entries",[]):
		npcs_by_map[entry.map]=npcs_by_map.get(entry.map,[]).filter(func(n):return not str(n.id).ends_with(":merchant"))
		npcs_by_map[entry.map].append(entry)
	if EditionRegion.data().get("format_version")!=1:errors["regional-data.json"]="区域服务端目录缺失或损坏";return false
	for m in maps:
		var regional:=EditionRegion.npcs(m.id)
		if regional.is_empty() and map_names[m.id].reconstructed:
			regional=npcs_by_map.get(m.id,[]).filter(func(n):return str(n.id).ends_with(":guide"))
			for n in regional:n.name="单机驿站传送员 · 重建"
		npcs_by_map[m.id]=regional
	npcs_by_map[EditionFireDragon.MAP].append({"id":EditionFireDragon.GUARD,"map":EditionFireDragon.MAP,"kind":"npc","name":"神殿接引员 · 单机","cell":[45,84],"bank":"npc","frame":900,"frames":4,"service":"fire_dragon"})
	return maps.size()==707 and errors.is_empty()

func frame_location(bank: String,index: int) -> Dictionary:
	if index<0:return {}
	if not libraries.has(bank):
		libraries[bank]=json("libraries/"+bank+".json") if FileAccess.file_exists(BASE+"libraries/"+bank+".json") else {}
	var frames: Array=libraries[bank].get("frames",[])
	if index<frames.size() and frames[index].size()>=6:
		return {"entry":frames[index],"pack":bank,"path":BASE+"libraries/"+bank+".pngpack"}
	var extra: Array=supplement.get("frames",{}).get(bank,{}).get(str(index),[])
	if extra.size()>=6:return {"entry":extra,"pack":"@supplement16","path":SUPPLEMENT_BASE+"frames.pngpack"}
	if finish_fallbacks.is_empty() and FileAccess.file_exists("res://content/2011/finish-fallbacks.json"):
		finish_fallbacks=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/finish-fallbacks.json"))
	var replacement: Dictionary=finish_fallbacks.get("aliases",{}).get(bank+":"+str(index),{})
	if not replacement.is_empty():
		fallback_used[bank+":"+str(index)]=replacement
		return frame_location(replacement.bank,int(replacement.index))
	errors[bank+":"+str(index)]="基础与补充素材均缺少此帧";return {}
func frame_bounds(bank: String,index: int) -> Rect2:
	var location:=frame_location(bank.to_lower(),index)
	if location.is_empty():return Rect2()
	var entry: Array=location.entry
	return Rect2(entry[4],entry[5],entry[2],entry[3])

func frame(bank: String,index: int) -> Dictionary:
	bank=bank.to_lower()
	var location:=frame_location(bank,index)
	if location.is_empty():return {}
	var key:=bank+":"+str(index)
	clock+=1
	if textures.has(key):
		textures[key].used=clock;return textures[key]
	var pack_key: String=location.pack
	if not packs.has(pack_key):packs[pack_key]=FileAccess.open(location.path,FileAccess.READ)
	if packs[pack_key]==null:errors[location.path]="图像包无法打开";return {}
	var f: FileAccess=packs[pack_key];var entry: Array=location.entry
	f.seek(int(entry[0]));var data:=f.get_buffer(int(entry[1]))
	var im:=Image.new()
	if im.load_png_from_buffer(data)!=OK:errors[key]="PNG 数据损坏";return {}
	var bytes:=im.get_width()*im.get_height()*4
	while memory_bytes+bytes>192*1024*1024 and not textures.is_empty():
		var oldest: String="";var age:=9223372036854775807
		for k in textures:
			if int(textures[k].used)<age:oldest=k;age=int(textures[k].used)
		memory_bytes-=int(textures[oldest].bytes);textures.erase(oldest)
	var value={"texture":ImageTexture.create_from_image(im),"offset":Vector2(entry[4],entry[5]),
		"size":Vector2(entry[2],entry[3]),"body_visible":im.get_width()*im.get_height()>4 and im.get_used_rect().get_area()>0,"bytes":bytes,"used":clock}
	textures[key]=value;memory_bytes+=bytes
	return value

func clear_scene_cache() -> void:
	textures.clear();memory_bytes=0

func sound(name: String) -> AudioStream:
	if sounds.has(name):return sounds[name]
	var path:=BASE+"audio/"+name.to_lower()
	if not ResourceLoader.exists(path,"AudioStream") and not FileAccess.file_exists(path) and supplement.get("audio",{}).has(name.to_lower()):path=SUPPLEMENT_BASE+"audio/"+name.to_lower()
	# Exported WAVs are remapped to Godot samples. FileAccess cannot follow that remap.
	var stream: AudioStream
	if ResourceLoader.exists(path,"AudioStream"):stream=ResourceLoader.load(path,"AudioStream") as AudioStream
	elif FileAccess.file_exists(path):stream=AudioStreamWAV.load_from_file(path)
	else:errors[path]="声音缺失";return null
	if stream==null:errors[path]="WAV 解码失败";return null
	if sounds.size()>=24:sounds.erase(sounds.keys()[0])
	sounds[name]=stream
	return stream

func sound_id(id: int) -> AudioStream:
	var name: String=audio_catalog.get("sound_ids",{}).get(str(id),"")
	return sound(name) if not name.is_empty() else null
