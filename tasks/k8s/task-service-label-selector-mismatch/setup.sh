#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Service Label Selector Mismatch task..."

# 1. Create Deployment (3 replicas with label app=web-frontend)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
        tier: frontend
    spec:
      containers:
      - name: nginx-web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

# 2. Create Service with MISMATCHED selector (app=frontend-web-service instead of app=web-frontend)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: frontend-web-service
  ports:
  - port: 80
    targetPort: 80
EOF

echo "Waiting for deployment to initialize..."
kubectl rollout status deployment/web-frontend --timeout=60s

echo "Setup completed: Service frontend-service created with mismatched selector (app=frontend-web-service vs app=web-frontend). Endpoints show <none>."
