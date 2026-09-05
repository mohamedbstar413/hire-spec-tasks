#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Multi-Container Unix Socket SecurityContext Failure task..."

# Deploy Deployment app-with-sidecar with socket path mismatch and securityContext drop
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-sidecar
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
      containers:
      - name: main-app
        image: nginx:1.25-alpine
        command: ["/bin/sh", "-c", "echo 'Connecting to sidecar...'; ls -la /var/run/proxy/sidecar.sock || exit 1; exec nginx -g 'daemon off;'"]
        ports:
        - containerPort: 80
        volumeMounts:
        - name: socket-dir
          mountPath: /var/run/proxy
      - name: sidecar-proxy
        image: alpine:3.19
        command: ["/bin/sh", "-c", "nc -l -U /var/run/sidecar/sidecar.sock"]
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: socket-dir
          mountPath: /var/run/sidecar
      volumes:
      - name: socket-dir
        emptyDir: {}
EOF

echo "Setup completed: Deployment app-with-sidecar deployed with socket path mismatch and readOnlyRootFilesystem block."
