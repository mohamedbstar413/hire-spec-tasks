#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod hostPath node dependency task..."

# Deploy Deployment log-processor using hostPath volume
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-processor
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-processor
  template:
    metadata:
      labels:
        app: log-processor
    spec:
      containers:
      - name: processor
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-storage
          mountPath: /var/log/processor
      volumes:
      - name: app-storage
        hostPath:
          path: /var/log/processor-data
          type: DirectoryOrCreate
EOF

echo "Setup completed: Deployment log-processor created with hostPath volume /var/log/processor-data."
