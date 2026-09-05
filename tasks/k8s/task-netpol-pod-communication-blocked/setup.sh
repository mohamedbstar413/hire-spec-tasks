#!/bin/bash
set -e

echo "Deploying Kubernetes environment for NetworkPolicy Communication Blocked task..."

# 1. Create Backend Deployment & ClusterIP Service
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
      - name: api-server
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
                  self.wfile.write(b"200 OK - Backend API Connected\n")
          with socketserver.TCPServer(("", 8080), Handler) as httpd:
              httpd.serve_forever()
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: backend-api
  ports:
  - port: 8080
    targetPort: 8080
EOF

# 2. Create Frontend Client Deployment
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: web-client
        image: curlimages/curl:8.5.0
        command: ["sh", "-c", "while true; do sleep 3600; done"]
EOF

# 3. Create Restrictive NetworkPolicy blocking frontend (only allowing role=internal-admin)
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: internal-admin
    ports:
    - protocol: TCP
      port: 8080
EOF

echo "Waiting for deployments to start..."
kubectl rollout status deployment/backend-api --timeout=60s
kubectl rollout status deployment/frontend --timeout=60s

echo "Setup completed: NetworkPolicy 'backend-netpol' isolates backend-api and blocks traffic from app=frontend."
