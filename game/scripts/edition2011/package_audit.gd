extends RefCounted
var failures: Array=[]
var count:=0
func scan(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		count+=1
		if file.get_extension().to_lower() in ["wil","wix","wis","wzl","wzx","uib","wav","pngpack","mapbin","walk","map","sqlite","login"]:failures.append(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		if dir=="assets":failures.append(path.path_join(dir))
		scan(path.path_join(dir))
func run() -> Dictionary:
	scan("res://")
	var report:={"files":count,"forbidden":failures,"code_only":failures.is_empty()}
	return report
