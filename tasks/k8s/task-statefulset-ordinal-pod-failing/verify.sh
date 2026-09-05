#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: StatefulSet Ordinal Pod Failing ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if StatefulSet app exists
if ! kubectl get statefulset app -n default >/dev/null 2>&1; then
    echo "ERROR: StatefulSet 'app' not found in default namespace."
    exit 1
fi

# 3. Check requested replicas count (must be 3)
REPLICAS=$(kubectl get statefulset app -n default -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" -ne 3 ]; then
    echo "ERROR: Expected StatefulSet spec.replicas to be 3, but found $REPLICAS."
    exit 1
fi

# 4. Check ready replicas count (must be 3)
READY_REPLICAS=$(kubectl get statefulset app -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current StatefulSet Ready Replicas: $READY_REPLICAS / 3"

if [ "$READY_REPLICAS" -lt 3 ]; then
    echo "ERROR: StatefulSet 'app' is not fully ready. Required: 3/3, Actual: $READY_REPLICAS/3."
    exit 1
fi

# 5. Verify no pods matching app=stateful-app are in CrashLoopBackOff or Error status
CRASHING_PODS=$(kubectl get pods -n default -l app=stateful-app --no-headers | grep -iE "CrashLoopBackOff|Error" | wc -l || true)
if [ "$CRASHING_PODS" -gt 0 ]; then
    echo "ERROR: Detected $CRASHING_PODS pod(s) still stuck in CrashLoopBackOff or Error status."
    exit 1
fi

# 6. Verify ConfigMap cluster-config contains configuration entry for app-2
CM_DATA=$(kubectl get configmap cluster-config -n default -o jsonpath='{.data.cluster-nodes\.json}' 2>/dev/null || true)
if ! echo "$CM_DATA" | grep -q '"app-2"'; then
    echo "ERROR: ConfigMap 'cluster-config' is still missing configuration entry for 'app-2'."
    exit 1
fi

echo "SUCCESS: Ordinal pod 'app-2' crash resolved! StatefulSet 'app' is 3/3 READY!"
exit 0
