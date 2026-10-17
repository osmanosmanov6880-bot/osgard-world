"""Offline checks of the QA-only CONNECT adapter and the unchanged live probe.

The wire fixture runs the real HTTPSConnection/CONNECT implementation against
in-memory sockets. TLS wrapping is intercepted only to inspect the real default
context and SNI; no TLS handshake, DNS, socket connection or server is used.
"""
import base64
import contextlib
import http.client
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import socket
import ssl
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("runtime_remix_proxy", ROOT / "scripts/with-remix-runtime-proxy.py")
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)
PROXY_URL = "http://qa%40proxy:private%3Apassword@proxy.test:8080"
PROXY_AUTH = "Basic " + base64.b64encode(b"qa@proxy:private:password").decode("ascii")
SECRETS = (PROXY_URL, "qa@proxy", "private:password", PROXY_AUTH)
RELEASE = "123456789abc"


def http_reply(payload, status=200, content_type="application/json"):
    body = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
    return (f"HTTP/1.1 {status} Fixture\r\nContent-Type: {content_type}\r\n"
            f"Cache-Control: no-store\r\nContent-Length: {len(body)}\r\n\r\n").encode() + body


def release_reply():
    return http_reply(f'<script src="/brand/osa-transition.js?v={RELEASE}"></script>'.encode(), content_type="text/html")


def capability_reply():
    return http_reply({"authPolicyVersion": 1, "provider": "core",
                       "ownershipPolicy": "confirmed-durable-binding", "creationEnabled": True})


class MemorySocket:
    def __init__(self, reply, tunnel_reply):
        self.reply, self.tunnel_reply = reply, tunnel_reply
        self.tls = False
        self.sent = []
        self.closed = False

    def sendall(self, data):
        self.sent.append((self.tls, bytes(data)))

    def makefile(self, mode):
        return io.BytesIO(self.reply if self.tls else self.tunnel_reply)

    def setsockopt(self, *args):
        pass

    def close(self):
        self.closed = True


class Wire:
    """Capture separate proxy plaintext and origin TLS-bound request bytes."""
    def __init__(self, replies=(), tunnel_reply=b"HTTP/1.1 200 Connection established\r\n\r\n"):
        self.replies = list(replies)
        self.tunnel_reply = tunnel_reply
        self.connections = []
        self.tls = []
        self.sockets = []

    def connect(self, address, timeout, source_address):
        self.connections.append((address, timeout, source_address))
        reply = self.replies.pop(0) if self.replies else http_reply({})
        sock = MemorySocket(reply, self.tunnel_reply)
        self.sockets.append(sock)
        return sock

    def wrap(self, context, sock, *, server_hostname):
        self.tls.append((server_hostname, context.check_hostname, context.verify_mode))
        sock.tls = True
        return sock

    @contextlib.contextmanager
    def installed(self):
        wire = self
        def wrap(context, sock, *, server_hostname):
            return wire.wrap(context, sock, server_hostname=server_hostname)
        with patch.object(socket, "create_connection", self.connect), patch.object(ssl.SSLContext, "wrap_socket", wrap):
            yield self

    def data(self, tls):
        return b"".join(data for sock in self.sockets for encrypted, data in sock.sent if encrypted is tls)


class NoNetworkTests(unittest.TestCase):
    def setUp(self):
        for target, name in ((socket, "create_connection"), (socket, "getaddrinfo"),
                             (socket.socket, "connect"), (socket.socket, "connect_ex")):
            blocker = patch.object(target, name, side_effect=AssertionError("Real network is forbidden"))
            blocker.start()
            self.addCleanup(blocker.stop)


