#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Rolling Update Stuck Readiness Probe ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment api-service exists
if ! kubectl get deployment api-service -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'api-service' not found in default namespace."
    exit 1
fi

# 3. Check requested replicas count (must be 4)
REPLICAS=$(kubectl get deployment api-service -n default -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" -ne 4 ]; then
    echo "ERROR: Expected deployment spec.replicas to be 4, but found $REPLICAS."
    exit 1
fi

# 4. Check readyReplicas for deployment api-service (must be 4)
READY_REPLICAS=$(kubectl get deployment api-service -n default -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 4"

if [ "$READY_REPLICAS" -lt 4 ]; then
    echo "ERROR: Deployment 'api-service' is not fully ready. Required: 4/4, Actual: $READY_REPLICAS/4."
    exit 1
fi

# 5. Check updatedReplicas for deployment api-service (must be 4, rollout finished)
UPDATED_REPLICAS=$(kubectl get deployment api-service -n default -o jsonpath='{.status.updatedReplicas}')
if [ -z "$UPDATED_REPLICAS" ]; then
    UPDATED_REPLICAS=0
fi

if [ "$UPDATED_REPLICAS" -lt 4 ]; then
    echo "ERROR: Deployment rollout is still incomplete. Updated replicas: $UPDATED_REPLICAS/4."
    exit 1
fi

# 6. Verify readinessProbe path is not targeting /healthz
PROBE_PATH=$(kubectl get deployment api-service -n default -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null || true)
if [ "$PROBE_PATH" = "/healthz" ]; then
    echo "ERROR: Deployment readinessProbe path is still targeting misconfigured path '/healthz'."
    exit 1
fi

echo "SUCCESS: Rolling update completed! Deployment 'api-service' is 4/4 READY with readinessProbe targeting '$PROBE_PATH'."
exit 0
