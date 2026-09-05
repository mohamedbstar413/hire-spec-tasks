#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Topology Spread Constraints task..."

# Deploy Deployment ha-app with strict topologySpreadConstraints (whenUnsatisfiable: DoNotSchedule)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ha-app
  template:
    metadata:
      labels:
        app: ha-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: ha-app
      containers:
      - name: web-app
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "Setup completed: Deployment ha-app created with strict topologySpreadConstraints (whenUnsatisfiable: DoNotSchedule). Pods are stuck in Pending."
