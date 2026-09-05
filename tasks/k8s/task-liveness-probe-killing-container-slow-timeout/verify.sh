#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Liveness Probe Killing Container (Slow/Failing Endpoint) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment app-service exists
if ! kubectl get deployment app-service -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'app-service' not found in default namespace."
    exit 1
fi

# 3. Verify liveness probe path is updated from /failing-liveness-check
PROBE_PATH=$(kubectl get deployment app-service -n default -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null || true)
if [ "$PROBE_PATH" = "/failing-liveness-check" ]; then
    echo "ERROR: Liveness probe path is still set to failing endpoint '/failing-liveness-check'."
    exit 1
fi

# 4. Check readyReplicas for deployment app-service (must be >= 1)
READY_REPLICAS=$(kubectl get deployment app-service -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'app-service' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl describe pod -l app=app-service' for container restart events."
    exit 1
fi

# 5. Verify pod phase is Running
RUNNING_PODS=$(kubectl get pods -n default -l app=app-service --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -z "$RUNNING_PODS" ]; then
    echo "ERROR: No pods for deployment 'app-service' are in Running phase."
    exit 1
fi

echo "SUCCESS: Liveness probe endpoint updated and Deployment 'app-service' is 1/1 READY!"
exit 0
