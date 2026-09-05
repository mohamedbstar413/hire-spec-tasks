#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Deployment Stuck Partial Rollout ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment web-app-deployment exists
if ! kubectl get deployment web-app-deployment -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'web-app-deployment' not found in default namespace."
    exit 1
fi

# 3. Check requested replicas count (must be 10)
REPLICAS=$(kubectl get deployment web-app-deployment -n default -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" -ne 10 ]; then
    echo "ERROR: Expected deployment spec.replicas to be 10, but found $REPLICAS."
    exit 1
fi

# 4. Check ready replicas count (must be 10)
READY_REPLICAS=$(kubectl get deployment web-app-deployment -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 10"

if [ "$READY_REPLICAS" -lt 10 ]; then
    echo "ERROR: Deployment 'web-app-deployment' is not fully ready. Required: 10/10, Actual: $READY_REPLICAS/10."
    exit 1
fi

# 5. Check updated replicas count (rollout must be complete, 10 up-to-date)
UPDATED_REPLICAS=$(kubectl get deployment web-app-deployment -n default -o jsonpath='{.status.updatedReplicas}')
if [ -z "$UPDATED_REPLICAS" ]; then
    UPDATED_REPLICAS=0
fi

if [ "$UPDATED_REPLICAS" -lt 10 ]; then
    echo "ERROR: Rollout is still incomplete. Updated replicas: $UPDATED_REPLICAS/10."
    exit 1
fi

# 6. Verify no pods matching app=web-app are stuck in ImagePullBackOff, ErrImagePull, or CrashLoopBackOff
FAILING_PODS=$(kubectl get pods -n default -l app=web-app --no-headers | grep -iE "ImagePullBackOff|ErrImagePull|CrashLoopBackOff|Error" | wc -l || true)
if [ "$FAILING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $FAILING_PODS pod(s) still stuck in ImagePullBackOff or Error status."
    exit 1
fi

# 7. Check that deployment image does not contain the broken tag
CURRENT_IMAGE=$(kubectl get deployment web-app-deployment -n default -o jsonpath='{.spec.template.spec.containers[0].image}')
if echo "$CURRENT_IMAGE" | grep -q "nonexistent"; then
    echo "ERROR: Deployment image still references invalid tag '$CURRENT_IMAGE'."
    exit 1
fi

echo "SUCCESS: Partial rollout resolved! Deployment 'web-app-deployment' is 10/10 READY on valid image '$CURRENT_IMAGE'."
exit 0
