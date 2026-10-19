"""Serves build/web locally, sending unknown paths to index.html.

The app uses real paths (/insights, /cash-in), so a refresh on one of them
must still load the app. A plain static server would answer 404.

    flutter build web --release --no-web-resources-cdn
    python tool/serve_web.py [port]
"""
import http.server
import os
import sys
from functools import partial

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
    }

    def send_head(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path):
            # An app address, not a file: hand it to the app.
            self.path = "/index.html"
        return super().send_head()

    def end_headers(self):
        # Always fetch a fresh index.html so new builds show up on refresh.
        if self.path.endswith("index.html") or self.path == "/":
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    handler = partial(SpaHandler, directory=os.path.normpath(ROOT))
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"Cash Flow web on http://127.0.0.1:{port}")
        httpd.serve_forever()
