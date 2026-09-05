#!/bin/bash
set -e

echo "Deploying Kubernetes environment for StatefulSet Pod Stuck in Terminating task..."

# 1. Create Headless Service for StatefulSet
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: default
spec:
  clusterIP: None
  selector:
    app: db-ss
  ports:
  - port: 5432
    name: postgres
EOF

# 2. Deploy StatefulSet with 3 replicas
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-ss
  namespace: default
spec:
  serviceName: db-service
  replicas: 3
  selector:
    matchLabels:
      app: db-ss
  template:
    metadata:
      labels:
        app: db-ss
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: database
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "SecretPassword123"
        ports:
        - containerPort: 5432
          name: postgres
EOF

# Wait for StatefulSet pods to be ready
echo "Waiting for StatefulSet pods to initialize..."
kubectl rollout status statefulset/db-ss --timeout=60s || true

# 3. Inject Fault: Patch pod db-ss-0 with a blocking finalizer and delete it
echo "Injecting fault: adding blocking finalizer to pod db-ss-0 and issuing deletion..."
kubectl patch pod db-ss-0 -n default --type=merge -p '{"metadata":{"finalizers":["custom.finalizer/cleanup-protection"]}}'
kubectl delete pod db-ss-0 -n default --wait=false

echo "Setup completed: Pod db-ss-0 is now stuck in 'Terminating' state."
