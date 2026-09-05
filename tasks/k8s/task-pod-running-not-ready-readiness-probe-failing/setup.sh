#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod Running Not Ready Readiness Probe Failing task..."

# Deploy Deployment api-server with failing readinessProbe (path /healthz returns 404)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
EOF

echo "Setup completed: Deployment api-server deployed with failing readiness probe /healthz (STATUS: Running, READY: 0/1)."
