#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Multi-Container Unix Socket SecurityContext Failure ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment app-with-sidecar exists
if ! kubectl get deployment app-with-sidecar -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'app-with-sidecar' not found in default namespace."
    exit 1
fi

# 3. Check volume mount path alignment between main-app and sidecar-proxy
MAIN_MOUNT=$(kubectl get deployment app-with-sidecar -n default -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[0].mountPath}' 2>/dev/null || true)
SIDECAR_MOUNT=$(kubectl get deployment app-with-sidecar -n default -o jsonpath='{.spec.template.spec.containers[1].volumeMounts[0].mountPath}' 2>/dev/null || true)

if [ "$MAIN_MOUNT" != "$SIDECAR_MOUNT" ]; then
    echo "ERROR: Mount path mismatch between main-app ('$MAIN_MOUNT') and sidecar-proxy ('$SIDECAR_MOUNT')."
    exit 1
fi

# 4. Check readyReplicas for deployment app-with-sidecar (must be >= 1)
READY_REPLICAS=$(kubectl get deployment app-with-sidecar -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'app-with-sidecar' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl logs -l app=app-with-sidecar -c main-app' for details."
    exit 1
fi

# 5. Verify 2/2 containers are ready
POD_READY=$(kubectl get pods -l app=app-with-sidecar -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null || true)
if [[ "$POD_READY" != *"true true"* ]]; then
    echo "ERROR: Not all containers in 'app-with-sidecar' are ready. Container statuses: '$POD_READY'."
    exit 1
fi

echo "SUCCESS: Unix socket paths aligned, securityContext fixed, and Deployment 'app-with-sidecar' is 2/2 READY!"
exit 0
