extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var failures: Array=[]
var checks:=0
var exercised_quests:=0
var quest_results: Array=[]
var started_ms:=Time.get_ticks_msec()
var phase_times: Dictionary={}
var quest_job: String="战士"
func mark_phase(name: String) -> void:
	phase_times[name]=Time.get_ticks_msec()-started_ms
	print(JSON.stringify({"story_test_phase":name,"elapsed_ms":phase_times[name]}))
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	quest_job=OS.get_environment("MAFA_STORY_JOB")
	if quest_job.is_empty():quest_job="战士"
	if quest_job not in ["战士","法师","道士"]:printerr("invalid test profession");quit(1);return
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/mafa-story-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle()
	app.start_character({"id":"story","name":"故事验收","gender":"男","job":quest_job});app.world.paused=true
	var premature: Dictionary=app.rules.story_npc("server:npc:9")
	expect(not app.rules.story_action("story_mongchon","accept",premature.id,premature.map,Vector2i(premature.cell[0],premature.cell[1])),"prerequisites cannot be skipped")
	# Existing save identity, wealth and inventory survive when no story fields exist.
	expect(not app.rules.state.has("story_progress"),"legacy saves need no reset")
	var next: Dictionary=app.rules.state.duplicate(true);next.quests.nv_patrol="done";next.novice={"chickens":0,"patrol":true};next.gold=10000
	expect(app.rules.apply(next,"story_fixture"),"seed completed introductory quest")
	for q in Story.data().quests:
		if q.has("jobs") and app.rules.character.job not in q.jobs:continue
		exercised_quests+=1
		var failures_before:=failures.size()
		var checks_before:=checks
		# A sequential whole-catalog fixture must store accumulated rewards like a player.
		for supply in ["potion","mana"]:
			while int(app.rules.state.inventory.get(supply,0))>50:
				var stored: bool=app.rules.warehouse(supply,true)
				expect(stored,"store accumulated rewards: "+app.rules.message)
				if not stored:break
		var start: Dictionary=app.rules.story_npc(q.start_npc);var end: Dictionary=app.rules.story_npc(q.end_npc)
		expect(not start.is_empty() and not end.is_empty(),"NPC catalog "+q.id)
		expect(app.resources.npcs_by_map.get(start.map,[]).any(func(n):return n.id==q.start_npc) or q.start_npc=="border:elder","NPC actually loaded "+q.id)
		var cell:=Vector2i(start.cell[0],start.cell[1])
		expect(not app.rules.story_action(q.id,"accept",q.start_npc,start.map,cell+Vector2i(20,20)),"far accept refused "+q.id)
		expect(app.rules.story_action(q.id,"accept",q.start_npc,start.map,cell),"accept "+q.id)
		expect(not app.rules.story_action(q.id,"accept",q.start_npc,start.map,cell),"duplicate accept refused "+q.id)
		for o in q.objectives:
			match o.type:
				"mine":
					exercise_mining(q,o)
				"binding":
					var giver: Dictionary=app.rules.story_npc(o.npc)
					var ingredient: String=EditionRules.MEDICINE_BUNDLES.merged(EditionRules.SCROLL_BUNDLES)[o.item]
					expect(app.rules.shop(ingredient,6),"purchase binding supplies")
					expect(app.rules.bind_bundle(o.npc,giver.map,Vector2i(giver.cell[0],giver.cell[1]),o.item),"actual binding objective")
				"purchase":
					expect(app.rules.reference_trade(o.npc,o.item,true,0.0),"actual named shop purchase")
				"warehouse":
					expect(app.rules.save_location(o.map,Vector2i(9,11),0.0),"warehouse location fixture")
					expect(app.rules.warehouse(o.item,o.direction=="deposit"),"actual warehouse objective: "+app.rules.message)
				"repair":
					var repair_item: String="robe" if EditionRegion.shop(o.npc).accepted_modes.any(func(mode):return int(mode)==10) else "wood_sword"
					var other_shop: String="server:merchant:61" if repair_item=="robe" else "server:merchant:131"
					var incompatible_shop: String="server:merchant:131" if repair_item=="robe" else "server:merchant:61"
					var weapon_slot: int=EditionInventory.SLOTS.find(EditionRules.ITEMS[repair_item].slot)
					next=app.rules.state.duplicate(true)
					next.items=next.items.filter(func(item):return item.container!="equipment" or int(item.slot)!=weapon_slot)
					next.items.append(EditionInventory.make_item(repair_item,1,"equipment",weapon_slot,50));EditionInventory.mirror(next)
					expect(app.rules.apply(next,"damaged_weapon_fixture"),"prepare damaged equipment")
					var other_repair: bool=app.rules.reference_repair(other_shop)
					expect(other_repair and Story.progress(app.rules.state,q,q.objectives.find(o))==0,"other smith repair does not satisfy named NPC objective")
					next=app.rules.state.duplicate(true)
					for item in next.items:
						if item.container=="equipment" and int(item.slot)==weapon_slot:item.durability=50
					EditionInventory.mirror(next);expect(app.rules.apply(next,"damage_again_fixture"),"restore test wear")
					var smith: Dictionary=app.rules.story_npc(o.npc)
					expect(app.rules.story_talk(smith.id,smith.map,Vector2i(smith.cell[0],smith.cell[1])) and not Story.ready(app.rules.state,q),"talking alone does not repair")
					var intact: Dictionary=app.rules.state.duplicate(true)
					app.store.db.query("PRAGMA query_only=ON;")
					expect(not app.rules.reference_repair(o.npc) and app.rules.state==intact,"repair failure rolls back durability money and progress")
					app.store.db.query("PRAGMA query_only=OFF;")
					var named_repair: bool=app.rules.reference_repair(o.npc)
					expect(named_repair and Story.progress(app.rules.state,q,q.objectives.find(o))>=int(o.count),"actual named smith repair progresses task")
					intact=app.rules.state.duplicate(true)
					expect(not app.rules.reference_repair(o.npc) and app.rules.state==intact,"intact equipment does not trigger another repair")
					expect(app.rules.shop(repair_item,1),"prepare spare weapon for sale")
					intact=app.rules.state.duplicate(true)
					expect(not app.rules.reference_trade(incompatible_shop,repair_item,false,0) and app.rules.state==intact,"incompatible shop refuses equipment sale")
					expect(app.rules.reference_trade(o.npc,repair_item,false,0) and app.rules.state.gold>intact.gold,"designated shop accepts equipment category")

				"craft":
					if o.npc=="server:merchant:109":
						exercise_mystery_craft(o);continue
					var craft=preload("res://scripts/edition2011/peach_crafting.gd")
					var recipe: Dictionary=craft.recipes().filter(func(r):return r.product==o.item)[0]
					next=app.rules.state.duplicate(true);next.level=maxi(60,int(next.level));next.gold=maxi(1000,int(next.gold))
					for id in recipe.materials:
						var missing:=maxi(0,int(recipe.materials[id])-int(next.inventory.get(id,0)))
						app.rules.count_item(next,id,missing)
					expect(app.rules.apply(next,"craft_material_fixture"),"prepare craft materials")
					var maker: Dictionary=app.rules.story_npc(o.npc)
					expect(craft.craft(app.rules,maker.map,Vector2i(maker.cell[0]+1,maker.cell[1]),o.item,int(app.rules.state.revision)),"actual crafting transaction advances objective")
				"relationship":
					if Story.progress(app.rules.state,q,q.objectives.find(o))<int(o.count):expect(app.rules.social("guild_member" if o.field=="guild" and not app.rules.state.guild.is_empty() else o.field,o.name),"real relationship operation")
				"talk":
					var person: Dictionary=app.rules.story_npc(o.npc)
					expect(app.rules.story_talk(o.npc,person.map,Vector2i(person.cell[0],person.cell[1])),"talk progress")
				"visit":expect(app.rules.story_arrival(o.map) if o.has("party_member") else app.rules.save_location(o.map,Vector2i(1,1),0.0),"visit progress")
				"collect":
					if EditionRules.ITEMS[o.item].get("quest_material",false):
						var loot: Dictionary={}
						for entry in app.rules.state.get("ground_loot",[]):
							if entry.type==o.item:loot=entry;break
						expect(not loot.is_empty(),"quest token on ground")
						if not loot.is_empty():expect(app.rules.pickup(loot.uid,loot.map,Vector2i(loot.cell[0],loot.cell[1])),"collect dropped task token")
					else:
						var missing:=maxi(0,int(Story.collection_requirements(q)[o.item])-int(app.rules.state.inventory.get(o.item,0)))
						expect(missing==0 or app.rules.shop(o.item,missing),"collect purchases")
				"skill":
					var desired: String=o.get("skills_by_job",{}).get(app.rules.character.job,{"战士":"slaying","法师":"fireball","道士":"heal"}[quest_job])
					next=app.rules.state.duplicate(true);next.level=maxi(int(next.level),int(EditionSkills.DEFINITIONS[desired].level));app.rules.apply(next,"book_level_fixture")
					var book:=""
					for id in EditionRules.ITEMS:
						if EditionRules.ITEMS[id].get("skill_book")==desired:book=id;break
					expect(app.rules.state.skills.has(desired) or (not book.is_empty() and app.rules.shop(book,1) and app.rules.use_item(book)),"learn objective requires real book")
					if o.has("min_proficiency"):
						next=app.rules.state.duplicate(true);next.skills[desired].proficiency=int(o.min_proficiency)
						expect(app.rules.apply(next,"proficiency_fixture"),"practice progress fixture")
				"kill":
					var untouched: Dictionary=app.rules.state.duplicate(true)
					expect(not Story.observe(untouched,"kill",{"name":o.names[0],"map":"wrong-map"}),"same name in wrong region does not count")
					expect(not Story.observe(untouched,"kill",{"name":"wrong-monster","map":o.maps[0]}),"wrong monster does not count")
					for index in range(int(o.count)):
						var monster:={"id":q.id+":"+str(q.objectives.find(o))+":"+str(index),"spawn_id":"story-fixture","respawn_seconds":60,"exp":1,"drops":[],"name":o.names[index%o.names.size()],"map":o.maps[0]}
						var token: String="story-kill:"+monster.id
						var before_count:=Story.progress(app.rules.state,q,q.objectives.find(o))
						app.store.db.query("PRAGMA query_only=ON;")
						expect(not app.rules.reward_kill(token,"",monster,10.0),"kill write failure refuses progress")
						app.store.db.query("PRAGMA query_only=OFF;")
						expect(Story.progress(app.rules.state,q,q.objectives.find(o))==before_count,"failed kill preserves count")
						expect(app.rules.reward_kill(token,"",monster,10.0),"kill enters settlement transaction")
						expect(not app.rules.reward_kill(token,"",monster,10.0),"same life cannot credit twice")
						expect(Story.progress(app.rules.state,q,q.objectives.find(o))==index+1,"exact kill progress")
				"flag":
					next=app.rules.state.duplicate(true)
					if o.field=="cook_trial":
						var seed: Dictionary=next.duplicate(true);seed.map="1";seed.hp=1
						seed.erase("cook_trial")
						var trial: Dictionary=preload("res://scripts/edition2011/cook_trial_state.gd").begin(seed,app.rules.character.job,Vector2i(239,301),100)
						trial.active=false;trial.won=true;trial.claimed=true;next.cook_trial=trial
					elif o.field=="feast_gift":next.feast_gift={"stage":"done","answers":["angry"],"bonus":false,"rewards":{}}
					else:next[o.field]={o.key:true}
					expect(app.rules.apply(next,"story_flag_fixture"),"valid story flag fixture; not combat verification")
		expect(Story.ready(app.rules.state,q),"all objectives ready "+q.id)
		var before: Dictionary=app.rules.state.duplicate(true)
		app.store.db.query("PRAGMA query_only=ON;")
		expect(not app.rules.story_action(q.id,"submit",q.end_npc,end.map,Vector2i(end.cell[0],end.cell[1])),"failed write rejects "+q.id)
		expect(app.rules.state==before,"failed write preserves reward and items "+q.id)
		app.store.db.query("PRAGMA query_only=OFF;")
		expect(app.rules.story_action(q.id,"submit",q.end_npc,end.map,Vector2i(end.cell[0],end.cell[1])),"submit "+q.id+": "+app.rules.message)
		before=app.rules.state.duplicate(true)
		expect(not app.rules.story_action(q.id,"submit",q.end_npc,end.map,Vector2i(end.cell[0],end.cell[1])) and app.rules.state==before,"reward not repeated "+q.id)
		expect(app.store.load_world(app.rules.character.id).quests.get(q.id)=="done","completed quest persisted "+q.id)
		quest_results.append({"id":q.id,"checks":checks-checks_before,"failures":failures.slice(failures_before),"passed":failures.size()==failures_before})
	mark_phase("rules_complete")
	# Real mouse input reaches the new NPC accept action, without directly emitting signals.
	app.start_character({"id":"story_mouse","name":"村庄来信","gender":"男","job":quest_job})
	next=app.rules.state.duplicate(true);next.quests.nv_patrol="done";next.novice={"chickens":0,"patrol":true};app.rules.apply(next,"ui_prerequisite_fixture")
	app.world.player.reset(EditionVillage.SPAWN);app.world.paused=false;app.show_story({"id":"border:elder","cell":[287,618]});mark_phase("mouse_panel_created");await settle();mark_phase("mouse_panel_settled")
	expect(Rect2(Vector2.ZERO,Vector2(800,600)).encloses(app.panel.get_global_rect()),"story window fits minimum resolution")
	var view=app.form.get_child(1)
	var accept: Button=null
	for child in view.details.get_children():
		if child is Button and child.text=="接受委托":accept=child
	expect(accept!=null and not accept.disabled,"NPC accept is visible and enabled")
	if accept!=null:
		var e:=InputEventMouseButton.new();e.position=accept.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;root.push_input(e,true)
		e=e.duplicate();e.pressed=false;root.push_input(e,true);await settle()
		expect(app.rules.state.quests.get("story_letter")=="accepted","mouse click accepts story quest")
	mark_phase("await_render")
	# Native background windows may stop scheduling draws; render the tested
	# viewport explicitly instead of waiting forever for an automatic callback.
	RenderingServer.force_draw(false)
	mark_phase("render_received")
	root.get_texture().get_image().save_png("res://../artifacts/world-story/story-panel.png")
	var report:={"catalog_sha256":FileAccess.get_sha256("res://content/2011/world-story.json"),"quest_results":quest_results,"checks":checks,"failures":failures,"quests":Story.data().quests.size(),"exercised_quests":exercised_quests,"quest_job":quest_job,"phase_elapsed_ms":phase_times,"scope":"isolated rule and UI tests; visit/survey fixtures do not prove real travel or full world completion"}
	FileAccess.open("res://../artifacts/world-story/tests-"+quest_job+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
	app.queue_free();await settle();quit(0 if failures.is_empty() else 1)

func exercise_mining(q: Dictionary,objective: Dictionary) -> void:
	var Mining=preload("res://scripts/edition2011/mining.gd")
	var was_paused: bool=app.world.paused
	expect(app.enter_map(objective.map,Vector2i(-1,-1),false),"load mining objective map")
	var spawn: Vector2i=app.world.player.cell
	var found:=false
	for y in range(app.world.navigation.size.y):
		if found:break
		for x in range(app.world.navigation.size.x):
			var at:=Vector2i(x,y)
			if app.world.navigation.path(spawn,at).is_empty():continue
			for direction in range(8):
				if Mining.wall(app.world.navigation,at,direction):
					app.world.player.cell=at;app.world.player.direction=direction;found=true;break
			if found:break
	expect(found,"mining objective has reachable wall")
	if not found:app.world.paused=was_paused;return
	var prepared: Dictionary=app.rules.state.duplicate(true)
	prepared.items=prepared.items.filter(func(i):return i.container!="equipment" or int(i.slot)!=0)
	prepared.items.append(EditionInventory.make_item("ref:87",1,"equipment",0))
	EditionInventory.mirror(prepared)
	prepared.map=objective.map;prepared.cell=[app.world.player.cell.x,app.world.player.cell.y]
	expect(app.rules.apply(prepared,"mining_equipment_fixture"),"prepare mining equipment")
	app.world.paused=false
	for swing in range(100):
		if Story.progress(app.rules.state,q,q.objectives.find(objective))>=int(objective.count):break
		app.elapsed=maxf(app.elapsed+1,float(app.rules.state.get("mining",{}).get("ready",0)))
		expect(Mining.swing(app),"actual mining transaction in profession matrix")
	expect(Story.progress(app.rules.state,q,q.objectives.find(objective))==int(objective.count),"profession mining objective complete")
	app.world.paused=was_paused

func exercise_mystery_craft(objective: Dictionary) -> void:
	var Books=preload("res://scripts/edition2011/mystery_books.gd")
	var recipe: Dictionary=Books.WEAPONS[quest_job]
	var prepared: Dictionary=app.rules.state.duplicate(true)
	app.rules.count_item(prepared,"ref:226",1)
	expect(EditionInventory.reconcile(prepared),"prepare gold bar instance")
	var ore:=EditionInventory.make_item("ref:132",int(recipe.count),"inventory",EditionInventory.free_slot(prepared.items,"inventory"));ore.purity=18
	prepared.items.append(ore);EditionInventory.mirror(prepared)
	expect(app.rules.apply(prepared,"mystery_materials_fixture"),"prepare graded recipe materials")
	var was_paused: bool=app.world.paused
	expect(app.enter_map("q016",Vector2i(14,22),false),"enter mystery craftsman room")
	app.world.paused=false
	expect(recipe.product==objective.item and Books.craft(app,int(app.rules.state.revision)),"actual mystery craft objective")
	app.world.paused=was_paused
