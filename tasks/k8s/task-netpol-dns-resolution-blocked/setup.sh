#!/bin/bash
set -e

echo "Deploying Kubernetes environment for NetworkPolicy DNS Resolution Blocked task..."

# 1. Create Deployment app-server
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-server
  template:
    metadata:
      labels:
        app: app-server
    spec:
      containers:
      - name: web-app
        image: curlimages/curl:8.5.0
        command: ["sh", "-c", "while true; do sleep 3600; done"]
EOF

# 2. Create Egress NetworkPolicy blocking UDP/TCP port 53 (CoreDNS)
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-egress-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: app-server
  policyTypes:
  - Egress
  egress:
  - ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
EOF

echo "Waiting for app-server deployment to start..."
kubectl rollout status deployment/app-server --timeout=60s

echo "Setup completed: NetworkPolicy 'app-egress-policy' restricts egress on app-server and blocks CoreDNS (port 53), causing all DNS resolution requests to fail."
