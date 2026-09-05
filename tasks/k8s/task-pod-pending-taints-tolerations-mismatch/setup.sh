#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod Pending Taints & Tolerations Mismatch task..."

# 1. Apply taint dedicated=gpu:NoSchedule to all nodes in the cluster
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Tainting node '$NODE_NAME' with dedicated=gpu:NoSchedule..."
kubectl taint nodes "$NODE_NAME" dedicated=gpu:NoSchedule --overwrite

# 2. Deploy Deployment dedicated-worker WITHOUT matching toleration
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dedicated-worker
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dedicated-worker
  template:
    metadata:
      labels:
        app: dedicated-worker
    spec:
      containers:
      - name: worker
        image: python:3.9-slim
        command: ["python3", "-c", "import time; print('Dedicated worker running...'); time.sleep(3600)"]
EOF

echo "Setup completed: Node '$NODE_NAME' tainted with dedicated=gpu:NoSchedule. Deployment dedicated-worker created without tolerations. Pod is stuck in Pending state."
