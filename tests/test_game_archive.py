import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("games",ROOT/"scripts/verify-game-archive.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class GameArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.file=Path(self.temp.name)/"games.zip"
        self.worlds=[{"id":f"zion-{i:03d}","route":f"/games/zion-9/queue/ZION-{i:03d}/index.html"} for i in range(20,31)]
        self.files={"index.html":b"<html></html>","games/index.html":b"<html></html>",
                    "play/index.html":b"<html></html>"}
        for name in m.LEGACY:
            self.files[f"games/{name}/index.html"]=b"<html></html>"
        for world in self.worlds:
            self.files[world["route"].lstrip("/")]=b'<html><script src="local.js"></script></html>'
            self.files[world["route"].lstrip("/").replace("index.html","local.js")]=b"console.log(1)"
    def pack(self):
        self.files["games/zion-9/worlds.json"]=json.dumps({"games":self.worlds}).encode()
        with zipfile.ZipFile(self.file,"w",compression=zipfile.ZIP_DEFLATED) as z:
            for k,v in self.files.items():z.writestr(k,v)
        return self.file
    def test_all_games(self):
        d=m.verify(self.pack())
        self.assertEqual((d["zion_worlds"],d["legacy_entrypoints"]),(11,8))
        self.assertEqual(d["local_dependencies_checked"],11)
    def test_missing_game(self):
        self.files.pop("games/zion-9/queue/ZION-030/index.html")
        with self.assertRaisesRegex(ValueError,"missing game routes"):m.verify(self.pack())
    def test_missing_local_script(self):
        self.files.pop("games/zion-9/queue/ZION-020/local.js")
        with self.assertRaisesRegex(ValueError,"missing dependency"):m.verify(self.pack())
    def test_duplicate_id(self):
        self.worlds[1]=dict(self.worlds[0])
        with self.assertRaisesRegex(ValueError,"duplicate"):m.verify(self.pack())
    def test_mismatched_route(self):
        self.worlds[0]["route"]="/games/other/index.html"
        with self.assertRaisesRegex(ValueError,"mismatch"):m.verify(self.pack())
    def test_missing_legacy(self):
        self.files.pop("games/swarm/index.html")
        with self.assertRaisesRegex(ValueError,"missing game routes"):m.verify(self.pack())
    def test_legacy_invalid_html(self):
        self.files["games/swarm/index.html"]=b"this is not a real HTML shell"
        with self.assertRaisesRegex(ValueError,"invalid legacy HTML"):
            m.verify(self.pack())
    def test_legacy_missing_script_dependency(self):
        self.files["games/swarm/index.html"]=b'<html><script src="missing.js"></script></html>'
        with self.assertRaisesRegex(ValueError,"legacy swarm: missing dependency"):
            m.verify(self.pack())
    def test_legacy_valid_script_dependency(self):
        self.files["games/swarm/index.html"]=b'<html><script src="main.js"></script></html>'
        self.files["games/swarm/main.js"]=b"console.log('legacy')"
        d=m.verify(self.pack())
        self.assertEqual(d["local_dependencies_checked"],12)
    def test_invalid_html(self):
        self.files["games/zion-9/queue/ZION-020/index.html"]=b"broken"
        with self.assertRaisesRegex(ValueError,"invalid HTML"):m.verify(self.pack())
    def test_unexpected_worlds(self):
        self.worlds=self.worlds[:-1]
        with self.assertRaisesRegex(ValueError,"11 worlds"):m.verify(self.pack())
    def test_oversized_world_manifest(self):
        self.pack()
        self.files["games/zion-9/worlds.json"]=b" " * (m.MAX_WORLD_MANIFEST_BYTES+1)
        with zipfile.ZipFile(self.file,"w") as z:
            for key,value in self.files.items():
                z.writestr(key,value)
        with self.assertRaisesRegex(ValueError,"oversized"):
            m.verify(self.file)
    def test_oversized_game_html(self):
        self.files["games/zion-9/queue/ZION-020/index.html"]=b"<html>"+b"x"*(m.MAX_GAME_HTML_BYTES+1)+b"</html>"
        with self.assertRaisesRegex(ValueError,"oversized"):
            m.verify(self.pack())
    def test_duplicate_zip_member_rejected(self):
        self.pack()
        with zipfile.ZipFile(self.file,"a") as z:
            z.writestr("games/index.html",b"<html></html>")
        with self.assertRaisesRegex(ValueError,"duplicate ZIP"):
            m.verify(self.file)
    def test_case_colliding_zip_member_rejected(self):
        self.pack()
        with zipfile.ZipFile(self.file,"a") as z:
            z.writestr("GAMES/index.html",b"<html></html>")
        with self.assertRaisesRegex(ValueError,"case-colliding"):
            m.verify(self.file)
    def test_no_remote_forced(self):
        self.files["games/zion-9/queue/ZION-020/index.html"]=b'<html><script src="https://example.com"></script></html>'
        self.assertEqual(m.verify(self.pack())["status"],"verified")
if __name__=="__main__":unittest.main()
