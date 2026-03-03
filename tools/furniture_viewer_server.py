#!/usr/bin/env python3
"""Simple HTTP server that serves FurnitureViewerPage.html and the PZClone asset tree.
Called by Claude's preview panel via .claude/launch.json."""

import http.server
import os
import pathlib
import urllib.parse

PORT      = int(os.environ.get("PORT", 8080))
TOOLS_DIR = pathlib.Path(__file__).parent.resolve()
ROOT_DIR  = TOOLS_DIR.parent   # PZClone project root

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path.lstrip("/")

        # Bare root → viewer page
        if path in ("", "index.html"):
            self.path = "/FurnitureViewerPage.html"
            return http.server.SimpleHTTPRequestHandler.do_GET(self)

        # tools/* → serve from tools directory
        tools_file = TOOLS_DIR / path
        if tools_file.exists() and tools_file.is_file():
            self.directory = str(TOOLS_DIR)
            return http.server.SimpleHTTPRequestHandler.do_GET(self)

        # assets/* → serve from project root (so res://assets/... is reachable)
        root_file = ROOT_DIR / path
        if root_file.exists() and root_file.is_file():
            self.directory = str(ROOT_DIR)
            return http.server.SimpleHTTPRequestHandler.do_GET(self)

        self.send_error(404)

    def log_message(self, format, *args):  # noqa: A002
        pass  # suppress request log spam

if __name__ == "__main__":
    os.chdir(TOOLS_DIR)
    with http.server.ThreadingHTTPServer(("", PORT), Handler) as server:
        print(f"Furniture Viewer  http://localhost:{PORT}", flush=True)
        server.serve_forever()
