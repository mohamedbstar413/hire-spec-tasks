#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Cross-Namespace DNS Resolution Blocked ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if frontend-app deployment exists in frontend-ns
if ! kubectl get deployment frontend-app -n frontend-ns >/dev/null 2>&1; then
    echo "ERROR: Deployment 'frontend-app' not found in namespace 'frontend-ns'."
    exit 1
fi

# 3. Check if backend-service exists in backend-ns
if ! kubectl get service backend-service -n backend-ns >/dev/null 2>&1; then
    echo "ERROR: Service 'backend-service' not found in namespace 'backend-ns'."
    exit 1
fi

echo "Testing cross-namespace DNS resolution for 'backend-service.backend-ns.svc.cluster.local' from frontend-ns..."

# 4. Test DNS resolution and HTTP connectivity across namespaces
RESPONSE=$(kubectl exec -n frontend-ns deployment/frontend-app -- curl -s --connect-timeout 4 http://backend-service.backend-ns.svc.cluster.local:8080 2>/dev/null || true)

echo "Received Response: '$RESPONSE'"

if ! echo "$RESPONSE" | grep -q "200 OK"; then
    echo "ERROR: Cross-namespace DNS resolution failed ('Could not resolve host' or timeout)."
    exit 1
fi

# 5. Verify allow-dns-egress in frontend-ns contains namespaceSelector
NS_SELECTOR=$(kubectl get netpol allow-dns-egress -n frontend-ns -o jsonpath='{.spec.egress[*].to[*].namespaceSelector}' 2>/dev/null || true)

if [ -z "$NS_SELECTOR" ]; then
    echo "WARNING: NetworkPolicy 'allow-dns-egress' egress rule is still missing 'namespaceSelector'."
fi

echo "SUCCESS: Cross-namespace DNS resolution issue resolved! Pods in 'frontend-ns' can successfully resolve 'backend-service.backend-ns.svc.cluster.local'!"
exit 0
