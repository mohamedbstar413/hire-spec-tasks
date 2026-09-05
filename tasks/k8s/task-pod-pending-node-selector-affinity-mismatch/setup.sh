#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod Pending Node Selector Mismatch task..."

# Deploy Deployment analytics-worker requiring non-existent node labels (disktype=ssd, gpu=true)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-worker
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: analytics-worker
  template:
    metadata:
      labels:
        app: analytics-worker
    spec:
      nodeSelector:
        disktype: ssd
        gpu: "true"
      containers:
      - name: worker
        image: python:3.9-slim
        command: ["python3", "-c", "import time; print('Analytics processing...'); time.sleep(3600)"]
EOF

echo "Setup completed: Deployment analytics-worker created requiring non-existent nodeSelector (disktype=ssd, gpu=true). Pod is stuck in Pending state."
