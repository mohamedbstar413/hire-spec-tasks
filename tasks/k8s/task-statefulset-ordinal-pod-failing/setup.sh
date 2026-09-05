#!/bin/bash
set -e

echo "Deploying Kubernetes environment for StatefulSet Ordinal Pod Failing task..."

# 1. Create Headless Service
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: default
spec:
  clusterIP: None
  selector:
    app: stateful-app
  ports:
  - port: 8080
    name: http
EOF

# 2. Create ConfigMap (Missing configuration entry for app-2)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
  namespace: default
data:
  cluster-nodes.json: |
    {
      "app-0": {
        "role": "primary",
        "port": 8080
      },
      "app-1": {
        "role": "replica",
        "port": 8080
      }
    }
EOF

# 3. Create StatefulSet with 3 replicas (app-0, app-1, app-2)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: app
  namespace: default
spec:
  serviceName: app-service
  replicas: 3
  selector:
    matchLabels:
      app: stateful-app
  template:
    metadata:
      labels:
        app: stateful-app
    spec:
      containers:
      - name: node-container
        image: python:3.9-slim
        command: ["python3", "-c"]
        args:
        - |
          import os, sys, time, json
          pod_name = os.getenv("POD_NAME", "")
          config_file = "/etc/config/cluster-nodes.json"
          
          print(f"Initializing stateful pod '{pod_name}'...", flush=True)
          if not os.path.exists(config_file):
              print(f"FATAL ERROR: Config file {config_file} missing!", file=sys.stderr, flush=True)
              sys.exit(1)
              
          with open(config_file) as f:
              nodes = json.load(f)
              
          if pod_name not in nodes:
              print(f"FATAL ERROR: Configuration for ordinal pod '{pod_name}' missing in {config_file}!", file=sys.stderr, flush=True)
              sys.exit(1)
              
          node_cfg = nodes[pod_name]
          print(f"Node '{pod_name}' initialized as '{node_cfg.get('role', 'unknown')}' on port {node_cfg.get('port')}.", flush=True)
          while True:
              time.sleep(3600)
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        volumeMounts:
        - name: config-vol
          mountPath: /etc/config
      volumes:
      - name: config-vol
        configMap:
          name: cluster-config
EOF

echo "Setup completed: StatefulSet 'app' deployed. Pods app-0 and app-1 are running, while app-2 is in CrashLoopBackOff."
