#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Secret HostPath Permission Denied task..."

# 1. Create Secret db-api-secret in default namespace
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: db-api-secret
  namespace: default
type: Opaque
stringData:
  api-key.txt: "super-secret-api-key-998877"
EOF

# 2. Deploy Deployment secure-service running non-root with hostPath volume (root-owned) causing permission denied
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-service
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-service
  template:
    metadata:
      labels:
        app: secure-service
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
      containers:
      - name: app
        image: nginx:1.25-alpine
        command: ["/bin/sh", "-c", "echo 'Reading secret...'; cat /var/app/secrets/api-key.txt || exit 1; exec nginx -g 'daemon off;'"]
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secret-volume
          mountPath: /var/app/secrets
      volumes:
      - name: secret-volume
        hostPath:
          path: /var/app/secrets-data
          type: DirectoryOrCreate
EOF

echo "Setup completed: Secret db-api-secret created and Deployment secure-service deployed with root-owned hostPath volume (Crashing)."
