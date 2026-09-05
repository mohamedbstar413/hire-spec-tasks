#!/bin/bash
set -e

echo "Deploying Kubernetes environment for PVC ReadWriteOnce Multi-Pod Pending task..."

# 1. Create PV & PVC with ReadWriteOnce access mode
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: shared-storage-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/shared-app-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# 2. Create Deployment with 3 replicas mounting app-data-pvc
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shared-app-deployment
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shared-app
  template:
    metadata:
      labels:
        app: shared-app
    spec:
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: app-data-pvc
      containers:
      - name: app-container
        image: nginx:1.25-alpine
        volumeMounts:
        - name: data-volume
          mountPath: /usr/share/nginx/html
        ports:
        - containerPort: 80
EOF

echo "Setup completed: Deployment created with 3 replicas. 1 pod is Running while 2 pods remain stuck due to ReadWriteOnce PVC access mode."
