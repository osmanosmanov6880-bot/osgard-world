import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def load(name,path):
 s=importlib.util.spec_from_file_location(name,ROOT/"scripts"/path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
http=load("staging","staging-http-acceptance.py")
rollback=load("rollback","rollback-readiness.py")
config=load("cfg","release-config-audit.py")
matrix=load("matrix","release-matrix.py")
class HTTPResponse:
 status=200
 headers={"Content-Type":"text/html"}
 def __init__(self,url):self.url=url
 def __enter__(self):return self
 def __exit__(self,*args):pass
 def geturl(self):return self.url
 def read(self,n):return b"<html><title>ok</title></html>"
class OperationsTest(unittest.TestCase):
 def test_http_origin(self):
  for url in ["http://staging.example.com","https://localhost","https://staging.example.com/path","https://user@staging.example.com"]:
   with self.subTest(url=url),self.assertRaises(ValueError):http.origin(url)
 def test_private_ip_origins_rejected(self):
  for url in ["https://10.0.0.1","https://192.168.1.5","https://127.0.0.1","https://[::1]","https://169.254.1.1"]:
   with self.subTest(url=url),self.assertRaises(ValueError):http.origin(url)
 def test_redirect_handler_fails_closed(self):
  handler=http.BlockRedirects()
  with self.assertRaisesRegex(ValueError,"redirect refused"):
   handler.redirect_request(None,None,302,"redirect",{},"https://evil.example.org")
 def test_http_acceptance(self):
  result=http.probe("https://staging.example.com",opener=lambda req,timeout:HTTPResponse(req.full_url))
  self.assertEqual(result["status"],"passed")
  self.assertEqual(len(result["routes"]),len(http.ROUTES))
 def test_http_cross_origin_redirect(self):
  result=http.probe("https://staging.example.com",opener=lambda req,timeout:HTTPResponse("https://evil.example.org"))
  self.assertEqual(result["status"],"blocked")
 def test_rollback_fails_closed(self):
  self.assertEqual(rollback.verify({})["status"],"blocked")
 def test_rollback_ready_only_for_review(self):
  data={"schema_version":1,"previous_commit":"a"*40,"previous_zip_sha256":"b"*64,"backup_sha256":"c"*64,"payments_enabled":False}
  for key in ("backup_restore_tested","previous_release_available","rollback_runbook_reviewed","operator_assigned","maintenance_window_approved"):data[key]=True
  self.assertEqual(rollback.verify(data)["status"],"ready_for_human_review")
  data["payments_enabled"]=True
  self.assertEqual(rollback.verify(data)["status"],"blocked")
 def test_config_fail_closed(self):
  with tempfile.TemporaryDirectory() as d:
   self.assertEqual(config.audit(d)["status"],"blocked")
 def test_config_valid_and_secret_detected(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d)
   (root/"_headers").write_text("X-Content-Type-Options: nosniff\nReferrer-Policy: strict-origin-when-cross-origin")
   (root/"_redirects").write_text("/old /new 301")
   (root/"robots.txt").write_text("User-agent: *")
   self.assertEqual(config.audit(root)["status"],"passed")
   (root/".env.production").write_text("secret")
   self.assertEqual(config.audit(root)["status"],"blocked")
 def test_matrix_missing_and_partial(self):
  self.assertEqual(matrix.assess({})["status"],"blocked")
  d={key:{"status":"passed"} for key in matrix.GATES};d["human_approval"]=False
  self.assertEqual(matrix.assess(d)["status"],"ready_for_review")
  d["backup_recovery"]["status"]="unknown"
  self.assertEqual(matrix.assess(d)["status"],"blocked")
if __name__=="__main__":unittest.main()
