#!/usr/bin/env python3
"""Offline ZIP contract for 11 ZION worlds, 8 legacy games and their static resources.

This is a bounded archive/content check, not a JavaScript interpreter or a browser.
Only declarative HTML resources and literal CSS url()/@import dependencies are
followed. Network URLs are reported as skipped and are never fetched.
"""
import argparse
from collections import deque
from html.parser import HTMLParser
import json
import re
import sys
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET
import zipfile


MAX_GAME_HTML_BYTES = 8 * 1024 * 1024
MAX_WORLD_MANIFEST_BYTES = 256 * 1024
MAX_TEXT_RESOURCE_BYTES = 8 * 1024 * 1024
MAX_RESOURCE_BYTES = 32 * 1024 * 1024
MAX_TOTAL_READ_BYTES = 128 * 1024 * 1024
MAX_RESOURCE_REFERENCES = 20000
ZION_PREFIX = "games/zion-9/queue/"
ZION_IDS = tuple(f"ZION-{i:03d}" for i in range(20, 31))
LEGACY = ("afterimage-run", "empire-orbit", "inherit", "null-shift", "remix",
          "swarm", "time-empire", "vector-zero")
CATALOGS = ("index.html", "games/index.html", "play/index.html")
SPACE = " \t\r\n\f"
JS_TYPES = {"", "module", "text/javascript", "application/javascript",
            "application/ecmascript", "text/ecmascript", "application/x-javascript",
            "text/x-javascript", "text/jscript", "text/livescript",
            "text/javascript1.0", "text/javascript1.1", "text/javascript1.2",
            "text/javascript1.3", "text/javascript1.4", "text/javascript1.5"}
PRELOAD_TYPES = {"script": "script", "style": "css", "image": "image",
                 "font": "asset", "fetch": "asset", "audio": "asset",
                 "video": "asset", "track": "asset", "document": "document"}
HTML_PAYLOAD = re.compile(
    br"<(?:!doctype\s+html\b|/?(?:html|head|body|title|meta|link|script|style|"
    br"div|main|section|h[1-6]|p|pre|span|table|form)\b)", re.I)


def bounded_read(z, name, limit):
    info = z.getinfo(name)
    if info.file_size > limit:
        raise ValueError("oversized game archive entry: " + name)
    with z.open(info) as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise ValueError("oversized game archive entry: " + name)
    return data


def resource_url(raw, base, fragment_local=False, allow_empty=False):
    """Return (local|external|embedded, path); decode local URL paths exactly once.

    base is (kind, path), where a local path is relative to the archive root and
    retains a trailing slash for a directory base. Absolute dot segments and
    encoded separators are rejected rather than relying on server rewrites.
    """
    raw = raw.strip(SPACE)
    if not raw and not allow_empty:
        raise ValueError("empty game resource URL")
    if any(ord(char) < 32 or ord(char) == 127 for char in raw):
        raise ValueError("control character in game resource URL")
    if fragment_local and raw.startswith("#"):
        return "embedded", raw
    parsed = urlsplit(raw)
    if parsed.scheme.lower() in ("http", "https") or (not parsed.scheme and parsed.netloc):
        return "external", raw
    if parsed.scheme.lower() in ("data", "blob"):
        return "embedded", raw
    if parsed.scheme:
        raise ValueError("unsupported game resource URL scheme: " + parsed.scheme)
    if base[0] == "external":
        return "external", raw
    if re.search(r"%(?![0-9a-fA-F]{2})", parsed.path):
        raise ValueError("invalid percent escape in game dependency path")
    if re.search(r"%(?:2f|5c)", parsed.path, re.I):
        raise ValueError("encoded separator in game dependency path")
    path = unquote(parsed.path, encoding="utf-8", errors="strict")
    if "\\" in path or any(ord(char) < 32 or ord(char) == 127 for char in path):
        raise ValueError("unsafe game dependency path")
    if not path:
        return "local", base[1]
    if path.startswith("/"):
        if any(part in (".", "..") for part in path.split("/")):
            raise ValueError("unsafe absolute game dependency path")
        chunks = []
    else:
        parent = base[1] if base[1].endswith("/") else base[1].rsplit("/", 1)[0] + "/"
        if "/" not in base[1]:
            parent = ""
        chunks = [part for part in parent.split("/") if part]
    for part in path.split("/"):
        if part == "..":
            if not chunks:
                raise ValueError("dependency escapes root")
            chunks.pop()
        elif part not in ("", "."):
            chunks.append(part)
    target = "/".join(chunks)
    if path.endswith(("/", "/.", "/..")) or path in (".", ".."):
        target += "/" if target else ""
    return "local", target


