#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Cross-Namespace DNS Resolution Blocked task..."

# 1. Create namespaces frontend-ns and backend-ns
kubectl create namespace frontend-ns --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace backend-ns --dry-run=client -o yaml | kubectl apply -f -

# 2. Deploy backend service in backend-ns
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: backend-ns
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
                  self.wfile.write(b"200 OK - Backend API Connected Across Namespaces\n")
          with socketserver.TCPServer(("", 8080), Handler) as httpd:
              httpd.serve_forever()
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: backend-ns
spec:
  type: ClusterIP
  selector:
    app: backend-api
  ports:
  - port: 8080
    targetPort: 8080
EOF

# 3. Deploy frontend client app in frontend-ns
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: frontend-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend-app
  template:
    metadata:
      labels:
        app: frontend-app
    spec:
      containers:
      - name: web-client
        image: curlimages/curl:8.5.0
        command: ["sh", "-c", "while true; do sleep 3600; done"]
EOF

# 4. Create Faulty Egress NetworkPolicy in frontend-ns (missing namespaceSelector for kube-system CoreDNS)
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: frontend-ns
spec:
  podSelector:
    matchLabels:
      app: frontend-app
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

echo "Waiting for deployments to start..."
kubectl rollout status deployment/backend-api -n backend-ns --timeout=60s
kubectl rollout status deployment/frontend-app -n frontend-ns --timeout=60s

echo "Setup completed: NetworkPolicy 'allow-dns-egress' in frontend-ns is missing namespaceSelector for kube-system, blocking cross-namespace DNS resolution."
