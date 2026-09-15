extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-entry-failure-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 app.entry.show_page("login")
 app.entry.fields.username.text="retry-user"
 app.entry.fields.password.text="test-input"
 app.entry.busy=true;app.entry.auth_kind="login"
 for button in app.entry.controls.values():button.disabled=true
 app.accounts.message="账号或密码错误"
 app.entry.finish_auth(false)
 assert(not app.entry.busy)
 assert(app.entry.fields.username.text=="retry-user" and app.entry.fields.password.text=="test-input")
 assert(app.entry.controls.values().all(func(button):return not button.disabled))
 app.entry.show_page("register")
 assert(not app.entry.busy and app.entry.fields.has("confirm"))
 app.entry.show_page("login")
 assert(not app.entry.fields.has("confirm"))
 app.entry.busy=true
 for button in app.entry.controls.values():button.disabled=true
 app.entry.authentication_start_failed(ERR_CANT_CREATE)
 assert(not app.entry.busy and app.entry.controls.values().all(func(button):return not button.disabled))
 assert(app.pending_message.contains("请重试") and app.pending_message.contains(str(ERR_CANT_CREATE)))
 print("PASS: failed authentication restores controls and preserves retry input; register/login rebuild fields; thread start failure releases busy state")
 var stale_register=app.entry.controls.register
 var stale_input=app.entry.fields.username
 app.entry.show_page("register");app.entry.show_page("login")
 var untouched: String=app.pending_message
 stale_register.pressed.emit();stale_input.text_submitted.emit("")
 assert(app.entry.page=="login" and not app.entry.busy and app.pending_message==untouched)
 var disabled_register=app.entry.controls.register;disabled_register.disabled=true
 disabled_register.pressed.emit()
 assert(app.entry.page=="login")
 app.entry.fields.username.editable=false
 app.entry.fields.username.text_submitted.emit("")
 assert(app.pending_message==untouched and not app.entry.busy)
 print("PASS: detached or disabled entry controls cannot submit or switch current page")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
