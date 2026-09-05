#!/bin/bash
set -e

echo "Deploying Kubernetes environment for NetworkPolicy + PodSecurity + ResourceQuota task..."

# 1. Create namespace secure-app-ns with restricted PodSecurity admission label
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: secure-app-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
EOF

# 2. Create ResourceQuota in secure-app-ns
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: secure-app-ns
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
EOF

# 3. Create NetworkPolicy in secure-app-ns blocking egress DNS/HTTP
cat << 'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secure-netpol
  namespace: secure-app-ns
spec:
  podSelector:
    matchLabels:
      app: secure-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
  egress: []
EOF

# 4. Deploy Deployment secure-app violating PSA restricted standard (no securityContext) & ResourceQuota
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: secure-app-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: app-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 8080
EOF

echo "Setup completed: Namespace secure-app-ns created with restricted PSA, compute-quota, secure-netpol, and misconfigured Deployment secure-app."