class ProxySettingsTests(NoNetworkTests):
    def test_stdlib_lowercase_https_setting_wins(self):
        with patch.dict(os.environ, {"HTTPS_PROXY": "http://upper.test:8123", "https_proxy": "http://lower.test:8124"}, clear=True):
            proxy = mod.runtime_proxy()
        self.assertEqual((proxy.host, proxy.port), ("lower.test", 8124))

    def test_stdlib_no_proxy_rules_include_fixed_port(self):
        for bypass in ("osgard.world", ".osgard.world", "osgard.world:443", "*"):
            with self.subTest(bypass=bypass), patch.dict(os.environ, {"https_proxy": PROXY_URL, "no_proxy": bypass}, clear=True):
                self.assertIsNone(mod.runtime_proxy())
        with patch.dict(os.environ, {"https_proxy": PROXY_URL, "no_proxy": "other.test,osgard.world:444"}, clear=True):
            self.assertIsNotNone(mod.runtime_proxy())

    def test_no_https_proxy_does_not_fall_back_to_http_or_all(self):
        for env in ({}, {"http_proxy": PROXY_URL, "all_proxy": PROXY_URL},
                    {"HTTPS_PROXY": PROXY_URL, "https_proxy": ""}):
            with self.subTest(keys=sorted(env)), patch.dict(os.environ, env, clear=True):
                self.assertIsNone(mod.runtime_proxy())

    def test_explicit_bypass_does_not_parse_unused_proxy(self):
        with patch.dict(os.environ, {"https_proxy": "unsupported://private.invalid", "no_proxy": "osgard.world"}, clear=True):
            self.assertIsNone(mod.runtime_proxy())

    def test_http_proxy_ports_and_ipv6(self):
        for value, expected in (("http://proxy.test", ("proxy.test", 80)),
                                ("HTTP://proxy.test:8080/", ("proxy.test", 8080)),
                                ("http://[::1]:8080", ("::1", 8080))):
            with self.subTest(expected=expected):
                proxy = mod.parse_proxy(value)
                self.assertEqual((proxy.host, proxy.port), expected)
                self.assertIsNone(proxy.authorization)

    def test_percent_decoded_basic_credentials_and_safe_repr(self):
        proxy = mod.parse_proxy(PROXY_URL)
        self.assertEqual(proxy.authorization, PROXY_AUTH)
        self.assertEqual(repr(proxy), "<HTTP CONNECT proxy>")
        self.assertTrue(all(value not in repr(proxy) for value in SECRETS))

    def test_invalid_used_proxy_syntax_is_rejected_without_value_in_error(self):
        invalid = ("https://user:secret@proxy.test", "socks5://proxy.test", "proxy.test:8080", "//proxy.test",
                   "http://", "http://proxy.test:0", "http://proxy.test:65536", "http://proxy.test:bad",
                   "http://proxy.test:", "http://proxy.test/path", "http://proxy.test/?private=query",
                   "http://proxy.test/#private", "http://a..test", "http://-bad.test", "http://[::1",
                   "http://[v1.proxy]", "http://[::1]suffix", "http://[::1]suffix:80",
                   "http://proxy%0a.test", "http://proxy.test\r\nInjected:value",
                   "http://proxy.test\\other", "http://user@proxy.test", "http://:password@proxy.test",
                   "http://u%3Aname:password@proxy.test", "http://u:pass%0Dword@proxy.test",
                   "http://u:pass%0Aword@proxy.test", "http://u:pass%GG@proxy.test", "http://u:pass%FF@proxy.test",
                   "http://user@name:password@proxy.test", None, "x" * 8193)
        for index, value in enumerate(invalid):
            with self.subTest(index=index), self.assertRaises(mod.ProxyConfigurationError) as raised:
                mod.parse_proxy(value)
            self.assertEqual(str(raised.exception), "Unsupported runtime HTTPS proxy configuration")


