extends SceneTree
var assets:=EditionResources.new()
func _initialize() -> void:call_deferred("run")
func rendered() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_region(Rect2i(100,100,40,40))
func run() -> void:
	root.size=Vector2i(400,300);root.title="0.9.0 按钮缓存回归（无存档）"
	assets.initialize()
	var button:=EditionSkinButton.new();button.resources=assets;button.normal_frame=8;button.position=Vector2(100,100);button.size=Vector2(40,40);button.highlight=false;root.add_child(button)
	var before:=await rendered()
	assets.clear_scene_cache()
	# The button receives no input or redraw request: its retained draw command
	# must remain valid while the world replaces its cached textures.
	var after:=await rendered()
	var same:=before.get_data()==after.get_data()
	var result:={"unchanged_pixels_after_scene_cache_clear":same,"resource_errors":assets.errors}
	print(JSON.stringify(result));FileAccess.open("res://../artifacts/living-village-0.9.0/skin-cache.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if same and assets.errors.is_empty() else 1)
