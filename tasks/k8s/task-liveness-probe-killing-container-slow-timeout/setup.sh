#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Liveness Probe Killing Container task..."

# Deploy Deployment app-service with failing livenessProbe causing continuous container restarts
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-service
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-service
  template:
    metadata:
      labels:
        app: app-service
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /failing-liveness-check
            port: 80
          initialDelaySeconds: 1
          periodSeconds: 2
          timeoutSeconds: 1
          failureThreshold: 1
EOF

echo "Setup completed: Deployment app-service deployed with aggressive/failing livenessProbe (Continuous Container Restarts)."
