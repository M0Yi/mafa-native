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
	if manifest.get("resource_version")!="2.0.1.11":
		if not errors.has(BASE+"manifest.json"):errors[BASE+"manifest.json"]="素材版本不兼容：需要 2.0.1.11，实际为 "+str(manifest.get("resource_version","未提供"))
		return false
	var requested=manifest.get("supplements",[])
	if not requested is Array or not requested.all(func(value):return value is String):
		errors[BASE+"manifest.json"]="supplements 必须是补充素材名称数组";return false
	var supplement_path:=SUPPLEMENT_BASE+"manifest.json"
	if FileAccess.file_exists(supplement_path):
		var raw=JSON.parse_string(FileAccess.get_file_as_string(supplement_path))
		if not raw is Dictionary or raw.get("format_version")!=1 or raw.get("base_resource_version")!="2.0.1.11":errors[supplement_path]="补充素材清单不兼容";return false
		for key in ["frames","audio"]:
			if not raw.get(key,{}) is Dictionary:errors[supplement_path]="补充素材 "+key+" 必须是字典";return false
		for bank in raw.get("frames",{}):
			if not raw.frames[bank] is Dictionary:errors[supplement_path]="补充图像库结构错误："+str(bank);return false
		supplement=raw
	elif requested.has("supplement16"):
		errors[supplement_path]="16周年补充素材清单缺失";return false
	var map_catalog:=json("maps.json")
	if errors.has(BASE+"maps.json"):return false
	var entries=map_catalog.get("maps")
	if not entries is Array:errors[BASE+"maps.json"]="地图目录 maps 必须是数组";return false
	var ids: Dictionary={}
	for index in range(entries.size()):
		var record=entries[index]
		if not record is Dictionary or not record.get("id") is String or str(record.get("id","")).strip_edges().is_empty():
			errors[BASE+"maps.json"]="地图记录 %d 缺少有效 ID"%index;return false
		if ids.has(record.id):errors[BASE+"maps.json"]="地图 ID 重复："+record.id;return false
		ids[record.id]=true
	if entries.size()!=707:errors[BASE+"maps.json"]="地图目录数量不完整：需要707，实际%d"%entries.size();return false
	maps=entries
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

static func valid_frame_entry(entry: Array) -> bool:
	if entry.size()<6:return false
	for field in range(6):
		if not (entry[field] is int or entry[field] is float) or not is_finite(float(entry[field])) or float(entry[field])!=floor(float(entry[field])):return false
	return entry[0]>=0 and entry[1]>0 and entry[2]>0 and entry[3]>0

func frame_location(bank: String,index: int,visited: Array=[]) -> Dictionary:
	if index<0:return {}
	var frame_id:=bank+":"+str(index)
	if frame_id in visited:errors[frame_id]="图像替代映射循环："+" → ".join(visited+[frame_id]);return {}
	if not libraries.has(bank):
		libraries[bank]=json("libraries/"+bank+".json") if FileAccess.file_exists(BASE+"libraries/"+bank+".json") else {}
	var frames=libraries[bank].get("frames",[])
	if not frames is Array:errors[BASE+"libraries/"+bank+".json"]="frames 必须是数组";return {}
	if index<frames.size():
		var entry=frames[index]
		if not entry is Array or (not entry.is_empty() and not valid_frame_entry(entry)):
			errors[bank+":"+str(index)]="基础图像帧索引无效";return {}
		if not entry.is_empty():return {"entry":entry,"pack":bank,"path":BASE+"libraries/"+bank+".pngpack"}
	var extra=supplement.get("frames",{}).get(bank,{}).get(str(index),[])
	if not extra is Array or (not extra.is_empty() and not valid_frame_entry(extra)):
		errors[bank+":"+str(index)]="补充图像帧索引无效";return {}
	if not extra.is_empty():return {"entry":extra,"pack":"@supplement16","path":SUPPLEMENT_BASE+"frames.pngpack"}
	if finish_fallbacks.is_empty() and FileAccess.file_exists("res://content/2011/finish-fallbacks.json"):
		finish_fallbacks=JSON.parse_string(FileAccess.get_file_as_string("res://content/2011/finish-fallbacks.json"))
	var replacement: Dictionary=finish_fallbacks.get("aliases",{}).get(bank+":"+str(index),{})
	if not replacement.is_empty():
		fallback_used[bank+":"+str(index)]=replacement
		return frame_location(replacement.bank,int(replacement.index),visited+[frame_id])
	errors[bank+":"+str(index)]="基础与补充素材均缺少此帧";return {}
