#!/bin/bash
set -e

echo "Deploying Kubernetes environment for VolumeSnapshot Empty Restore task..."

# 1. Create StorageClass with WaitForFirstConsumer volumeBindingMode
cat << 'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delayed-sc
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: WaitForFirstConsumer
EOF

# 2. Create source PVC source-pvc using delayed-sc (not bound yet)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: source-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: delayed-sc
  resources:
    requests:
      storage: 1Gi
EOF

# 3. Create restored PVC restored-pvc (pending binding)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: delayed-sc
  resources:
    requests:
      storage: 1Gi
EOF

# 4. Deploy Deployment data-app mounting restored-pvc
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-app
  template:
    metadata:
      labels:
        app: data-app
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: storage-vol
          mountPath: /usr/share/nginx/html
      volumes:
      - name: storage-vol
        persistentVolumeClaim:
          claimName: restored-pvc
EOF

echo "Setup completed: StorageClass delayed-sc created with WaitForFirstConsumer. Source and restored PVCs created."
