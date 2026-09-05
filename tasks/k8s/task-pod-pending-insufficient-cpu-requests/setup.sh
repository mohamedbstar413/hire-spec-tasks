#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod Pending Insufficient CPU Requests task..."

# Deploy Deployment with 4 replicas, requesting 2 CPUs per pod (2000m)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compute-app
  namespace: default
spec:
  replicas: 4
  selector:
    matchLabels:
      app: compute-app
  template:
    metadata:
      labels:
        app: compute-app
    spec:
      containers:
      - name: worker
        image: python:3.9-slim
        command: ["python3", "-c", "import time; print('Worker running...'); time.sleep(3600)"]
        resources:
          requests:
            cpu: "2000m"
            memory: "128Mi"
          limits:
            cpu: "2000m"
            memory: "256Mi"
EOF

echo "Setup completed: Deployment compute-app created. Pods requested 2.0 CPUs each, causing 2 pods to remain stuck in Pending with 'Insufficient cpu'."
