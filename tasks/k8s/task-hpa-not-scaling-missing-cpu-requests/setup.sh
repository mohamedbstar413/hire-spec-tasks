#!/bin/bash
set -e

echo "Deploying Kubernetes environment for HPA Not Scaling Missing CPU Requests task..."

# 1. Deploy Deployment web-app WITHOUT resources.requests.cpu
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

# 2. Deploy HPA targeting web-app
cat << 'EOF' | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
EOF

echo "Waiting for HPA controller to reconcile..."
sleep 5

echo "Setup completed: Deployment web-app created without resources.requests.cpu. HPA web-app-hpa shows TARGETS <unknown>/80% and cannot scale."
