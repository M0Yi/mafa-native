extends SceneTree
func _initialize():call_deferred("run")
func click(app,text: String) -> void:
 for child in app.form.get_children():
  if child is Button and child.text==text:child.pressed.emit();return
 assert(false)
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-settings-save-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.start_character({"id":"settings","name":"设置保存","job":"战士","gender":"女"})
 app.show_settings()
 var slider: HSlider=null
 for row in app.form.get_children():
  for child in row.get_children():
   if child is HSlider and slider==null:slider=child
 assert(slider!=null)
 var volume: float=slider.value;var muted: bool=app.muted
 var ui: int=app.windows.requested_scale;var zoom: int=app.world.preferred_zoom
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 click(app,"保存进度");assert(app.notice.text.begins_with("保存未完成："))
 click(app,"恢复推荐窗口大小");assert(app.notice.text.begins_with("窗口设置保存失败："))
 slider.value=-20
 assert(slider.value==volume and app.sound_levels.Music==volume and app.notice.text.begins_with("音量保存失败"))
 click(app,"静音 / 恢复声音");assert(app.muted==muted and app.notice.text.begins_with("静音设置保存失败"))
 click(app,"界面缩放：3×");assert(app.windows.requested_scale==ui and app.notice.text.begins_with("界面缩放保存失败"))
 click(app,"地图缩放：3×");assert(app.world.preferred_zoom==zoom and app.notice.text.begins_with("地图缩放保存失败"))
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 slider.value=-20
 assert(app.sound_levels.Music==-20 and float(app.store.read_metadata("volume:Music"))==-20)
 click(app,"静音 / 恢复声音");assert(app.muted!=muted and app.store.read_metadata("muted")==str(app.muted))
 click(app,"界面缩放：3×");assert(app.windows.requested_scale==3 and app.store.read_metadata("ui_scale")=="3")
 click(app,"地图缩放：3×");assert(app.world.preferred_zoom==3 and app.store.read_metadata("zoom")=="3")
 click(app,"保存进度");assert(app.notice.text=="游戏进度已保存")
 root.size=Vector2i(800,600);app.windows.requested_scale=0
 for i in range(12):await process_frame
 var win=app.windows.windows["设置与操作"]
 win.scroll.scroll_vertical=10000
 for i in range(8):await process_frame
 var save_button: Button=null
 for child in app.form.get_children():
  if child is Button and child.text=="保存进度":save_button=child
 assert(save_button!=null and win.scroll.get_global_rect().grow(1).encloses(save_button.get_global_rect()))
 click(app,"保存进度")
 for i in range(8):await process_frame
 assert(win.get_global_rect().encloses(app.notice.get_global_rect()))
 assert(app.notice.get_global_rect().position.y>=win.scroll.get_global_rect().end.y)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../artifacts/closeout-settings-bottom.png")
 var short_height: float=win.scroll.size.y
 app.info("保存未完成：当前存档目录无法写入。请检查剩余空间与目录权限，处理后重试。\n此前成功保存的进度仍保留，请勿删除存档。")
 for i in range(12):await process_frame
 assert(win.get_global_rect().encloses(app.notice.get_global_rect()) and app.notice.get_line_count()>1)
 assert(win.scroll.size.y<short_height and app.notice.get_global_rect().position.y>=win.scroll.get_global_rect().end.y)
 win.scroll.scroll_vertical=10000
 for i in range(8):await process_frame
 assert(win.scroll.get_global_rect().grow(1).encloses(save_button.get_global_rect()))
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../artifacts/closeout-settings-error-footer.png")
 app.info("")
 for i in range(12):await process_frame
 assert(not app.notice.visible and win.scroll.size.y>short_height)
 app.windows.close("设置与操作");assert(not app.world.paused)
 var saved_volume: String=app.store.read_metadata("volume:Music")
 slider.value=-31
 assert(app.sound_levels.Music==-20 and app.store.read_metadata("volume:Music")==saved_volume)
 print("PASS: closed settings slider cannot change saved or active volume")
 app.world.paused=true;app.show_settings()
 var escape:=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE
 root.push_input(escape,true)
 for i in range(4):await process_frame
 assert(not app.windows.windows.has("设置与操作") and app.world.paused)
 app.world.paused=false;app.show_settings()
 app.windows.pause("focus");app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(app.world.paused and app.windows.pause_reason=="settings")
 app.windows.close("设置与操作");assert(not app.world.paused)
 app.show_settings();app.windows.pause("focus")
 app.windows.modal.canceled.emit();app.windows.modal.hide()
 assert(app.world.paused and app.windows.pause_reason=="settings")
 app.windows.close("设置与操作");assert(not app.world.paused)
 app.windows.pause("focus");app.windows.modal.canceled.emit();app.windows.modal.hide()
 assert(app.world.paused and app.windows.pause_reason.is_empty())
 app.world.paused=false;app.show_settings()
 app.windows.confirm("隔离测试确认",func():pass)
 app.controller_button(JOY_BUTTON_B)
 assert(app.windows.windows.has("设置与操作") and app.windows.modal.visible and app.world.paused)
 app.windows.modal.hide();app.controller_button(JOY_BUTTON_B)
 assert(not app.windows.windows.has("设置与操作") and not app.world.paused)
 var actions: Array=[]
 app.windows.confirm("第一个操作",func():actions.append("first"))
 app.windows.modal.canceled.emit();app.windows.modal.hide()
 app.windows.modal.confirmed.emit();assert(actions.is_empty())
 assert(app.windows.modal.confirmed.get_connections().is_empty())
 app.windows.confirm("第二个操作",func():actions.append("second"))
 app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(actions==["second"])
 app.windows.modal.confirmed.emit();assert(actions==["second"])
 app.windows.confirm("失焦前的操作",func():actions.append("stale"))
 app.windows.pause("focus")
 app.windows.modal.confirmed.emit();app.windows.modal.hide()
 assert(actions==["second"] and not app.world.paused)
 var pause_key:=InputEventKey.new();pause_key.pressed=true;pause_key.physical_keycode=KEY_P;pause_key.keycode=KEY_P
 app.world.paused=true;app.windows.pause_reason=""
 app.windows.confirm("保持暂停",func():pass)
 app._unhandled_input(pause_key)
 assert(app.world.paused)
 app.windows.modal.hide()
 var input:=LineEdit.new();root.add_child(input);input.grab_focus()
 assert(app.typing())
 app._unhandled_input(pause_key);assert(app.world.paused)
 input.release_focus();input.queue_free()
 app._unhandled_input(pause_key);assert(not app.world.paused)
 print("PASS: failed display settings preserve active values and show error; retry saves and applies both scales; P cannot resume through modal or text focus")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
