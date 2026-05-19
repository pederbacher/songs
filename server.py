#!/usr/bin/env python3
"""
Local development server for the song viewer.
Serves output_html/ as static files, and provides two extra endpoints:

  GET  /song-source?file=Artist___Title.txt   → returns raw .txt content as JSON
  POST /save-song                              → saves edited .txt back to songs/
"""

import http.server
import urllib.parse
import os
import sys
import json

BASE = os.path.dirname(os.path.abspath(__file__))
SONGS_DIR = os.path.join(BASE, "songs")
HTML_DIR  = os.path.join(BASE, "output_html")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=HTML_DIR, **kwargs)

    def log_message(self, fmt, *args):
        # Suppress per-request logs for cleaner output; keep errors
        if args and str(args[1]) >= "400":
            super().log_message(fmt, *args)

    def _safe_filename(self, name):
        """Return name if it looks like a plain song filename, else None."""
        if not name:
            return None
        if ".." in name or "/" in name or "\\" in name:
            return None
        if not name.endswith(".txt"):
            return None
        return name

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/song-source":
            params = urllib.parse.parse_qs(parsed.query)
            filename = self._safe_filename(params.get("file", [None])[0])
            if filename:
                filepath = os.path.join(SONGS_DIR, filename)
                if os.path.isfile(filepath):
                    with open(filepath, "r", encoding="utf-8") as fh:
                        content = fh.read()
                    data = json.dumps({"content": content}).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json; charset=utf-8")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
            self.send_error(404, "Song source not found")
            return
        super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/rebuild":
            self.rfile.read(int(self.headers.get("Content-Length", 0)))
            import subprocess, threading
            def run():
                env = {**os.environ, "SANGE_NO_SERVER_RESTART": "1"}
                subprocess.run(["Rscript", "make-html.R"], cwd=BASE, env=env)
            t = threading.Thread(target=run, daemon=True)
            t.start()
            t.join()  # wait for completion before responding
            resp = json.dumps({"ok": True}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return
        if parsed.path == "/new-song":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
            except json.JSONDecodeError:
                self.send_error(400, "Invalid JSON")
                return
            filename = self._safe_filename(data.get("file", ""))
            if not filename:
                self.send_error(400, "Invalid filename")
                return
            filepath = os.path.join(SONGS_DIR, filename)
            if os.path.exists(filepath):
                self.send_error(409, "File already exists")
                return
            open(filepath, "w", encoding="utf-8").close()
            print(f"Created: {filepath}")
            resp = json.dumps({"ok": True}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return
        if parsed.path == "/save-song":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
            except json.JSONDecodeError:
                self.send_error(400, "Invalid JSON")
                return
            filename = self._safe_filename(data.get("file", ""))
            content  = data.get("content", "")
            if not filename:
                self.send_error(400, "Invalid filename")
                return
            filepath = os.path.join(SONGS_DIR, filename)
            with open(filepath, "w", encoding="utf-8") as fh:
                fh.write(content)
            print(f"Saved: {filepath}")
            resp = json.dumps({"ok": True}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return
        self.send_error(404)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    with http.server.HTTPServer(("", port), Handler) as httpd:
        print(f"Serving output_html/ on http://localhost:{port}/")
        print("Song source/save endpoints active. Press Ctrl-C to stop.")
        httpd.serve_forever()
