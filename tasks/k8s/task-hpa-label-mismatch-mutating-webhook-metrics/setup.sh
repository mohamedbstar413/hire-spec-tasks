#!/bin/bash
set -e

echo "Deploying Kubernetes environment for HPA Metric Label Mismatch task..."

# 1. Deploy Deployment web-app with CPU requests specified
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
        webhook-injected-tag: production-v2
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"
EOF

# 2. Deploy HPA web-app-hpa expecting obsolete metric label (webhook-injected-tag: legacy-v1)
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
  maxReplicas: 5
  metrics:
  - type: Pods
    pods:
      metric:
        name: cpu_usage
        selector:
          matchLabels:
            webhook-injected-tag: legacy-v1
      target:
        type: AverageValue
        averageValue: 100m
EOF

echo "Setup completed: Deployment web-app and HPA web-app-hpa deployed with metric label mismatch."
