extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 await create_timer(2.0).timeout
 var devices: Array=[]
 for id in Input.get_connected_joypads():
  devices.append({"id":id,"name":Input.get_joy_name(id),"known_mapping":Input.is_joy_known(id)})
 var report:={"devices":devices,"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"scope":"device enumeration only; no buttons, axes, vibration or gameplay acceptance"}
 FileAccess.open("res://../artifacts/closeout-controller-devices.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit()
