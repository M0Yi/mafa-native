extends SceneTree
func _initialize() -> void:
	var script=load("res://tests2011/soak_test.gd")
	assert(script.parse_rss(0,[" 123456\n"])==123456)
	for row in [[1,["123"]],[0,[]],[0,[""]],[0,["error"]],[0,["0"]],[0,["-1"]]]:
		assert(script.parse_rss(row[0],row[1])==null)
	print("PASS: RSS valid output parses, unavailable/error output remains null")
	quit()
