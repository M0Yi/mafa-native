"""Real process termination at controlled SQLite transaction boundaries.
Uses the store's world/operation transaction shape; not an engine crash or power cut.
"""
import json,sqlite3,subprocess,sys,tempfile,unittest
from pathlib import Path
WORKER=r'''
import sqlite3,sys,json
c=sqlite3.connect(sys.argv[1]);c.execute('PRAGMA journal_mode=WAL');c.execute('PRAGMA synchronous=FULL')
c.execute('BEGIN IMMEDIATE')
c.execute("UPDATE worlds SET revision=2,state=? WHERE character_id='hero'", (json.dumps({'gold':600,'items':[{'uid':'potion-stack','count':3}]}),))
if sys.argv[2]!='after_world':
 c.execute("INSERT INTO operations VALUES('reward','hero','story_submit',2)")
if sys.argv[2]=='after_commit':c.commit()
print('boundary',flush=True)
sys.stdin.read()
'''
class InterruptionTests(unittest.TestCase):
 def test_world_and_receipt_survive_together(self):
  for boundary in ['after_world','after_receipt','after_commit']:
   with self.subTest(boundary=boundary),tempfile.TemporaryDirectory() as folder:
    path=Path(folder)/'world.sqlite'
    with sqlite3.connect(path) as c:
     c.executescript("CREATE TABLE worlds(character_id TEXT PRIMARY KEY,revision INTEGER,state TEXT);CREATE TABLE operations(id TEXT PRIMARY KEY,character_id TEXT,action TEXT,world_revision INTEGER);INSERT INTO worlds VALUES('hero',1,'{\"gold\":500}');")
    with sqlite3.connect(path) as c:
     c.execute("UPDATE worlds SET state=? WHERE character_id='hero'", (json.dumps({'gold':500,'items':[{'uid':'potion-stack','count':2}]}),))
    proc=subprocess.Popen([sys.executable,'-u','-c',WORKER,str(path),boundary],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
     # communicate cannot be used here: EOF deliberately releases the worker.
     import queue,threading
     lines=queue.Queue()
     reader=threading.Thread(target=lambda:lines.put(proc.stdout.readline()),daemon=True);reader.start()
     self.assertEqual(lines.get(timeout=10).strip(),'boundary')
     reader.join(timeout=1)
     proc.kill();proc.wait(timeout=10)
     with sqlite3.connect(path) as c:
      self.assertEqual(c.execute('PRAGMA integrity_check').fetchone()[0],'ok')
      rev,state=c.execute('SELECT revision,state FROM worlds').fetchone()
      receipt=c.execute("SELECT count(*) FROM operations WHERE id='reward'").fetchone()[0]
      committed=boundary=='after_commit'
      decoded=json.loads(state)
      self.assertEqual((rev,decoded['gold'],decoded['items'],receipt),(2,600,[{'uid':'potion-stack','count':3}],1) if committed else (1,500,[{'uid':'potion-stack','count':2}],0))
    finally:
     if proc.poll() is None:proc.kill();proc.wait(timeout=10)
     for stream in [proc.stdin,proc.stdout,proc.stderr]:stream.close()
if __name__=='__main__':unittest.main()
