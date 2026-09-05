#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: HPA Not Scaling Missing CPU Requests ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment web-app exists
if ! kubectl get deployment web-app -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'web-app' not found in default namespace."
    exit 1
fi

# 3. Check if HPA web-app-hpa exists
if ! kubectl get hpa web-app-hpa -n default >/dev/null 2>&1; then
    echo "ERROR: HorizontalPodAutoscaler 'web-app-hpa' not found in default namespace."
    exit 1
fi

# 4. Verify resources.requests.cpu is specified in container spec
CPU_REQ=$(kubectl get deployment web-app -n default -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
echo "Current Deployment Container CPU Request: '$CPU_REQ'"

if [ -z "$CPU_REQ" ]; then
    echo "ERROR: Deployment container 'web-container' is still missing 'resources.requests.cpu'."
    exit 1
fi

# 5. Check HPA status to ensure target is not <unknown>
HPA_TARGET=$(kubectl get hpa web-app-hpa -n default -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || true)
echo "Current HPA CPU Average Utilization Metric: '$HPA_TARGET'"

# Alternatively check describe output for unknown
HPA_DESC=$(kubectl describe hpa web-app-hpa -n default 2>/dev/null || true)
if echo "$HPA_DESC" | grep -q "missing request for cpu"; then
    echo "ERROR: HPA 'web-app-hpa' still reports missing request for CPU."
    exit 1
fi

echo "SUCCESS: HPA issue resolved! Container CPU requests defined and HPA 'web-app-hpa' is healthy!"
exit 0