class ConnectionTests(NoNetworkTests):
    def test_target_aliases_ports_and_custom_tls_context_are_rejected_before_connect(self):
        factory = mod.connection_factory(mod.parse_proxy(PROXY_URL))
        with patch.object(mod, "ORIGINAL_HTTPS_CONNECTION") as original:
            for host, port in (("other.test", None), ("osgard.world:443", None), ("OSGARD.WORLD", None),
                               ("osgard.world.", None), ("osgard.world", 80), ("osgard.world", "443"),
                               ("osgard.world", True)):
                with self.subTest(host=host, port=port), self.assertRaises(mod.ProxyConfigurationError):
                    factory(host, port, timeout=4)
            with self.assertRaises(TypeError):
                factory("osgard.world", timeout=4, context=ssl._create_unverified_context())
            original.assert_not_called()

    def test_real_connect_separates_proxy_and_origin_credentials_and_keeps_tls_validation(self):
        wire = Wire()
        stdout = io.StringIO()
        with wire.installed(), patch.object(http.client.HTTPConnection, "debuglevel", 1), contextlib.redirect_stdout(stdout):
            connection = mod.connection_factory(mod.parse_proxy(PROXY_URL))("osgard.world", timeout=7.25)
            self.assertIsInstance(connection, mod.ORIGINAL_HTTPS_CONNECTION)
            connection.request("POST", "/api/core/auth/logout", body=b"{}", headers={"Authorization": "Bearer origin-only-secret"})
            connection.close()
        self.assertEqual(wire.connections, [(("proxy.test", 8080), 7.25, None)])
        self.assertEqual(wire.tls, [("osgard.world", True, ssl.CERT_REQUIRED)])
        connect, origin = wire.data(False), wire.data(True)
        self.assertTrue(connect.startswith(b"CONNECT osgard.world:443 HTTP/"))
        self.assertIn(("Proxy-Authorization: " + PROXY_AUTH + "\r\n").encode(), connect)
        self.assertNotIn(b"origin-only-secret", connect)
        self.assertIn(b"POST /api/core/auth/logout HTTP/", origin)
        self.assertIn(b"Host: osgard.world\r\n", origin)
        self.assertIn(b"Authorization: Bearer origin-only-secret\r\n", origin)
        self.assertNotIn(b"Proxy-Authorization", origin)
        self.assertNotIn(b"proxy.test", origin)
        self.assertTrue(all(value.encode() not in origin for value in SECRETS))
        self.assertEqual(stdout.getvalue(), "")
        self.assertTrue(wire.sockets[0].closed)

    def test_proxy_without_credentials_sends_no_proxy_authorization(self):
        wire = Wire()
        with wire.installed():
            connection = mod.connection_factory(mod.parse_proxy("http://proxy.test"))("osgard.world", 443, timeout=3)
            connection.request("GET", "/")
            connection.close()
        self.assertNotIn(b"Proxy-Authorization", wire.data(False) + wire.data(True))
        self.assertEqual(wire.connections[0][0], ("proxy.test", 80))

    def test_direct_transport_is_original_validating_https_without_connect(self):
        wire = Wire()
        with wire.installed():
            connection = mod.connection_factory(None)("osgard.world", timeout=2.75)
            self.assertIsInstance(connection, mod.ORIGINAL_HTTPS_CONNECTION)
            connection.request("GET", "/api/remix/v2/capabilities")
            connection.close()
        self.assertEqual(wire.connections, [(("osgard.world", 443), 2.75, None)])
        self.assertEqual(wire.data(False), b"")
        self.assertEqual(wire.tls, [("osgard.world", True, ssl.CERT_REQUIRED)])

    def test_failed_tunnel_never_sends_origin_post_or_falls_back(self):
        for status in (407, 302, 503):
            with self.subTest(status=status):
                wire = Wire(tunnel_reply=f"HTTP/1.1 {status} Stop\r\n\r\n".encode())
                with wire.installed():
                    connection = mod.connection_factory(mod.parse_proxy(PROXY_URL))("osgard.world", timeout=4)
                    try:
                        with self.assertRaises(OSError):
                            connection.request("POST", "/api/core/auth/register", body=b"private body")
                    finally:
                        connection.close()
                self.assertEqual(len(wire.connections), 1)
                self.assertEqual(wire.tls, [])
                self.assertEqual(wire.data(True), b"")
                self.assertNotIn(b"private body", wire.data(False))

    def test_tunnel_setup_failure_closes_the_single_transport(self):
        transport = Mock()
        transport.set_tunnel.side_effect = ValueError("private settings must not be reported")
        with patch.object(mod, "ORIGINAL_HTTPS_CONNECTION", return_value=transport) as original:
            with self.assertRaises(ValueError):
                mod.connection_factory(mod.parse_proxy(PROXY_URL))("osgard.world", timeout=3)
        original.assert_called_once_with("proxy.test", 8080, timeout=3)
        transport.close.assert_called_once_with()


