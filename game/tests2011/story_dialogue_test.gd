extends SceneTree
const Story=preload("res://scripts/edition2011/story.gd")
var app
var checks:=0
var failures: Array=[]
func expect(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);printerr(note)
func _initialize():call_deferred("run")
func settle() -> void:
	for i in range(5):await process_frame
func press(button: int) -> void:
	var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=true;root.push_input(e,true);await settle()
func run() -> void:
	root.size=Vector2i(800,600);app=load("res://edition2011.tscn").instantiate();app.configure_native_window=false;app.allow_focus_pause=false
	app.store.path="/tmp/story-dialogue-"+Crypto.new().generate_random_bytes(8).hex_encode()+".sqlite";root.add_child(app);await settle();app.set_process(false)
	app.start_character({"id":"dialogue","name":"见闻验收","gender":"男","job":"战士"})
	for q in Story.data().quests:
		var first_talk:=true
		for o in q.objectives:
			if o.type!="talk":continue
			var npc: Dictionary=app.rules.story_npc(o.npc)
			if first_talk:
				expect(Story.npc_dialogue(app.rules.state,q,npc.id).is_empty(),"unaccepted response hidden "+q.id)
				var next: Dictionary=app.rules.state.duplicate(true)
				for id in q.requires:next.quests[id]="done"
				if "nv_patrol" in q.requires:next.novice={"chickens":0,"patrol":true}
				expect(app.rules.apply(next,"dialogue_prerequisite_fixture"),"valid dialogue prerequisites")
				var start: Dictionary=app.rules.story_npc(q.start_npc)
				expect(app.rules.story_action(q.id,"accept",start.id,start.map,Vector2i(start.cell[0],start.cell[1])),"accept "+q.id)
			first_talk=false
			expect(Story.involves_npc(app.rules.state,q,npc.id),"intermediate NPC visible")
			expect(not Story.npc_dialogue(app.rules.state,q,npc.id).is_empty(),"authored response exists")
			app.windows.close_all();expect(app.enter_map(npc.map,Vector2i(npc.cell[0],npc.cell[1])+Vector2i(1,0)),"load intermediate NPC map")
			app.world.paused=false
			var live: Dictionary={}
			for entity in app.world.entities:
				if entity.id==npc.id:live=entity
			expect(not live.is_empty(),"runtime NPC exists")
			var before: Dictionary=app.rules.state.duplicate(true)
			app.store.db.query("PRAGMA query_only=ON;");app.controller_interact(live);await settle()
			expect(app.rules.state==before and not app.windows.windows.has("手柄人物委托"),"failed talk not presented as recorded")
			app.store.db.query("PRAGMA query_only=OFF;");app.controller_interact(live);await settle()
			var view=app.form.get_child(1)
			for i in range(view.rows.size()):
				if view.rows[i].id==q.id:view.cursor=i
			await press(JOY_BUTTON_A)
			expect(o.dialogue in view.text.text,"controller displays NPC response")
			before=app.rules.state.duplicate(true)
			var can_submit: bool=npc.id==q.end_npc and Story.ready(before,q)
			await press(JOY_BUTTON_A)
			if can_submit:
				expect(app.rules.state.quests[q.id]=="done" and app.rules.state.quest_receipts.has(q.id),"recipient confirms completed conversation reward")
				var awarded: Dictionary=app.rules.state.duplicate(true)
				expect(not app.rules.story_action(q.id,"submit",npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])) and app.rules.state==awarded,"conversation reward cannot be claimed twice")
			else:expect(app.rules.state==before,"intermediate or incomplete NPC cannot grant reward")
			expect(int(app.store.load_world(app.rules.character.id).story_progress[q.id][str(q.objectives.find(o))])==1,"talk progress persists")
			var talks: Array=q.objectives.filter(func(objective):return objective.type=="talk")
			if talks.size()>1:
				var completed:=0
				for objective in talks:
					if Story.progress(app.rules.state,q,q.objectives.find(objective))==1:completed+=1
				var snapshot: Dictionary=app.rules.state.duplicate(true)
				expect(app.rules.story_talk(npc.id,npc.map,Vector2i(npc.cell[0],npc.cell[1])) and app.rules.state==snapshot,"repeated NPC conversation does not advance another witness")
				if completed<talks.size():
					expect(not Story.ready(app.rules.state,q),"one witness cannot satisfy multiple NPC task")
					var recipient: Dictionary=app.rules.story_npc(q.end_npc)
					expect(not app.rules.story_action(q.id,"submit",recipient.id,recipient.map,Vector2i(recipient.cell[0],recipient.cell[1])) and app.rules.state==snapshot,"partial conversations cannot award or change state")
				elif talks.size()==q.objectives.size():expect(Story.ready(app.rules.state,q) or app.rules.state.quests.get(q.id)=="done","all distinct witnesses allow delivery or completed receipt")

			app.windows.close_all();app.show_story(live);await settle()
			view=app.form.get_child(1);view.selected=q.id;view.refresh();await settle()
			var found:=false
			for child in view.details.get_children():
				if child is Label and o.dialogue in child.text:found=true
			expect(found,"mouse panel displays same response")
			if q.id=="story_apprentice_book":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../artifacts/world-story/npc-dialogue.png")
	var report:={"checks":checks,"failures":failures,"scope":"all authored intermediate NPCs, authored responses in both interfaces, actual map entities, talk save failure and retry; prerequisites and travel are fixtures"}
	FileAccess.open("res://../artifacts/world-story/dialogue-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));app.queue_free();await settle();quit(0 if failures.is_empty() else 1)
