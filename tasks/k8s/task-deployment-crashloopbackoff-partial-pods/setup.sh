#!/bin/bash
set -e

echo "Deploying Kubernetes environment for CrashLoopBackOff scenario..."

# 1. Apply initial working ConfigMap with DB_HOST
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: default
data:
  app.json: |
    {
      "PORT": 8080,
      "ENV": "production",
      "DB_HOST": "db.internal.company.com"
    }
EOF

# 2. Apply Deployment (15 replicas)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  namespace: default
spec:
  replicas: 15
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: api-container
        image: python:3.9-slim
        command: ["python3", "-c"]
        args:
        - |
          import os, sys, time, json
          config_path = "/etc/config/app.json"
          if not os.path.exists(config_path):
              print(f"FATAL ERROR: Configuration file {config_path} not found!", file=sys.stderr, flush=True)
              sys.exit(1)
          try:
              with open(config_path) as f:
                  cfg = json.load(f)
          except Exception as e:
              print(f"FATAL ERROR: Failed to parse {config_path}: {e}", file=sys.stderr, flush=True)
              sys.exit(1)
          if "DB_HOST" not in cfg or not cfg["DB_HOST"]:
              print("FATAL ERROR: Missing required 'DB_HOST' parameter in configuration!", file=sys.stderr, flush=True)
              sys.exit(1)
          print(f"Server starting on port {cfg.get('PORT', 8080)}, DB connection established to {cfg['DB_HOST']}...", flush=True)
          while True:
              time.sleep(3600)
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: api-config
EOF

# Scale to 10 working replicas initially
kubectl scale deployment api-deployment --replicas=10
kubectl rollout status deployment/api-deployment --timeout=60s

# 3. Apply faulty ConfigMap (missing DB_HOST) and scale up to 15 replicas
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: default
data:
  app.json: |
    {
      "PORT": 8080,
      "ENV": "production"
    }
EOF

# Scale deployment to 15 (new pods will crash loop due to missing DB_HOST)
kubectl scale deployment api-deployment --replicas=15

echo "Cluster environment successfully deployed: 10/15 pods ready, 5 pods in CrashLoopBackOff."
