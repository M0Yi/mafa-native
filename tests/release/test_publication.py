import sys,unittest,tempfile
from unittest.mock import patch
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/release'))
import source_files
class PublicationTests(unittest.TestCase):
 def test_regression_sources_are_deliverable(self):
  selected=set(source_files.audit())
  for name in ['connections_test.gd','novice_gender_reward_test.gd','story_reward_transaction_test.gd','resource_settings_test.gd','cache_startup_test.gd','auto_skill_order_test.gd','skill_bind_failure_test.gd','pickup_retry_closeout_test.gd','window_position_closeout_test.gd']:
   self.assertIn(ROOT/'game/tests2011'/name,selected)
  self.assertIn(ROOT/'tools/check_item_ui_closeout.py',selected)
  self.assertIn(ROOT/'tools/sample_process.py',selected)
  for name in ['character_switch_closeout_test.gd','controller_stale_item_closeout_test.gd','logout_failure_closeout_test.gd']:
   self.assertIn(ROOT/'game/tests2011'/name,selected)
  self.assertTrue(all(p.suffix in {'.gd','.uid'} for p in selected if 'tests2011' in p.parts))
 def test_audit_rejects_linked_external_file(self):
  with tempfile.TemporaryDirectory() as temporary:
   base=Path(temporary);root=base/'project';root.mkdir()
   external=base/'external.md';external.write_text('not a project source')
   linked=root/'README.md';linked.symlink_to(external)
   with patch.object(source_files,'ROOT',root),patch.object(source_files,'files',return_value=[linked]):
    with self.assertRaises(AssertionError):source_files.audit()
 def test_audit_rejects_external_parent_link(self):
  with tempfile.TemporaryDirectory() as temporary:
   base=Path(temporary);root=base/'project';root.mkdir();external=base/'external';external.mkdir()
   (external/'note.md').write_text('not a project source');(root/'release').symlink_to(external,target_is_directory=True)
   with patch.object(source_files,'ROOT',root),patch.object(source_files,'files',return_value=[root/'release/note.md']):
    with self.assertRaises(AssertionError):source_files.audit()
if __name__=='__main__':unittest.main()
