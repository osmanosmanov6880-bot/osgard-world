#!/usr/bin/env python3
"""Run the unchanged owned REMIX QA probe through the runtime's HTTPS proxy.

Usage and opt-in writes are those of remix-owned-live-smoke.py. This launcher
adds no arguments and never enables --exercise-owned itself. It reads stdlib
getproxies()/proxy_bypass(), supports only an HTTP CONNECT proxy, and leaves TLS
certificate and hostname validation to the original HTTPSConnection. An absent
HTTPS proxy or explicit bypass uses the original direct connection. Unsupported
used proxy settings fail before the probe starts; there is no fallback or retry.

Only the loaded probe's http namespace is replaced. No global transport, app,
workflow, timeout, request headers or evidence schema is modified. Proxy URLs and
credentials remain in memory and are never printed or written to the evidence.
"""
from __future__ import annotations

import base64
import http.client
import importlib.util
import ipaddress
import json
from pathlib import Path
import re
import sys
import types
from urllib.parse import unquote, urlsplit
from urllib.request import getproxies, proxy_bypass


TARGET_HOST = "osgard.world"
TARGET_PORT = 443
PROBE_PATH = Path(__file__).resolve().with_name("remix-owned-live-smoke.py")
ORIGINAL_HTTPS_CONNECTION = http.client.HTTPSConnection


class ProxyConfigurationError(Exception):
    """A deliberately generic error that never contains proxy settings."""


class ProxyEndpoint:
    __slots__ = ("host", "port", "authorization")

    def __init__(self, host, port, authorization):
        self.host, self.port, self.authorization = host, port, authorization

    def __repr__(self):
        return "<HTTP CONNECT proxy>"


def parse_proxy(value):
    """Validate the narrow proxy URL syntax needed by this QA launcher."""
    try:
        if (not isinstance(value, str) or not value or len(value) > 8192
                or re.search(r"[\x00-\x20\x7f\\]", value)):
            raise ValueError
        parsed = urlsplit(value)
        if (parsed.scheme.lower() != "http" or not parsed.hostname
                or parsed.path not in ("", "/") or parsed.query or parsed.fragment
                or parsed.netloc.count("@") > 1):
            raise ValueError
        authority = parsed.netloc.rsplit("@", 1)[-1]
        if authority.endswith(":"):
            raise ValueError
        port = parsed.port if parsed.port is not None else 80
        if not 1 <= port <= 65535:
            raise ValueError
        host = parsed.hostname
        if "%" in host:
            raise ValueError
        if authority.startswith("["):
            if not re.fullmatch(r"\[[0-9A-Fa-f:.]+\](?::[0-9]{1,5})?", authority):
                raise ValueError
            host = str(ipaddress.IPv6Address(host))
        else:
            if not re.fullmatch(r"[^:@\[\]]+(?::[0-9]{1,5})?", authority):
                raise ValueError
            host = host.encode("idna").decode("ascii")
            labels = (host[:-1] if host.endswith(".") else host).split(".")
            if len(host) > 254 or any(not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", label) for label in labels):
                raise ValueError
        authorization = None
        if parsed.username is not None:
            if not parsed.username or parsed.password is None:
                raise ValueError
            credentials = (parsed.username, parsed.password)
            if any(re.search(r"%(?![0-9a-fA-F]{2})", part) for part in credentials):
                raise ValueError
            username, password = (unquote(part, encoding="utf-8", errors="strict") for part in credentials)
            if ":" in username or any(re.search(r"[\x00-\x1f\x7f]", part) for part in (username, password)):
                raise ValueError
            authorization = "Basic " + base64.b64encode((username + ":" + password).encode("utf-8")).decode("ascii")
        return ProxyEndpoint(host, port, authorization)
    except (ValueError, UnicodeError):
        raise ProxyConfigurationError("Unsupported runtime HTTPS proxy configuration") from None


def runtime_proxy():
    """Use the HTTPS entry, with stdlib environment precedence and bypass rules."""
    value = getproxies().get("https")
    if not value or proxy_bypass(f"{TARGET_HOST}:{TARGET_PORT}"):
        return None
    return parse_proxy(value)


def connection_factory(proxy):
    """Expose only the fixed origin and the timeout the frozen probe supplies."""
    def connection(host, port=None, *, timeout):
        if host != TARGET_HOST or (port is not None and (type(port) is not int or port != TARGET_PORT)):
            raise ProxyConfigurationError("The QA transport only supports its fixed HTTPS origin")
        target_host, target_port = (proxy.host, proxy.port) if proxy else (TARGET_HOST, TARGET_PORT)
        transport = ORIGINAL_HTTPS_CONNECTION(target_host, target_port, timeout=timeout)
        try:
            # Prevent stdlib's optional debug output from exposing either kind
            # of credentials, even if another module changed its class default.
            transport.set_debuglevel(0)
            if proxy:
                headers = {"Proxy-Authorization": proxy.authorization} if proxy.authorization else {}
                transport.set_tunnel(TARGET_HOST, TARGET_PORT, headers=headers)
            return transport
        except BaseException:
            transport.close()
            raise
    return connection


def load_probe():
    # This path is fixed beside the launcher; there is no user-supplied source,
    # alternate target, or copied version of the probe.
    spec = importlib.util.spec_from_file_location("_osgard_owned_probe_runtime_proxy", PROBE_PATH)
    probe = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(probe)
    return probe


def main():
    try:
        proxy = runtime_proxy()  # Validate before any probe request or write.
        probe = load_probe()
        probe.http = types.SimpleNamespace(client=types.SimpleNamespace(HTTPSConnection=connection_factory(proxy)))
    except Exception as error:
        print(json.dumps({"status": "FAIL", "phase": "runtime-proxy-setup",
                          "errorType": type(error).__name__, "requests": 0}), file=sys.stderr)
        return 2
    # Preserve the original CLI, request journal, alarms, cleanup and exit code.
    return probe.main()


if __name__ == "__main__":
    sys.exit(main())