def srcset_urls(value):
    """Read candidate URLs without splitting commas inside data: URLs.

    All candidates are checked, independently of viewport/DPR selection. Sizes
    and descriptors are not evaluated. This follows the URL/descriptor boundary
    rules of srcset rather than a comma-only split.
    """
    pos = 0
    while pos < len(value):
        while pos < len(value) and value[pos] in SPACE + ",":
            pos += 1
        start = pos
        while pos < len(value) and value[pos] not in SPACE:
            pos += 1
        url = value[start:pos]
        if not url:
            break
        if url.endswith(","):
            yield url.rstrip(",")
            continue
        yield url
        depth = 0
        while pos < len(value):
            char = value[pos]
            pos += 1
            if char == "(":
                depth += 1
            elif char == ")":
                depth = max(0, depth - 1)
            elif char == "," and depth == 0:
                break


def _css_escape(text, pos):
    pos += 1
    if pos == len(text):
        raise ValueError("unfinished CSS escape")
    char = text[pos]
    if char in "\r\n\f":
        end = pos + (2 if text[pos:pos + 2] == "\r\n" else 1)
        return "", end
    if char in "0123456789abcdefABCDEF":
        end = pos
        while end < min(pos + 6, len(text)) and text[end] in "0123456789abcdefABCDEF":
            end += 1
        code = int(text[pos:end], 16)
        decoded = chr(code) if 0 < code <= 0x10ffff and not 0xd800 <= code <= 0xdfff else "\ufffd"
        if end < len(text) and text[end] in SPACE:
            end += 2 if text[end:end + 2] == "\r\n" else 1
        return decoded, end
    return char, pos + 1


def _css_space(text, pos):
    while pos < len(text):
        if text[pos] in SPACE:
            pos += 1
        elif text.startswith("/*", pos):
            end = text.find("*/", pos + 2)
            if end < 0:
                raise ValueError("unterminated CSS comment")
            pos = end + 2
        else:
            break
    return pos


def _css_string(text, pos):
    quote = text[pos]
    chars = []
    pos += 1
    while pos < len(text):
        char = text[pos]
        if char == quote:
            return "".join(chars), pos + 1
        if char == "\\":
            char, pos = _css_escape(text, pos)
            chars.append(char)
        elif char in "\r\n\f":
            raise ValueError("newline in CSS resource string")
        else:
            chars.append(char)
            pos += 1
    raise ValueError("unterminated CSS string")


def _css_name(text, pos):
    chars = []
    while pos < len(text):
        char = text[pos]
        if char == "\\":
            char, pos = _css_escape(text, pos)
            chars.append(char)
        elif char.isalnum() or char in "_-" or ord(char) >= 128:
            chars.append(char)
            pos += 1
        else:
            break
    return "".join(chars), pos


def _css_url(text, pos):
    pos = _css_space(text, pos + 1)  # opening parenthesis
    if pos < len(text) and text[pos] in "\"'":
        value, pos = _css_string(text, pos)
        pos = _css_space(text, pos)
    else:
        chars = []
        while pos < len(text) and text[pos] != ")":
            char = text[pos]
            if char in SPACE:
                pos = _css_space(text, pos)
                break
            if char == "\\":
                char, pos = _css_escape(text, pos)
            elif char in "\"'(":
                raise ValueError("malformed CSS url()")
            else:
                pos += 1
            chars.append(char)
        value = "".join(chars)
    if pos >= len(text) or text[pos] != ")":
        raise ValueError("malformed CSS url()")
    return value, pos + 1


def css_references(text):
    """Yield (kind, URL, fragment_local) for literal CSS dependencies.

    A small lexical scanner avoids matching comments/content strings and handles
    CSS escapes. It is intentionally not a CSS grammar, JS or image-set parser.
    """
    pos = 0
    importing = False
    while pos < len(text):
        pos = _css_space(text, pos)
        if pos == len(text):
            break
        char = text[pos]
        if char in "\"'":
            value, pos = _css_string(text, pos)
            if importing:
                yield "css", value, False
            importing = False
        elif char == "@":
            name, pos = _css_name(text, pos + 1)
            importing = name.lower() == "import"
        elif char.isalpha() or char in "_-\\" or ord(char) >= 128:
            name, pos = _css_name(text, pos)
            opening = _css_space(text, pos)
            if name.lower() == "url" and opening < len(text) and text[opening] == "(":
                value, pos = _css_url(text, opening)
                if value:  # empty url() has no external resource
                    yield "css" if importing else "asset", value, not importing
            importing = False
        else:
            importing = False
            pos += 1


