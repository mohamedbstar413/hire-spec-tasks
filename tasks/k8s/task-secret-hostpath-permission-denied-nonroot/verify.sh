#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Secret Mounted as Volume Permission Denied (HostPath + Non-Root) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment secure-service exists
if ! kubectl get deployment secure-service -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'secure-service' not found in default namespace."
    exit 1
fi

# 3. Verify hostPath is removed and secret volume is used
HOST_PATH=$(kubectl get deployment secure-service -n default -o jsonpath='{.spec.template.spec.volumes[*].hostPath}' 2>/dev/null || true)
SECRET_VOL=$(kubectl get deployment secure-service -n default -o jsonpath='{.spec.template.spec.volumes[*].secret.secretName}' 2>/dev/null || true)

if [ -n "$HOST_PATH" ]; then
    echo "ERROR: Deployment 'secure-service' is still using a hostPath volume ($HOST_PATH) instead of native Kubernetes Secret volume."
    exit 1
fi

if [ "$SECRET_VOL" != "db-api-secret" ]; then
    echo "ERROR: Deployment 'secure-service' is not mounting Secret 'db-api-secret'. Current: '$SECRET_VOL'"
    exit 1
fi

# 4. Check readyReplicas for deployment secure-service (must be >= 1)
READY_REPLICAS=$(kubectl get deployment secure-service -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'secure-service' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    echo "Check 'kubectl logs -l app=secure-service' for permission or startup errors."
    exit 1
fi

# 5. Verify pod status phase is Running
RUNNING_PODS=$(kubectl get pods -n default -l app=secure-service --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
if [ -z "$RUNNING_PODS" ]; then
    echo "ERROR: No pods for deployment 'secure-service' are in Running phase."
    exit 1
fi

echo "SUCCESS: HostPath permission issue fixed! Secret 'db-api-secret' mounted via secret volume and Deployment 'secure-service' is 1/1 READY!"
exit 0
