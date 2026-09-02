#!/usr/bin/env python3
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"status": "UP", "service": "webapp"}\n')

    def log_message(self, format, *args):
        sys.stdout.write("%s - - [%s] %s\n" %
                         (self.address_string(),
                          self.log_date_time_string(),
                          format%args))
        sys.stdout.flush()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    server = HTTPServer(('0.0.0.0', port), RequestHandler)
    print(f"Starting webapp server on port {port}...")
    sys.stdout.flush()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()
