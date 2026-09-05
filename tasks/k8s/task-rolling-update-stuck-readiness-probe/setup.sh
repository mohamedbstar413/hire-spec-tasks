#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Rolling Update Stuck task..."

# 1. Apply initial Deployment (v1) with 4 working replicas
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: default
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        version: v1
    spec:
      containers:
      - name: web-app
        image: python:3.9-slim
        command: ["python3", "-c"]
        args:
        - |
          import http.server, socketserver
          class Handler(http.server.SimpleHTTPRequestHandler):
              def do_GET(self):
                  if self.path == "/health":
                      self.send_response(200)
                      self.send_header("Content-type", "text/plain")
                      self.end_headers()
                      self.wfile.write(b"OK")
                  else:
                      self.send_response(404)
                      self.end_headers()
          with socketserver.TCPServer(("", 8080), Handler) as httpd:
              httpd.serve_forever()
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 2
EOF

echo "Waiting for v1 deployment to stabilize..."
kubectl rollout status deployment/api-service --timeout=60s

# 2. Trigger rolling update (v2) with BROKEN readiness probe path /healthz (returns 404)
echo "Triggering rolling update with misconfigured readinessProbe path (/healthz)..."
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: default
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        version: v2
    spec:
      containers:
      - name: web-app
        image: python:3.9-slim
        command: ["python3", "-c"]
        args:
        - |
          import http.server, socketserver
          class Handler(http.server.SimpleHTTPRequestHandler):
              def do_GET(self):
                  if self.path == "/health":
                      self.send_response(200)
                      self.send_header("Content-type", "text/plain")
                      self.end_headers()
                      self.wfile.write(b"OK")
                  else:
                      self.send_response(404)
                      self.end_headers()
          with socketserver.TCPServer(("", 8080), Handler) as httpd:
              httpd.serve_forever()
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 2
EOF

echo "Setup completed: Deployment api-service is now stuck in a rolling update. New surge pods fail readiness probes, and old pods do not terminate."
