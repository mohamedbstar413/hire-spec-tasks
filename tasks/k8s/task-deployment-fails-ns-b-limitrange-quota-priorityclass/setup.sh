#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Cross-Namespace LimitRange + ResourceQuota + PriorityClass Failure task..."

# 1. Create Namespace ns-a and deploy working Deployment app-service
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ns-a
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-service
  namespace: ns-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-service
  template:
    metadata:
      labels:
        app: app-service
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

# 2. Create Namespace ns-b with LimitRange and tight ResourceQuota
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ns-b
---
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: ns-b
spec:
  limits:
  - defaultRequest:
      cpu: "1000m"
      memory: "1Gi"
    default:
      cpu: "2000m"
      memory: "2Gi"
    type: Container
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: ns-b
spec:
  hard:
    requests.cpu: "1200m"
    requests.memory: "1500Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: existing-worker
  namespace: ns-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - name: worker
        image: nginx:1.25-alpine
        resources:
          requests:
            cpu: "800m"
            memory: "800Mi"
EOF

# 3. Deploy app-service in ns-b without explicit resources (LimitRange injects 1000m CPU -> exceeds quota 1200m)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-service
  namespace: ns-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-service
  template:
    metadata:
      labels:
        app: app-service
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "Setup completed: Deployment app-service works in ns-a, but fails in ns-b due to LimitRange auto-injection exceeding ns-b ResourceQuota."
