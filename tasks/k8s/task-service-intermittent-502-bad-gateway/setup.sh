#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Intermittent 502 Service task..."

# 1. Create Healthy Deployment (3 replicas listening on 8080, serving 200 OK)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-api
      tier: frontend
  template:
    metadata:
      labels:
        app: web-api
        tier: frontend
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
                  self.send_response(200)
                  self.send_header("Content-type", "text/plain")
                  self.end_headers()
                  self.wfile.write(b"200 OK - Healthy Web API Node\n")
          with socketserver.TCPServer(("", 8080), Handler) as httpd:
              httpd.serve_forever()
        ports:
        - containerPort: 8080
        readinessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 1
          periodSeconds: 2
EOF

# 2. Create Faulty Pod matched by selector app=web-api (serving 502 Bad Gateway)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api-broken-canary
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-api
      tier: broken-canary
  template:
    metadata:
      labels:
        app: web-api
        tier: broken-canary
    spec:
      containers:
      - name: broken-app
        image: python:3.9-slim
        command: ["python3", "-c"]
        args:
        - |
          import http.server, socketserver
          class Handler(http.server.SimpleHTTPRequestHandler):
              def do_GET(self):
                  self.send_response(502)
                  self.send_header("Content-type", "text/plain")
                  self.end_headers()
                  self.wfile.write(b"502 Bad Gateway - Internal Upstream Error\n")
          with socketserver.TCPServer(("", 8080), Handler) as httpd:
              httpd.serve_forever()
        ports:
        - containerPort: 8080
EOF

# 3. Create ClusterIP Service matching app=web-api
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-api-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: web-api
  ports:
  - port: 80
    targetPort: 8080
EOF

echo "Waiting for deployments to start..."
kubectl rollout status deployment/web-api --timeout=60s
kubectl rollout status deployment/web-api-broken-canary --timeout=60s

echo "Setup completed: Service web-api-service now has intermittent 502 Bad Gateway errors (~25% failure rate)."
