extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
 var path:="/tmp/mafa-reentry-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite"
 app.store.path=path;root.add_child(app);app.set_process(false)
 var profile:={"id":"revival","name":"复活测试","job":"法师","gender":"女"}
 app.start_character(profile)
 var next: Dictionary=app.rules.state.duplicate(true)
 next.map="3";next.cell=[340,340];next.hp=0;next.death_due=next.time+30
 next.green_poison={"until":999,"next":1,"power":3};next.stone_until=999
 assert(app.rules.apply(next,"dead_fixture"),app.rules.message)
 var items: Array=app.rules.state.items.duplicate(true);var gold: int=app.rules.state.gold
 assert(app.store.db.query("PRAGMA query_only=ON;"))
 assert(not app.rules.revive_on_entry("3",Vector2i(330,330)))
 assert(app.rules.state.hp==0 and app.rules.state.has("death_due"))
 app.accounts.data={"version":1,"accounts":[{"id":"fixture","characters":[profile]}]}
 app.accounts.current_id="fixture";app.entry.selected_id=profile.id
 app.entry.show_page("notice");app.entry.confirm_modal()
 assert(app.entry.visible and app.entry.page=="roster" and app.mode=="roster")
 assert(app.rules.state.hp==0 and not app.entry.message.text.is_empty())
 print("PASS: failed revival through entry confirmation restores visible roster and retry feedback")
 assert(app.store.db.query("PRAGMA query_only=OFF;"))
 var saved_map: Dictionary=app.resources.map_by_id["3"]
 app.resources.map_by_id.erase("3")
 app.entry.show_page("notice");app.entry.confirm_modal()
 assert(app.entry.visible and app.entry.page=="roster" and app.rules.state.hp==0)
 assert(app.entry.message.text.contains("无法载入"))
 app.resources.map_by_id["3"]=saved_map
 app.entry.show_page("notice");app.entry.confirm_modal()
 assert(not app.entry.visible)
 assert(app.pending_message.begins_with("已进入") and not "索引" in app.pending_message)
 assert(not app.resources.world_catalog["3"].missing_references.is_empty())
 print("PASS: missing revival map keeps roster visible; restoring it allows entry retry")
 assert(app.mode=="game" and app.rules.state.hp==app.rules.max_hp())
 assert(app.rules.state.map=="3" and EditionRegion.safe("3",app.world.player.cell))
 assert(not app.rules.state.has("death_due") and not app.rules.state.has("green_poison") and not app.rules.state.has("stone_until"))
 assert(JSON.parse_string(JSON.stringify(app.rules.state.items))==JSON.parse_string(JSON.stringify(items)) and app.rules.state.gold==gold)
 assert(app.rules.attach(profile) and app.rules.state.hp>0 and app.rules.state.map=="3")
 var zone:=EditionRegion.revival_zone("test_dungeon",Vector2i.ZERO,{"test_dungeon":[{"target_map":"3","target_cell":[330,330]}]})
 assert(zone.map=="3")
 var local:=EditionRegion.revival_zone("0",Vector2i(650,631),{})
 assert(Vector2i(local.cell[0],local.cell[1])==Vector2i(650,631))
 var rect:=EditionRegion.safe_rect(local)
 assert(rect.has_point(Vector2(645*48,626*32)) and not rect.has_point(Vector2(656*48,631*32)))
 var healthy: Dictionary=app.rules.state.duplicate(true)
 var attacker:={"magic_attack":false}
 for point in [Vector2i(325,325),Vector2i(335,335),Vector2i(330,330)]:
  app.world.player.cell=point
  app.world.monster_hit.emit(attacker,10)
  assert(app.rules.state==healthy)
 app.world.player.cell=Vector2i(336,330)
 app.world.paused=true
 app.world.monster_hit.emit(attacker,10)
 assert(app.rules.state==healthy,"paused monster hit must not apply")
 app.world.paused=false
 app.world.monster_hit.emit(attacker,10)
 assert(app.rules.state.hp<int(healthy.hp))
 print("PASS: safe-zone edge cells block monster damage; pause blocks late hits; outside damage remains active")
 print("PASS: reentry revives immediately in nearest safe town, persists without item loss; write failure preserves death; safety overlay matches cells")
 app.queue_free();await process_frame;await create_timer(0.2).timeout
 for suffix in ["","-wal","-shm",".backup.sqlite"]:DirAccess.remove_absolute(path+suffix)
 quit()