class LauncherTests(NoNetworkTests):
    def run_probe(self, wire, args=()):
        with tempfile.TemporaryDirectory(prefix="runtime-proxy-test-") as directory:
            output = Path(directory) / "report.json"
            argv = ["with-remix-runtime-proxy.py", "--expected-release", RELEASE, "--output", str(output), *args]
            stdout, stderr = io.StringIO(), io.StringIO()
            with wire.installed(), patch.object(mod, "getproxies", return_value={"https": PROXY_URL}), \
                    patch.object(mod, "proxy_bypass", return_value=False), patch.object(sys, "argv", argv), \
                    contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                result = mod.main()
            raw = output.read_text()
        for value in SECRETS:
            self.assertNotIn(value, raw + stdout.getvalue() + stderr.getvalue())
        return result, json.loads(raw), stdout.getvalue(), stderr.getvalue()

    def test_same_probe_readonly_cli_performs_exactly_three_gets(self):
        wire = Wire([release_reply(), capability_reply(), release_reply()])
        result, report, stdout, stderr = self.run_probe(wire)
        self.assertEqual((result, report["status"], report["mode"]), (0, "PASS", "read-only"))
        self.assertEqual([(row["method"], row["path"]) for row in report["requests"]],
                         [("GET", "/"), ("GET", "/api/remix/v2/capabilities"), ("GET", "/")])
        self.assertEqual(len(report["checks"]), 2)
        self.assertEqual(len(wire.connections), 3)
        self.assertNotIn(b"POST ", wire.data(True))
        self.assertTrue(all(item[0] == ("proxy.test", 8080) for item in wire.connections))
        self.assertEqual(stderr, "")
        self.assertEqual(json.loads(stdout)["status"], "PASS")

    def test_origin_redirect_is_reported_without_follow_or_retry(self):
        wire = Wire([http_reply(b"redirect", status=302, content_type="text/html")])
        result, report, stdout, stderr = self.run_probe(wire)
        self.assertEqual((result, report["status"], len(report["requests"])), (1, "FAIL", 1))
        self.assertEqual(len(wire.connections), 1)
        self.assertNotIn(b"POST ", wire.data(True))

    def test_proxy_failure_is_sanitized_by_original_probe_report(self):
        wire = Wire(tunnel_reply=("HTTP/1.1 407 " + PROXY_URL + "\r\nProxy-Authenticate: " + PROXY_AUTH + "\r\n\r\n").encode())
        result, report, stdout, stderr = self.run_probe(wire, ("--exercise-owned",))
        self.assertEqual((result, report["status"], len(report["requests"])), (1, "FAIL", 1))
        self.assertEqual(report["failure"], "Transport or parsing failure: OSError")
        self.assertEqual(report["requests"][0]["outcome"], "failed")
        self.assertEqual(len(wire.connections), 1)
        self.assertEqual(wire.data(True), b"")

    def test_invalid_proxy_stops_before_loading_probe_or_writing_output(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with tempfile.TemporaryDirectory(prefix="runtime-proxy-invalid-") as directory:
            output = Path(directory) / "never-created.json"
            with patch.object(mod, "getproxies", return_value={"https": "https://secret:password@private.test"}), \
                    patch.object(mod, "proxy_bypass", return_value=False), patch.object(mod, "load_probe") as loader, \
                    patch.object(sys, "argv", ["launcher", "--exercise-owned", "--output", str(output)]), \
                    contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                self.assertEqual(mod.main(), 2)
            loader.assert_not_called()
            self.assertFalse(output.exists())
        self.assertEqual(stdout.getvalue(), "")
        self.assertEqual(json.loads(stderr.getvalue()), {"status": "FAIL", "phase": "runtime-proxy-setup",
                                                       "errorType": "ProxyConfigurationError", "requests": 0})
        self.assertNotIn("secret", stderr.getvalue())
        self.assertNotIn("private.test", stderr.getvalue())

    def test_only_loaded_probe_namespace_changes_and_arguments_exit_code_are_preserved(self):
        original = http.client.HTTPSConnection
        argv = ["launcher", "--exercise-owned", "--expected-release", RELEASE, "--output", "unused.json"]
        observed = []
        probe = types.SimpleNamespace(http=http)
        def main():
            observed.append(sys.argv)
            self.assertIsNot(probe.http, http)
            self.assertIs(http.client.HTTPSConnection, original)
            return 7
        probe.main = main
        with patch.object(mod, "getproxies", return_value={}), patch.object(mod, "load_probe", return_value=probe), patch.object(sys, "argv", argv):
            self.assertEqual(mod.main(), 7)
        self.assertEqual(len(observed), 1)
        self.assertIs(observed[0], argv)
        self.assertIs(http.client.HTTPSConnection, original)
        self.assertIs(mod.ORIGINAL_HTTPS_CONNECTION, original)

    def test_fixed_sibling_source_and_original_parser_reject_alternate_source(self):
        probe = mod.load_probe()
        self.assertEqual(Path(probe.main.__code__.co_filename).resolve(), ROOT / "scripts/remix-owned-live-smoke.py")
        stderr = io.StringIO()
        with patch.object(mod, "getproxies", return_value={}), patch.object(mod, "ORIGINAL_HTTPS_CONNECTION") as original, \
                patch.object(sys, "argv", ["launcher", "--source", "other.py"]), contextlib.redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as raised:
                mod.main()
        self.assertEqual(raised.exception.code, 2)
        original.assert_not_called()

    @unittest.skipUnless(hasattr(signal, "setitimer") and hasattr(signal, "SIGALRM"), "The original probe requires POSIX alarms")
    def test_original_whole_request_alarm_interrupts_proxy_construction_without_retry(self):
        previous_handler = signal.getsignal(signal.SIGALRM)
        previous_timer = signal.setitimer(signal.ITIMER_REAL, 0)
        started = time.monotonic()
        try:
            probe_module = mod.load_probe()
            timeout_function = probe_module.request_timeout
            probe_module.http = types.SimpleNamespace(client=types.SimpleNamespace(HTTPSConnection=mod.connection_factory(mod.parse_proxy(PROXY_URL))))
            probe = probe_module.Probe(True, "")
            probe.deadline = time.monotonic() + .04
            calls = []
            def slow_connection(host, port, *, timeout):
                calls.append((host, port, timeout, signal.getitimer(signal.ITIMER_REAL)[0]))
                time.sleep(.3)
                raise AssertionError("The original alarm did not interrupt construction")
            with patch.object(mod, "ORIGINAL_HTTPS_CONNECTION", side_effect=slow_connection):
                with self.assertRaises(probe_module.ProbeFailure):
                    probe.request("POST", "/api/remix/v2/matches", body={"challengeId": "qa", "maxPlayers": 2})
            self.assertIs(probe_module.request_timeout, timeout_function)
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0][:2], ("proxy.test", 8080))
            self.assertGreater(calls[0][2], 0)
            self.assertLessEqual(calls[0][2], .04)
            self.assertGreater(calls[0][3], 0)
            self.assertEqual([(row["method"], row["outcome"]) for row in probe.report["requests"]], [("POST", "uncertain")])
            self.assertEqual(signal.getitimer(signal.ITIMER_REAL), (0.0, 0.0))
            self.assertIs(signal.getsignal(signal.SIGALRM), previous_handler)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous_handler)
            if previous_timer[0]:
                signal.setitimer(signal.ITIMER_REAL, max(.000001, previous_timer[0] - (time.monotonic() - started)), previous_timer[1])


if __name__ == "__main__":
    unittest.main()
