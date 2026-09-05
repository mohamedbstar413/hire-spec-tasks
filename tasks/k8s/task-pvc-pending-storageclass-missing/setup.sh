#!/bin/bash
set -e

echo "Deploying Kubernetes environment for PVC Pending StorageClass Missing task..."

# 1. Create valid StorageClass 'standard' and PV
cat << 'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-storage
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: /tmp/pvc-pending-data
EOF

# 2. Create PVC with NON-EXISTENT StorageClass 'fast-ssd-storage'
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: default
spec:
  storageClassName: fast-ssd-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

# 3. Create Deployment mounting data-pvc
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-app
  template:
    metadata:
      labels:
        app: db-app
    spec:
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: data-pvc
      containers:
      - name: database
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "SecretPassword123"
        volumeMounts:
        - name: data-volume
          mountPath: /var/lib/postgresql/data
        ports:
        - containerPort: 5432
EOF

echo "Setup completed: PVC 'data-pvc' created with non-existent storageClassName 'fast-ssd-storage'. PVC and pod are stuck in Pending state."
