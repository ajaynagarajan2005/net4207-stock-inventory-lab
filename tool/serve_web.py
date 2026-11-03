"""Serves build/web on http://localhost:8085 with caching disabled,
so a fresh `flutter build web` always shows up on reload."""
import functools
import http.server
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "build" / "web"


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    handler = functools.partial(NoCacheHandler, directory=str(ROOT))
    http.server.ThreadingHTTPServer(("127.0.0.1", 8085), handler).serve_forever()
