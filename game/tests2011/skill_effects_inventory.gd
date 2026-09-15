extends SceneTree
# Code inventory only; never substitutes for visual, audio or historical acceptance.
const Effects=preload("res://scripts/edition2011/skill_effects.gd")
func _initialize():
 var rows:Array=[]
 for id in EditionSkills.DEFINITIONS:
  var skill:Dictionary=EditionSkills.DEFINITIONS[id]
  var row:Dictionary={"id":id,"name":skill.name,"job":skill.job,"status":"visual_mapping_pending","channels":{}}
  if skill.get("passive",false):row.status="passive_rule_only"
  elif Effects.PROFILES.has(id):
   row.status="source_frames_connected_not_fully_verified"
   row.channels.impact_or_cast=Effects.PROFILES[id].duplicate(true)
  if Effects.PROJECTILES.has(id):row.channels.flight={"bank":"magic","start":Effects.PROJECTILES[id],"directions":16,"stride":10,"count":6}
  if Effects.MELEE.has(id):
   row.status="source_frames_connected_not_fully_verified"
   row.channels.weapon_effect={"bank":"magic","start":Effects.MELEE[id],"directions":8,"stride":10,"action":skill.action}
  if id=="shield":
   row.status="source_frames_connected_not_fully_verified"
   row.channels.state={"bank":"magic","loop_start":3890,"hurt_start":3900,"count":3}
  row.acceptance="unverified"
  row.known_gaps=[]
  if id=="talisman":row.known_gaps.append("flight_channel_unmapped_reference_only_has_stationary_bujauk_explosion")
  if id=="manafire":row.known_gaps.append("reference_uses_nearest_effect_adaptation_not_verified_original")
  if id in ["armor","ghostshield"]:row.known_gaps.append("reference_comment_16_frames_conflicts_with_runtime_10_frames")
  if id=="groupheal":row.known_gaps.append("party_recipient_visuals_not_verified")
  if row.status=="visual_mapping_pending":row.known_gaps.append("original_effect_channel_not_connected")
  rows.append(row)
 var report:Dictionary={"scope":"implementation mapping only, not visual, audio or historical fidelity acceptance","generator":"res://tests2011/skill_effects_inventory.gd","skills":rows}
 var file:=FileAccess.open("res://../artifacts/skill-effects-coverage.json",FileAccess.WRITE)
 if file==null:printerr("Cannot write skill effects inventory");quit(1);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("Inventory: ",rows.size()," skills; pending: ",rows.filter(func(r):return r.status=="visual_mapping_pending").map(func(r):return r.name))
 quit()
