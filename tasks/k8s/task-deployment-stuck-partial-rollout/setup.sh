#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Deployment Stuck Partial Rollout task..."

# 1. Apply initial Deployment with 10 replicas running valid image (nginx:1.25-alpine)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-deployment
  namespace: default
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: v1
    spec:
      containers:
      - name: web-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "Waiting for initial v1 deployment to stabilize..."
kubectl rollout status deployment/web-app-deployment --timeout=60s

# 2. Trigger rolling update with non-existent / broken image tag (nginx:1.25.99-nonexistent)
echo "Triggering broken rolling update..."
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-deployment
  namespace: default
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: v2
    spec:
      containers:
      - name: web-container
        image: nginx:1.25.99-nonexistent
        ports:
        - containerPort: 80
EOF

echo "Setup completed: Deployment web-app-deployment is now stuck in a partial rollout state."
