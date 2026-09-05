#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Deployment Replicas Mismatch (HPA Override) task..."

# 1. Deploy Deployment web-app-deployment with replicas: 5 requested
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app-deployment
  namespace: default
spec:
  replicas: 5
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
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
EOF

# 2. Deploy HPA targeting web-app-deployment with minReplicas: 1 (overrides Deployment replicas to 1)
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
    name: web-app-deployment
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

echo "Waiting for HPA controller to reconcile deployment replicas..."
sleep 5

echo "Setup completed: Deployment web-app-deployment created with 5 replicas requested, but HPA web-app-hpa scaled it down to 1 replica."
