#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Init Container Crash task..."

# 1. Create dependent database Service & Deployment
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: default
spec:
  selector:
    app: db-server
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-server
  template:
    metadata:
      labels:
        app: db-server
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "Secret123"
        ports:
        - containerPort: 5432
EOF

# 2. Create web-app Deployment with FAULTY init container (typo in target hostname: db-servcie instead of db-service)
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
      initContainers:
      - name: init-db-check
        image: busybox:1.36
        command: ['sh', '-c', 'echo "Checking database connection..."; nc -z -w 3 db-servcie 5432 || (echo "ERROR: Unable to resolve or reach db-servcie:5432" && exit 1)']
      containers:
      - name: app-container
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "Setup completed: Pod is now in Init:CrashLoopBackOff state due to init container failure."
