#!/bin/bash
set -e

echo "Deploying Kubernetes environment for Invalid ConfigMap Syntax task..."

# 1. Create ConfigMap app-config with invalid Nginx syntax (missing closing brace and semicolon)
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html;
            invalid_directive_broken_syntax
        }
EOF

# 2. Deploy Deployment web-app mounting app-config into /etc/nginx/conf.d/default.conf
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
      volumes:
      - name: config-volume
        configMap:
          name: app-config
EOF

echo "Setup completed: ConfigMap app-config applied with invalid syntax and Deployment web-app deployed (Crashing)."
