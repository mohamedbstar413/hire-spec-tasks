#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Sidecar Blocking Pod Termination task..."

# 1. Create ConfigMap containing sidecar entrypoint script (ignores SIGTERM)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: sidecar-script
  namespace: default
data:
  sidecar-entrypoint.sh: |
    #!/bin/sh
    # FAULT: Trapping/ignoring SIGTERM prevents sidecar from shutting down gracefully
    trap 'echo "SIGTERM ignored, blocking termination..."' SIGTERM
    echo "Sidecar log collector running..."
    while true; do
      sleep 1
    done
EOF

# 2. Deploy Deployment with app-container + sidecar-logging container
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-sidecar
  template:
    metadata:
      labels:
        app: app-with-sidecar
    spec:
      terminationGracePeriodSeconds: 30
      volumes:
      - name: script-vol
        configMap:
          name: sidecar-script
          defaultMode: 0755
      containers:
      - name: main-app
        image: python:3.9-slim
        command: ["python3", "-c", "import time; print('Main app running...'); time.sleep(3600)"]
      - name: sidecar-logging
        image: busybox:1.36
        command: ["/bin/sh", "/scripts/sidecar-entrypoint.sh"]
        volumeMounts:
        - name: script-vol
          mountPath: /scripts
EOF

echo "Waiting for app-deployment to start..."
kubectl rollout status deployment/app-deployment --timeout=60s

echo "Setup completed: Deployment app-deployment created with sidecar-logging ignoring SIGTERM. Pod deletion will hang for 30s."
