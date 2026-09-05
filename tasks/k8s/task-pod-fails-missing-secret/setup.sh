#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod Fails Missing Secret task..."

# Deploy Deployment referencing missing Secret 'db-credentials'
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-backend-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-backend-api
  template:
    metadata:
      labels:
        app: secure-backend-api
    spec:
      containers:
      - name: api-container
        image: python:3.9-slim
        command: ["python3", "-c", "import os, time; print(f'Authenticated DB user: {os.getenv(\"DB_USER\")}'); time.sleep(3600)"]
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        ports:
        - containerPort: 8080
EOF

echo "Setup completed: Deployment secure-backend-api created referencing missing Secret 'db-credentials'. Pod is stuck in CreateContainerConfigError."
