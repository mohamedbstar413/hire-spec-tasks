#!/bin/bash
set -e

echo "Deploying Kubernetes environment for CreateContainerConfigError task..."

# 1. Create ConfigMap missing required key DATABASE_URL (has PORT and ENV only)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: default
data:
  PORT: "8080"
  ENV: "production"
EOF

# 2. Deploy Deployment api-server referencing DATABASE_URL from ConfigMap api-config
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
      - name: web-app
        image: python:3.9-slim
        command: ["python3", "-c", "import os, time; print(f'Connected to {os.getenv(\"DATABASE_URL\")}'); time.sleep(3600)"]
        env:
        - name: PORT
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: PORT
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: DATABASE_URL
        ports:
        - containerPort: 8080
EOF

echo "Setup completed: ConfigMap api-config created missing key DATABASE_URL. Deployment api-server pod is stuck in CreateContainerConfigError."
