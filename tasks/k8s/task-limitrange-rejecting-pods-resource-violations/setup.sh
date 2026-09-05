#!/bin/bash
set -e

echo "Deploying Kubernetes environment for LimitRange Resource Violations task..."

# 1. Create LimitRange enforcing max CPU 500m and min memory 128Mi
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-cpu-limit-range
  namespace: default
spec:
  limits:
  - max:
      cpu: "500m"
      memory: "512Mi"
    min:
      cpu: "50m"
      memory: "128Mi"
    default:
      cpu: "250m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    type: Container
EOF

# 2. Deploy Deployment web-service VIOLATING LimitRange (limits.cpu 2000m > 500m, requests.memory 64Mi < 128Mi)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-service
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-service
  template:
    metadata:
      labels:
        app: web-service
    spec:
      containers:
      - name: web-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "64Mi"
          limits:
            cpu: "2000m"
            memory: "1Gi"
EOF

echo "Setup completed: LimitRange mem-cpu-limit-range created in namespace default. Deployment web-service created violating min/max limits, preventing pod creation."
