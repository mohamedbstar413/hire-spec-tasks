#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Pod Fails Incorrect imagePullSecrets task..."

# 1. Create valid docker-registry Secret 'private-registry-cred'
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: private-registry-cred
  namespace: default
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
EOF

# 2. Deploy Deployment private-app referencing INCORRECT imagePullSecrets name (private-registry-cred-typo)
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: private-app
  template:
    metadata:
      labels:
        app: private-app
    spec:
      imagePullSecrets:
      - name: private-registry-cred-typo
      containers:
      - name: web-app
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

echo "Setup completed: Deployment private-app created with incorrect imagePullSecrets name 'private-registry-cred-typo'. Pod is stuck in ImagePullBackOff / ErrImagePull."