class GameHTMLParser(HTMLParser):
    """Declarative resources in active HTML with scripting enabled."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.opened_html = False
        self.closed_html = False
        self.base_href = None
        self.references = []
        self.styles = []
        self._style = None
        self._inert = []
        self._raw_text = None

    def reference(self, kind, raw, fragment_local=False):
        if len(self.references) >= MAX_RESOURCE_REFERENCES:
            raise ValueError("too many game resource references")
        self.references.append((kind, raw or "", fragment_local))

    def handle_starttag(self, tag, attrs):
        if self._raw_text:
            return
        if self._inert:
            if tag in ("template", "noscript"):
                self._inert.append(tag)
            return
        if tag in ("template", "noscript"):
            self._inert.append(tag)
            return
        # Browsers use the first duplicate attribute, not the last one.
        attr = {}
        for key, value in attrs:
            attr.setdefault(key, value)
        if tag == "html":
            self.opened_html = True
        if tag == "base" and "href" in attr and self.base_href is None:
            self.base_href = attr["href"] or ""
        if attr.get("style"):
            self.styles.append(attr["style"])
        mime = (attr.get("type") or "").strip().lower().split(";", 1)[0]
        if tag == "style" and mime in ("", "text/css"):
            self._style = []
        elif tag == "script" and mime in JS_TYPES and "src" in attr:
            self.reference("script", attr["src"])
        elif tag == "link":
            rel = set((attr.get("rel") or "").lower().split())
            kind = None
            if "stylesheet" in rel and mime in ("", "text/css"):
                kind = "css"
            elif "modulepreload" in rel:
                kind = "script"
            elif rel & {"icon", "apple-touch-icon", "apple-touch-icon-precomposed", "mask-icon"}:
                kind = "image"
            elif "manifest" in rel:
                kind = "manifest"
            elif "preload" in rel:
                kind = PRELOAD_TYPES.get((attr.get("as") or "").lower())
            elif "prefetch" in rel:
                kind = PRELOAD_TYPES.get((attr.get("as") or "").lower(), "asset")
                if kind == "asset" and urlsplit(attr.get("href") or "").path.lower().endswith((".html", ".htm")):
                    kind = "document"
            if kind and "href" in attr:
                self.reference(kind, attr["href"])
            if kind == "image" and attr.get("imagesrcset"):
                for raw in srcset_urls(attr["imagesrcset"]):
                    self.reference("image", raw)
        elif tag in ("img", "source"):
            if "src" in attr:
                self.reference("image" if tag == "img" else "asset", attr["src"])
            if attr.get("srcset"):
                for raw in srcset_urls(attr["srcset"]):
                    self.reference("image", raw)
        elif tag in ("video", "audio", "track"):
            if "src" in attr:
                self.reference("asset", attr["src"])
            if tag == "video" and "poster" in attr:
                self.reference("image", attr["poster"])
        elif tag == "input" and mime == "image" and "src" in attr:
            self.reference("image", attr["src"])
        elif tag in ("image", "use", "feimage"):
            raw = attr.get("href", attr.get("xlink:href"))
            if raw is not None:
                self.reference("image", raw, True)
        elif tag == "iframe":
            if "src" in attr and "srcdoc" not in attr:
                self.reference("document", attr["src"])
        elif tag in ("object", "embed"):
            key = "data" if tag == "object" else "src"
            if key in attr:
                raw = attr[key] or ""
                document = mime in ("text/html", "application/xhtml+xml") or urlsplit(raw).path.lower().endswith((".html", ".htm"))
                self.reference("document" if document else "asset", raw)
        if tag in ("title", "textarea", "xmp", "iframe"):
            self._raw_text = tag

    def handle_endtag(self, tag):
        if self._raw_text:
            if tag == self._raw_text:
                self._raw_text = None
            return
        if self._inert:
            if tag == self._inert[-1]:
                self._inert.pop()
            return
        if tag == "html":
            self.closed_html = True
        if tag == "style" and self._style is not None:
            self.styles.append("".join(self._style))
            self._style = None

    def handle_data(self, data):
        if self._style is not None and not self._inert:
            self._style.append(data)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        self.handle_endtag(tag)


def html_payload(data):
    # Check the entire bounded payload, including long padding/comments. Keep an
    # offset so many leading comments cannot produce quadratic string copies.
    pos = 3 if data.startswith(b"\xef\xbb\xbf") else 0
    while pos < len(data):
        while pos < len(data) and data[pos] in b" \t\r\n\f":
            pos += 1
        if not data.startswith(b"<!--", pos):
            break
        end = data.find(b"-->", pos + 4)
        if end < 0:
            return False
        pos = end + 3
    return bool(HTML_PAYLOAD.match(data, pos))


def check_asset_content(name, data, kind):
    if not data.strip():
        raise ValueError("empty game dependency: " + name)
    if html_payload(data):
        raise ValueError("HTML payload instead of game " + kind + ": " + name)
    suffix = name.rsplit(".", 1)[-1].lower() if "." in name.rsplit("/", 1)[-1] else ""
    if suffix == "svg":
        svg = data.decode("utf-8-sig")
        if "\x00" in svg:
            raise ValueError("SVG dependency must use UTF-8: " + name)
        if re.search(r"<!\s*(?:DOCTYPE|ENTITY)\b", svg, re.I):
            raise ValueError("SVG DTD/entities are unsupported: " + name)
        try:
            root = ET.fromstring(svg)
        except ET.ParseError as exc:
            raise ValueError("invalid SVG dependency: " + name) from exc
        if root.tag not in ("svg", "{http://www.w3.org/2000/svg}svg"):
            raise ValueError("invalid SVG root: " + name)
    signatures = {
        "png": (b"\x89PNG\r\n\x1a\n",), "apng": (b"\x89PNG\r\n\x1a\n",),
        "jpg": (b"\xff\xd8\xff",), "jpeg": (b"\xff\xd8\xff",),
        "gif": (b"GIF87a", b"GIF89a"), "ico": (b"\x00\x00\x01\x00",),
        "woff": (b"wOFF",), "woff2": (b"wOF2",), "otf": (b"OTTO",),
        "ttf": (b"\x00\x01\x00\x00", b"true", b"typ1"),
        "wasm": (b"\x00asm\x01\x00\x00\x00",),
    }
    if suffix in signatures and not data.startswith(signatures[suffix]):
        raise ValueError("invalid game asset signature: " + name)
    if suffix == "webp" and not (data.startswith(b"RIFF") and data[8:12] == b"WEBP"):
        raise ValueError("invalid game asset signature: " + name)


class ArchiveResources:
    def __init__(self, archive, names):
        self.archive = archive
        self.names = names
        self.pending = deque()
        self.scheduled = set()
        self.asset_files = set()
        self.css_files = set()
        self.html_files = set()
        self.local_count = 0
        self.external_count = 0
        self.embedded_count = 0
        self.reference_count = 0
        self.read_bytes = 0

    def read(self, name, limit):
        size = self.archive.getinfo(name).file_size
        if self.read_bytes + size > MAX_TOTAL_READ_BYTES:
            raise ValueError("game dependency read budget exceeded")
        data = bounded_read(self.archive, name, limit)
        self.read_bytes += len(data)
        return data

    def dependency(self, kind, raw, fragment_local, base, label):
        self.reference_count += 1
        if self.reference_count > MAX_RESOURCE_REFERENCES:
            raise ValueError("too many game resource references")
        # A blank browsing context has no archive file and performs no fetch.
        # Keep this exception typed: about: is not a script/CSS/asset scheme.
        if kind == "document" and raw.strip(SPACE) == "about:blank":
            self.embedded_count += 1
            return
        location, target = resource_url(raw, base, fragment_local)
        if location == "external":
            self.external_count += 1
            return
        if location == "embedded":
            self.embedded_count += 1
            return
        if kind == "document" and (not target or target.endswith("/")):
            target += "index.html"
        if target not in self.names:
            raise ValueError(f"{label}: missing dependency {target}")
        self.local_count += 1
        self.asset_files.add(target)
        key = target, kind
        if key not in self.scheduled:
            self.scheduled.add(key)
            self.pending.append((target, kind, label))

    def html(self, name, label, legacy=False):
        if name in self.html_files:
            return
        self.html_files.add(name)
        source = self.read(name, MAX_GAME_HTML_BYTES).decode("utf-8-sig")
        parser = GameHTMLParser()
        parser.feed(source)
        parser.close()
        if not parser.opened_html or not parser.closed_html:
            prefix = "invalid legacy HTML shell: " if legacy else "invalid HTML shell: "
            raise ValueError(prefix + label)
        base = ("local", name)
        if parser.base_href is not None:
            base = resource_url(parser.base_href, base, allow_empty=True)
            if base[0] == "embedded":
                raise ValueError("unsupported game document base URL: " + name)
        for kind, raw, fragment_local in parser.references:
            self.dependency(kind, raw, fragment_local, base, label)
        for style in parser.styles:
            for kind, raw, fragment_local in css_references(style):
                self.dependency(kind, raw, fragment_local, base, label)

    def finish(self):
        while self.pending:
            name, kind, label = self.pending.popleft()
            if kind == "document":
                self.html(name, label + " -> " + name)
                continue
            limit = MAX_TEXT_RESOURCE_BYTES if kind in ("script", "css") else MAX_RESOURCE_BYTES
            if kind == "manifest":
                limit = MAX_WORLD_MANIFEST_BYTES
            data = self.read(name, limit)
            check_asset_content(name, data, kind)
            if kind in ("script", "css"):
                source = data.decode("utf-8-sig")
                if not source.strip():
                    raise ValueError("empty game dependency: " + name)
                if "\x00" in source:
                    raise ValueError("binary payload instead of game " + kind + ": " + name)
                markup = source.lstrip()
                if markup.startswith("<") and not markup.startswith("<!--"):
                    raise ValueError("markup payload instead of game " + kind + ": " + name)
                if kind == "css":
                    self.css_files.add(name)
                    for child_kind, raw, fragment_local in css_references(source):
                        self.dependency(child_kind, raw, fragment_local, ("local", name), label + " -> " + name)
            elif kind == "manifest":
                if not isinstance(json.loads(data), dict):
                    raise ValueError("web manifest dependency must be an object: " + name)


def verify(archive):
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            path = member.filename
            if (not path or path.startswith("/") or "\\" in path or
                    any(part in ("", ".", "..") for part in path.rstrip("/").split("/"))):
                raise ValueError("unsafe ZIP game archive path: " + path)
            if member.flag_bits & 1:
                raise ValueError("encrypted ZIP game archive entry: " + path)
            mode = (member.external_attr >> 16) & 0o170000
            if mode == 0o120000:
                raise ValueError("ZIP game archive symlink: " + path)
        entries = [x.filename for x in z.infolist() if not x.is_dir()]
        if len(entries) != len(set(entries)):
            raise ValueError("duplicate ZIP game archive member")
        folded = [name.casefold() for name in entries]
        if len(folded) != len(set(folded)):
            raise ValueError("case-colliding ZIP game archive member")
        names = set(entries)
        required = set(CATALOGS) | {"games/zion-9/worlds.json"}
        required.update(f"{ZION_PREFIX}{gid}/index.html" for gid in ZION_IDS)
        required.update(f"games/{name}/index.html" for name in LEGACY)
        missing = sorted(required - names)
        if missing:
            raise ValueError("missing game routes: " + ", ".join(missing[:15]))
        resources = ArchiveResources(z, names)
        manifest = json.loads(resources.read("games/zion-9/worlds.json", MAX_WORLD_MANIFEST_BYTES))
        if not isinstance(manifest, dict):
            raise ValueError("ZION manifest must be an object")
        games = manifest.get("games")
        if not isinstance(games, list) or len(games) != 11:
            raise ValueError("ZION manifest must have 11 worlds")
        ids = set()
        for game in games:
            if not isinstance(game, dict):
                raise ValueError("ZION manifest game must be object")
            gid = game.get("id")
            if not isinstance(gid, str) or gid not in {item.lower() for item in ZION_IDS}:
                raise ValueError("invalid ZION game ID")
            if gid in ids:
                raise ValueError("duplicate ZION game ID")
            ids.add(gid)
            route = game.get("route")
            if route != f"/{ZION_PREFIX}{gid.upper()}/index.html":
                raise ValueError("ZION route/id mismatch")
            resources.html(route.lstrip("/"), gid)
        for name in LEGACY:
            resources.html(f"games/{name}/index.html", "legacy " + name, legacy=True)
        for name in CATALOGS:
            resources.html(name, "catalog " + name)
        resources.finish()
        return {
            "status": "verified", "zion_worlds": 11, "legacy_entrypoints": len(LEGACY),
            "local_dependencies_checked": resources.local_count,
            "publication_performed": False, "catalog_entrypoints": len(CATALOGS),
            "asset_files_checked": len(resources.asset_files),
            "css_files_checked": len(resources.css_files),
            "html_files_checked": len(resources.html_files),
            "external_references_skipped": resources.external_count,
            "embedded_references_skipped": resources.embedded_count,
            "dependency_scope": "declarative_html_and_literal_css",
            "runtime_execution_performed": False,
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip")
    args = parser.parse_args()
    try:
        result = verify(args.zip)
    except (OSError, ValueError, TypeError, KeyError, zipfile.BadZipFile, UnicodeError,
            RuntimeError, NotImplementedError) as exc:
        print("GAME RELEASE BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
