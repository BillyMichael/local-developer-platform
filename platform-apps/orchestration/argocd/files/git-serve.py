#!/usr/bin/env python3
"""Read-only git smart-HTTP server: serves each repo under GIT_ROOT at /<name>
over `git upload-pack`; pushes get 403."""
import gzip
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = os.environ.get("GIT_ROOT", "/repos")
PORT = int(os.environ.get("PORT", "8080"))


def pkt(line: bytes) -> bytes:
    return f"{len(line) + 4:04x}".encode() + line


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def _repo(self, path):
        parts = [p for p in path.split("/") if p]
        if not parts or ".." in parts:
            return None, parts
        repo = os.path.join(ROOT, parts[0])
        if not os.path.isdir(repo):
            return None, parts
        return repo, parts[1:]

    def _env(self):
        env = dict(os.environ, GIT_CONFIG_COUNT="1",
                   GIT_CONFIG_KEY_0="safe.directory", GIT_CONFIG_VALUE_0="*")
        proto = self.headers.get("Git-Protocol")
        if proto:
            env["GIT_PROTOCOL"] = proto
        return env

    def _send(self, status, ctype, body):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        repo, rest = self._repo(url.path)
        if url.path == "/healthz":
            return self._send(200, "text/plain", b"ok\n")
        if repo is None:
            return self._send(404, "text/plain", b"no such repository\n")
        service = parse_qs(url.query).get("service", [None])[0]
        if rest != ["info", "refs"] or service != "git-upload-pack":
            return self._send(403, "text/plain", b"read-only smart HTTP only\n")
        out = subprocess.run(
            ["git", "upload-pack", "--stateless-rpc", "--advertise-refs", repo],
            env=self._env(), capture_output=True)
        if out.returncode != 0:
            return self._send(500, "text/plain", out.stderr)
        body = pkt(b"# service=git-upload-pack\n") + b"0000" + out.stdout
        self._send(200, "application/x-git-upload-pack-advertisement", body)

    def do_POST(self):
        url = urlparse(self.path)
        repo, rest = self._repo(url.path)
        if repo is None or rest != ["git-upload-pack"]:
            return self._send(403, "text/plain", b"read-only smart HTTP only\n")
        length = int(self.headers.get("Content-Length", "0"))
        data = self.rfile.read(length)
        if self.headers.get("Content-Encoding") == "gzip":
            data = gzip.decompress(data)
        out = subprocess.run(["git", "upload-pack", "--stateless-rpc", repo],
                             env=self._env(), input=data, capture_output=True)
        if out.returncode != 0:
            return self._send(500, "text/plain", out.stderr)
        self._send(200, "application/x-git-upload-pack-result", out.stdout)


if __name__ == "__main__":
    ThreadingHTTPServer(("", PORT), Handler).serve_forever()
