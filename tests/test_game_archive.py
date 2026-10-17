import importlib.util
import json
import tempfile
import unittest
from unittest import mock
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
    def test_manifest_array_rejected(self):
        self.files["games/zion-9/worlds.json"]=json.dumps([1,2,3]).encode()
        with zipfile.ZipFile(self.file,"w") as z:
            for name,payload in self.files.items(): z.writestr(name,payload)
        with self.assertRaisesRegex(ValueError,"manifest must be an object"):
            m.verify(self.file)
    def test_manifest_non_object_game_rejected(self):
        self.worlds[0]=None
        with self.assertRaisesRegex(ValueError,"must be object"):
            m.verify(self.pack())
    def test_manifest_non_string_id_rejected(self):
        self.worlds[0]["id"]=123
        with self.assertRaisesRegex(ValueError,"invalid ZION game ID"):
            m.verify(self.pack())
    def test_manifest_unknown_id_rejected(self):
        self.worlds[0]["id"]="zion-999"
        with self.assertRaisesRegex(ValueError,"invalid ZION game ID"):
            m.verify(self.pack())
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
    def test_zion_absolute_dependency_traversal_rejected(self):
        self.files["games/zion-9/queue/ZION-020/index.html"]=b'<html><script src="/../local.js"></script></html>'
        with self.assertRaisesRegex(ValueError,"unsafe absolute game dependency"):
            m.verify(self.pack())
    def test_legacy_absolute_dependency_traversal_rejected(self):
        self.files["games/swarm/index.html"]=b'<html><script src="/games/../local.js"></script></html>'
        with self.assertRaisesRegex(ValueError,"unsafe absolute game dependency"):
            m.verify(self.pack())
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
    def test_zip_parent_traversal_rejected(self):
        self.pack()
        with zipfile.ZipFile(self.file,"a") as z:
            z.writestr("../outside.txt",b"bad")
        with self.assertRaisesRegex(ValueError,"unsafe ZIP"):
            m.verify(self.file)
    def test_zip_backslash_path_rejected(self):
        self.pack()
        with zipfile.ZipFile(self.file,"a") as z:
            z.writestr("games\\\\escape.txt",b"bad")
        with self.assertRaisesRegex(ValueError,"unsafe ZIP"):
            m.verify(self.file)
    def test_zip_symlink_rejected(self):
        self.pack()
        info=zipfile.ZipInfo("games/unsafe-link")
        info.create_system=3
        info.external_attr=(0o120777<<16)
        with zipfile.ZipFile(self.file,"a") as z:
            z.writestr(info,b"../../unsafe")
        with self.assertRaisesRegex(ValueError,"symlink"):
            m.verify(self.file)
    def test_no_remote_forced(self):
        self.files["games/zion-9/queue/ZION-020/index.html"]=b'<html><script src="https://example.com"></script></html>'
        self.assertEqual(m.verify(self.pack())["status"],"verified")

    def set_html(self, body, route="games/zion-9/queue/ZION-020/index.html"):
        self.files[route] = ("<html>" + body + "</html>").encode("utf-8")

    def test_unquoted_uppercase_and_attribute_order(self):
        self.set_html('<SCRIPT defer data-label="x > y" SRC=local.js></SCRIPT>')
        self.assertEqual(m.verify(self.pack())["local_dependencies_checked"], 11)

    def test_first_duplicate_attribute_matches_browser(self):
        self.set_html('<script src=local.js src=missing.js></script>')
        self.assertEqual(m.verify(self.pack())["status"], "verified")
        self.set_html('<script src=missing.js src=local.js></script>')
        with self.assertRaisesRegex(ValueError, "missing dependency"):
            m.verify(self.pack())

    def test_canonical_navigation_and_connection_hints_are_not_assets(self):
        self.set_html('''<link href=/never-pack-this-route rel=canonical>
            <link rel=alternate href=/feed.xml><link rel=preconnect href=/origin>
            <link rel=dns-prefetch href=//example.invalid>
            <a href=/another-route>Next</a><script src=local.js></script>''')
        result = m.verify(self.pack())
        self.assertEqual(result["local_dependencies_checked"], 11)
        self.assertEqual(result["external_references_skipped"], 0)

    def test_comments_raw_text_and_inert_markup_do_not_load_assets(self):
        self.set_html('''<!-- <script src=missing-comment.js></script> -->
            <script>const example = '<img src="missing-string.png">';</script>
            <textarea><img src=missing-text.png></textarea>
            <template><link rel=stylesheet href=missing-template.css></template>
            <noscript><img src=missing-noscript.png></noscript>
            <script type=application/json src=missing-data.json></script>
            <script src=local.js></script>''')
        self.assertEqual(m.verify(self.pack())["local_dependencies_checked"], 11)

    def test_html_tokens_inside_comment_are_not_a_shell(self):
        self.files["games/zion-9/queue/ZION-020/index.html"] = b'<!-- <html></html> -->'
        with self.assertRaisesRegex(ValueError, "invalid HTML shell"):
            m.verify(self.pack())

    def test_catalog_shell_and_catalog_resources_are_checked(self):
        self.files["play/index.html"] = b"broken"
        with self.assertRaisesRegex(ValueError, "invalid HTML shell: catalog"):
            m.verify(self.pack())
        self.set_html('<script src=/assets/missing.js></script>', "play/index.html")
        with self.assertRaisesRegex(ValueError, "catalog play/index.html: missing dependency"):
            m.verify(self.pack())

    def test_shared_parent_relative_and_root_paths(self):
        self.set_html('''<script src=../../shared.js?build=42#module></script>
            <script src=/assets/root.js></script>''')
        self.files["games/zion-9/shared.js"] = b"console.log('shared')"
        self.files["assets/root.js"] = b"console.log('root')"
        self.assertEqual(m.verify(self.pack())["local_dependencies_checked"], 12)

    def test_url_decoding_entities_and_exact_single_percent_decode(self):
        self.set_html('''<script src="/assets/a&amp;b.js?cache=1&amp;v=2#code"></script>
            <script src="/assets/%D0%BC%D0%B8%D1%80%20one.js"></script>
            <script src=/assets/percent%2520name.js></script>''')
        for path in ("assets/a&b.js", "assets/мир one.js", "assets/percent%20name.js"):
            self.files[path] = b"console.log('decoded once')"
        self.assertEqual(m.verify(self.pack())["local_dependencies_checked"], 13)

    def test_ambiguous_or_escaping_local_resource_urls_fail_closed(self):
        cases = {
            "/%2e%2e/local.js": "unsafe absolute game dependency",
            "/games/%2E/local.js": "unsafe absolute game dependency",
            "../../../../../../local.js": "dependency escapes root",
            "/games%2Flocal.js": "encoded separator",
            "/games%5Clocal.js": "encoded separator",
            "/games\\local.js": "unsafe game dependency",
            "/bad%ZZ.js": "invalid percent escape",
            "/bad%00.js": "unsafe game dependency",
            "file:///tmp/local.js": "unsupported game resource URL scheme",
            "javascript:alert(1)": "unsupported game resource URL scheme",
        }
        for url, message in cases.items():
            with self.subTest(url=url):
                self.set_html('<script src="' + url + '"></script>')
                with self.assertRaisesRegex(ValueError, message):
                    m.verify(self.pack())

    def test_local_base_directory_and_only_first_base_are_used(self):
        self.set_html('''<base href=/assets/><base href=/incorrect/>
            <script src=shared.js></script>
            <style>.hero{background:url(cover.svg)}</style>''')
        self.files["assets/shared.js"] = b"console.log('base')"
        self.files["assets/cover.svg"] = b'<svg xmlns="http://www.w3.org/2000/svg"/>'
        self.assertEqual(m.verify(self.pack())["local_dependencies_checked"], 12)

    def test_root_base_and_relative_base(self):
        for base in ("/", "../../../../"):
            with self.subTest(base=base):
                self.set_html('<base href="' + base + '"><script src=shared.js></script>')
                self.files["shared.js"] = b"console.log('root base')"
                self.assertEqual(m.verify(self.pack())["status"], "verified")

    def test_external_base_and_remote_urls_are_reported_without_fetching(self):
        self.set_html('''<base href=https://example.invalid/assets/>
            <script src=not-in-archive.js></script><img src=/remote.svg>
            <script src=HTTP://example.invalid/a.js></script>''')
        result = m.verify(self.pack())
        self.assertEqual(result["local_dependencies_checked"], 10)
        self.assertEqual(result["external_references_skipped"], 3)

    def test_empty_resource_attributes_are_rejected(self):
        for element in ('<script src=""></script>', '<link rel=stylesheet href>', '<img src="">'):
            with self.subTest(element=element):
                self.set_html(element)
                with self.assertRaisesRegex(ValueError, "empty game resource URL"):
                    m.verify(self.pack())

    def test_query_or_fragment_only_script_resolves_to_html_and_is_rejected(self):
        for url in ("?version=2", "#inline-is-not-an-external-script"):
            with self.subTest(url=url):
                self.set_html('<script src="' + url + '"></script>')
                with self.assertRaisesRegex(ValueError, "HTML payload instead of game script"):
                    m.verify(self.pack())

    def test_empty_and_html_fallback_resource_payloads_are_rejected(self):
        for tag, path in (('<script src=/asset.js></script>', "asset.js"),
                          ('<link rel=stylesheet href=/asset.css>', "asset.css"),
                          ('<img src=/asset.png>', "asset.png")):
            for payload in (b"", b"  \n\t", b"<!doctype html><html>Not found</html>",
                            b"\xef\xbb\xbf" + b" " * 9000 + b"<!-- CDN fallback -->\n<html></html>"):
                with self.subTest(path=path, payload_length=len(payload)):
                    self.set_html(tag)
                    self.files[path] = payload
                    with self.assertRaisesRegex(ValueError, "empty game dependency|HTML payload instead"):
                        m.verify(self.pack())

    def test_text_resources_must_be_utf8_without_binary_nuls(self):
        for payload in (b"\xff\xfe\x00", b"console.log(1)\x00"):
            with self.subTest(payload=payload):
                self.files["games/zion-9/queue/ZION-020/local.js"] = payload
                with self.assertRaises((ValueError, UnicodeError)):
                    m.verify(self.pack())

    def test_js_containing_html_strings_remains_valid(self):
        self.files["games/zion-9/queue/ZION-020/local.js"] = b'const template = "<html></html>";'
        self.assertEqual(m.verify(self.pack())["status"], "verified")

    def test_other_markup_is_not_accepted_as_javascript(self):
        self.files["games/zion-9/queue/ZION-020/local.js"] = b'<?xml version="1.0"?><svg/>'
        with self.assertRaisesRegex(ValueError, "markup payload instead of game script"):
            m.verify(self.pack())

    def test_recursive_css_uses_stylesheet_directory_and_terminates_cycles(self):
        self.set_html('<script src=local.js></script><link rel=stylesheet href=/styles/main.css>')
        self.files["styles/main.css"] = b'@import "nested/theme.css"; .hero{background:url(../images/cover.svg?v=1#art)}'
        self.files["styles/nested/theme.css"] = b'@import url(../main.css); @font-face{src:url(../../fonts/game.woff2)}'
        self.files["images/cover.svg"] = b'<svg xmlns="http://www.w3.org/2000/svg"/>'
        self.files["fonts/game.woff2"] = b"wOF2" + b"\x00" * 48
        result = m.verify(self.pack())
        self.assertEqual(result["css_files_checked"], 2)
        self.assertEqual(result["local_dependencies_checked"], 16)
        self.assertEqual(result["asset_files_checked"], 15)

    def test_missing_transitive_css_asset_blocks_release(self):
        self.set_html('<link rel=stylesheet href=/styles/main.css>')
        self.files["styles/main.css"] = b'@import "nested/theme.css";'
        self.files["styles/nested/theme.css"] = b'.hero{background:url(../../images/missing.svg)}'
        with self.assertRaisesRegex(ValueError, r"styles/nested/theme.css: missing dependency images/missing.svg"):
            m.verify(self.pack())

    def test_missing_css_import_without_url_function_blocks_release(self):
        self.set_html('<style>@import "/missing.css" screen;</style>')
        with self.assertRaisesRegex(ValueError, "missing dependency missing.css"):
            m.verify(self.pack())

    def test_css_comments_strings_fragments_and_inline_data_are_not_files(self):
        self.set_html('''<style>
            /* @import "missing.css"; url(missing.png) */
            .copy::before{content:"url(missing-string.png)"}
            .mask{filter:url(#local-mask);background:url("data:image/svg+xml,%3Csvg/%3E")}
            @import url(https://example.invalid/fonts.css);
            </style><script src=local.js></script>''')
        result = m.verify(self.pack())
        self.assertEqual(result["local_dependencies_checked"], 11)
        self.assertEqual(result["embedded_references_skipped"], 2)
        self.assertEqual(result["external_references_skipped"], 1)

    def test_css_escapes_quoted_urls_and_inline_style_dependencies(self):
        self.set_html(r'''<style>@im\70 ort "/styles/theme.css";</style>
            <div style="background: u\72l('/images/cover\20 one.svg')"></div>''')
        self.files["styles/theme.css"] = b"body{color:green}"
        self.files["images/cover one.svg"] = b'<svg xmlns="http://www.w3.org/2000/svg"/>'
        result = m.verify(self.pack())
        self.assertEqual(result["css_files_checked"], 1)
        self.assertEqual(result["local_dependencies_checked"], 12)

    def test_srcset_candidates_with_data_url_and_fallback_are_checked(self):
        self.set_html('''<picture><source srcset="data:image/svg+xml,%3Csvg/%3E 1x, /images/large.svg 2x">
            <img src=/images/small.svg></picture>''')
        self.files["images/small.svg"] = b'<svg xmlns="http://www.w3.org/2000/svg"/>'
        with self.assertRaisesRegex(ValueError, "missing dependency images/large.svg"):
            m.verify(self.pack())
        self.files["images/large.svg"] = self.files["images/small.svg"]
        result = m.verify(self.pack())
        self.assertEqual(result["local_dependencies_checked"], 12)
        self.assertEqual(result["embedded_references_skipped"], 1)

    def test_image_preload_modulepreload_and_icons_have_typed_checks(self):
        self.set_html('''<link rel=modulepreload href=/module.js>
            <link rel="shortcut icon" href=/icon.svg>
            <link rel=preload as=image imagesrcset="/one.svg 1x, /two.svg 2x">''')
        self.files["module.js"] = b"export const value = 1"
        for name in ("icon.svg", "one.svg", "two.svg"):
            self.files[name] = b'<svg xmlns="http://www.w3.org/2000/svg"/>'
        self.assertEqual(m.verify(self.pack())["local_dependencies_checked"], 14)
        self.files["module.js"] = b"<html>Fallback</html>"
        with self.assertRaisesRegex(ValueError, "HTML payload instead of game script"):
            m.verify(self.pack())

    def test_invalid_svg_and_image_magic_are_rejected(self):
        for path, payload, message in (
            ("image.svg", b"<document/>", "invalid SVG root"),
            ("image.svg", b"<svg>", "invalid SVG dependency"),
            ("image.svg", b'<!DOCTYPE svg [<!ENTITY x "abc">]><svg>&x;</svg>', "DTD/entities"),
            ("image.png", b"not a png", "invalid game asset signature"),
            ("image.webp", b"RIFF0000WAVE", "invalid game asset signature"),
        ):
            with self.subTest(path=path, payload=payload):
                self.set_html('<img src="/' + path + '">')
                self.files[path] = payload
                with self.assertRaisesRegex(ValueError, message):
                    m.verify(self.pack())

    def test_svg_utf16_cannot_bypass_entity_guard(self):
        self.set_html('<img src=/image.svg>')
        self.files["image.svg"] = '<!DOCTYPE svg [<!ENTITY x "abc">]><svg>&x;</svg>'.encode("utf-16-le")
        with self.assertRaisesRegex(ValueError, "SVG dependency must use UTF-8"):
            m.verify(self.pack())

    def test_media_poster_and_svg_external_reference_are_checked(self):
        self.set_html('''<video src=/clip.mp4 poster=/poster.svg><source src=/clip.webm></video>
            <audio src=/sound.ogg></audio><svg><use href=#local/><image href=/poster.svg/></svg>''')
        for name in ("clip.mp4", "clip.webm", "sound.ogg"):
            self.files[name] = b"media-signatures-are-outside-this-contract"
        with self.assertRaisesRegex(ValueError, "missing dependency poster.svg"):
            m.verify(self.pack())

    def test_iframe_document_and_nested_dependencies_are_checked(self):
        self.set_html('<iframe src=/player/><img src=/ignored-fallback.png></iframe>')
        self.files["player/index.html"] = b'<html><script src=loader.js></script></html>'
        with self.assertRaisesRegex(ValueError, "missing dependency player/loader.js"):
            m.verify(self.pack())
        self.files["player/loader.js"] = b"console.log('loader')"
        result = m.verify(self.pack())
        self.assertEqual(result["html_files_checked"], 23)
        self.assertEqual(result["local_dependencies_checked"], 12)

    def test_about_blank_iframe_is_an_embedded_document(self):
        self.set_html('<iframe src="about:blank"></iframe><script src=local.js></script>')
        result = m.verify(self.pack())
        self.assertEqual(result["embedded_references_skipped"], 1)
        self.assertEqual(result["local_dependencies_checked"], 11)
        self.assertEqual(result["asset_files_checked"], 11)
        self.assertEqual(result["html_files_checked"], 22)

    def test_about_scheme_exception_does_not_apply_to_other_resources(self):
        for element in ('<script src="about:blank"></script>',
                        '<link rel=stylesheet href="about:blank">',
                        '<img src="about:blank">',
                        '<style>.hero{background:url(about:blank)}</style>',
                        '<iframe src="about:config"></iframe>'):
            with self.subTest(element=element):
                self.set_html(element)
                with self.assertRaisesRegex(ValueError, "unsupported game resource URL scheme: about"):
                    m.verify(self.pack())

    def test_web_manifest_is_json_object(self):
        self.set_html('<link rel=manifest href=/game.webmanifest>')
        self.files["game.webmanifest"] = b"[]"
        with self.assertRaisesRegex(ValueError, "web manifest dependency must be an object"):
            m.verify(self.pack())

    def test_asset_read_limits_apply_before_decompression(self):
        archive = self.pack()
        name = "games/zion-9/queue/ZION-020/local.js"
        with zipfile.ZipFile(archive) as z:
            with mock.patch.object(z, "open", side_effect=AssertionError("must not decompress")):
                with self.assertRaisesRegex(ValueError, "oversized"):
                    m.bounded_read(z, name, 1)
        self.files[name] = b"x" * 65
        with mock.patch.object(m, "MAX_TEXT_RESOURCE_BYTES", 64):
            with self.assertRaisesRegex(ValueError, "oversized"):
                m.verify(self.pack())

    def test_binary_asset_size_limit(self):
        self.set_html('<img src=/oversized.svg>')
        self.files["oversized.svg"] = b"<svg>" + b" " * 80 + b"</svg>"
        with mock.patch.object(m, "MAX_RESOURCE_BYTES", 64):
            with self.assertRaisesRegex(ValueError, "oversized"):
                m.verify(self.pack())

    def test_global_read_budget_bounds_asset_fanout(self):
        for world in self.worlds:
            self.files[world["route"].lstrip("/").replace("index.html", "local.js")] = b"/*" + b"x" * 4096 + b"*/"
        with mock.patch.object(m, "MAX_TOTAL_READ_BYTES", 8192):
            with self.assertRaisesRegex(ValueError, "read budget exceeded"):
                m.verify(self.pack())

    def test_reference_budget_bounds_css_expansion(self):
        self.set_html('<script src=local.js></script><link rel=stylesheet href=/main.css>')
        self.files["main.css"] = b"body{background:url(/one.svg),url(/two.svg),url(/three.svg)}"
        for name in ("one.svg", "two.svg", "three.svg"):
            self.files[name] = b"<svg/>"
        with mock.patch.object(m, "MAX_RESOURCE_REFERENCES", 13):
            with self.assertRaisesRegex(ValueError, "too many game resource references"):
                m.verify(self.pack())

    def test_report_exposes_scope_and_does_not_claim_runtime_execution(self):
        result = m.verify(self.pack())
        self.assertEqual(result["catalog_entrypoints"], 3)
        self.assertEqual(result["html_files_checked"], 22)
        self.assertEqual(result["dependency_scope"], "declarative_html_and_literal_css")
        self.assertIs(result["runtime_execution_performed"], False)
        self.assertIs(result["publication_performed"], False)
if __name__=="__main__":unittest.main()
