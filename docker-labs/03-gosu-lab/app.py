# app.py
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

OUTPUT_FILE = "/app/write-here.txt"

print(f"Writing to {OUTPUT_FILE}...")

try:
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, "w") as f:
        f.write("Container started successfully!\n")

    print("Successfully wrote file.")
except Exception as e:
    print(f"Startup failed: {e}", file=sys.stderr)
    sys.exit(1)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"Server is running.\n")


print("Starting HTTP server on :8000")
HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