func frame_bounds(bank: String,index: int) -> Rect2:
	var location:=frame_location(bank.to_lower(),index)
	if location.is_empty():return Rect2()
	var entry: Array=location.entry
	return Rect2(entry[4],entry[5],entry[2],entry[3])

func frame(bank: String,index: int) -> Dictionary:
	bank=bank.to_lower()
	var key:=bank+":"+str(index)
	clock+=1
	if textures.has(key):
		textures[key].used=clock;return textures[key]
	# Cached frames already include their resolved fallback, bounds and texture.
	# Resolve the source index only on a miss; scene changes clear this cache.
	var location:=frame_location(bank,index)
	if location.is_empty():return {}
	var pack_key: String=location.pack
	if not packs.has(pack_key):packs[pack_key]=FileAccess.open(location.path,FileAccess.READ)
	if packs[pack_key]==null:errors[location.path]="图像包无法打开";return {}
	var f: FileAccess=packs[pack_key];var entry: Array=location.entry
	if entry[0]<0 or entry[1]<=0 or entry[2]<=0 or entry[3]<=0 or entry[0]>f.get_length() or entry[1]>f.get_length()-entry[0]:
		errors[key]="图像帧范围越界："+str(location.path);return {}
	f.seek(int(entry[0]));var data:=f.get_buffer(int(entry[1]))
	var im:=Image.new()
	if im.load_png_from_buffer(data)!=OK:errors[key]="PNG 数据损坏";return {}
	if im.get_width()!=int(entry[2]) or im.get_height()!=int(entry[3]):errors[key]="PNG 尺寸与帧索引不一致："+str(location.path);return {}
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
	elif FileAccess.file_exists(path):stream=AudioStreamWAV.load_from_buffer(wav_runtime_bytes(FileAccess.get_file_as_bytes(path)))
	else:errors[path]="声音缺失";return null
	if stream==null:errors[path]="WAV 解码失败";return null
	if sounds.size()>=24:sounds.erase(sounds.keys()[0])
	sounds[name]=stream
	return stream

static func wav_runtime_bytes(data: PackedByteArray) -> PackedByteArray:
	# Some client WAVs contain a valid zero-loop sampler chunk. The engine
	# attempts to read a loop record anyway. Omit only this empty metadata;
	# preserve PCM, other chunks, and every actual loop definition.
	if data.size()<12 or data.slice(0,4).get_string_from_ascii()!="RIFF" or data.slice(8,12).get_string_from_ascii()!="WAVE":return data
	var result:=data.slice(0,12)
	var cursor:=12;var changed:=false
	while cursor+8<=data.size():
		var size:=int(data.decode_u32(cursor+4))
		var end:=cursor+8+size+(size%2)
		if end>data.size():return data
		var empty_sampler:=data.slice(cursor,cursor+4).get_string_from_ascii()=="smpl" and size==36 and data.decode_u32(cursor+36)==0 and data.decode_u32(cursor+40)==0
		if empty_sampler:changed=true
		else:result.append_array(data.slice(cursor,end))
		cursor=end
	if not changed or cursor!=data.size():return data
	result.encode_u32(4,result.size()-8)
	return result

func sound_id(id: int) -> AudioStream:
	var name: String=audio_catalog.get("sound_ids",{}).get(str(id),"")
	return sound(name) if not name.is_empty() else null
