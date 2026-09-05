#!/bin/bash
set -e

echo "Deploying Kubernetes environment for CSI Driver Crashing task..."

# 1. Deploy CSI driver controller in kube-system with invalid container command causing CrashLoopBackOff
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-driver-controller
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: csi-driver-controller
  template:
    metadata:
      labels:
        app: csi-driver-controller
    spec:
      containers:
      - name: csi-provisioner
        image: nginx:1.25-alpine
        command: ["/bin/sh", "-c", "echo 'Starting CSI Provisioner...'; exit 1"]
        ports:
        - containerPort: 80
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-custom-sc
provisioner: k8s.io/csi-custom-driver
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: csi-custom-sc
  resources:
    requests:
      storage: 1Gi
EOF

echo "Setup completed: CSI driver csi-driver-controller deployed in kube-system (Crashing), StorageClass csi-custom-sc created, and PVC data-pvc pending."
