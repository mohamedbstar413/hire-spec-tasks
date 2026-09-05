#!/bin/bash
set -e

echo "Deploying Kubernetes environment for ResourceQuota Missing Resources task..."

# 1. Create ResourceQuota requiring explicit requests & limits for CPU and Memory
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: default
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
EOF

# 2. Deploy Deployment WITHOUT a resources section (triggers quota admission error)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: restricted-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: restricted-app
  template:
    metadata:
      labels:
        app: restricted-app
    spec:
      containers:
      - name: web-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "Setup completed: ResourceQuota created in namespace default. Deployment restricted-app created without resources section, preventing pod creation."
