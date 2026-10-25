import importlib.util, unittest, tempfile, hashlib, struct
from pathlib import Path
p=Path(__file__).with_name("omega_r73_field_qa.py")
s=importlib.util.spec_from_file_location("r73",p); m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Tests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name)
  self.manifest=dict(engine="Godot 4.4.1",source_path="godot/empire-omega",artifact_kind="native-Godot-HTML5-export",source_commit="a"*40)
  self.missions=[dict(id="drive",reward=i+100) for i in range(40)]
  self.x=m.make_template(self.manifest,self.missions)
 def put(self,name,data):
  (self.root/name).write_bytes(data);return hashlib.sha256(data).hexdigest()
 def complete(self):
  png=b"\x89PNG\r\n\x1a\n"+struct.pack(">I",13)+b"IHDR"+struct.pack(">II",320,240)+b"\x08\x06\x00\x00\x00"+b"x"*130
  self.x.update(tester="Operator",platform="desktop",human_operated=True,captured_utc="2026-10-25T15:00:00Z",recording_duration_s=240,recording_sha256=self.put("campaign.webm",b"\x1a\x45\xdf\xa3"+b"x"*2200))
  for i,e in enumerate(self.x["missions"]):e.update(result="passed",start_s=1+i*5,finish_s=3+i*5,screen_sha256=self.put(e["screen_file"],png+bytes([i])))
  for i,e in enumerate(self.x["save_reload_checkpoints"]):e.update(save_reload_verified=True,stage_after_reload=e["stage"],screen_sha256=self.put(e["screen_file"],png+bytes([i+40])))
 def run_gate(self):return m.verify_campaign(self.x,self.manifest,self.missions,self.root)
 def test_empty_template_is_hold(self):
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_full_pack_is_review_only(self):
  self.complete();r=self.run_gate();self.assertEqual(r["mission_records_checked"],40);self.assertFalse(r["production_go"])
 def test_tampered_video(self):
  self.complete();(self.root/"campaign.webm").write_bytes(b"tampered"*300)
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_wrong_source(self):
  self.complete();self.x["source_commit"]="b"*40
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_stage_skipping(self):
  self.complete();self.x["missions"][11]["stage"]=14
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_duplicate_image(self):
  self.complete();self.x["missions"][1]["screen_file"]=self.x["missions"][0]["screen_file"]
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_timeline_overlap(self):
  self.complete();self.x["missions"][2]["start_s"]=2
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_save_rollback(self):
  self.complete();self.x["save_reload_checkpoints"][0]["stage_after_reload"]=5
  with self.assertRaises(m.EvidenceError):self.run_gate()
 def test_not_human(self):
  self.complete();self.x["human_operated"]=False
  with self.assertRaises(m.EvidenceError):self.run_gate()
if __name__=="__main__":unittest.main(verbosity=2)
