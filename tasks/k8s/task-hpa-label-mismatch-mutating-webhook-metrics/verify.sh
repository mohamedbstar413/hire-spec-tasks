#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: HPA Refuses to Scale (Metric Label Mismatch) ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if HPA web-app-hpa exists
if ! kubectl get hpa web-app-hpa -n default >/dev/null 2>&1; then
    echo "ERROR: HPA 'web-app-hpa' not found in default namespace."
    exit 1
fi

# 3. Check HPA metrics spec: verify obsolete selector legacy-v1 is fixed/removed or switched to standard Resource CPU
LEGACY_TAG=$(kubectl get hpa web-app-hpa -n default -o jsonpath='{.spec.metrics[*].pods.metric.selector.matchLabels.webhook-injected-tag}' 2>/dev/null || true)
if [ "$LEGACY_TAG" = "legacy-v1" ]; then
    echo "ERROR: HPA 'web-app-hpa' is still querying mismatching metric label selector 'webhook-injected-tag: legacy-v1'."
    exit 1
fi

# 4. Check readyReplicas for deployment web-app (must be >= 1)
READY_REPLICAS=$(kubectl get deployment web-app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'web-app' is not ready. Required: 1/1, Actual: $READY_REPLICAS/1."
    exit 1
fi

echo "SUCCESS: HPA metric label selector fixed! HPA 'web-app-hpa' is configured cleanly!"
exit 0
