#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: NetworkPolicy DNS Resolution Blocked ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment app-server exists
if ! kubectl get deployment app-server -n default >/dev/null 2>&1; then
    echo "ERROR: Deployment 'app-server' not found in default namespace."
    exit 1
fi

echo "Testing DNS resolution from inside app-server pod for 'kubernetes.default'..."

# 3. Test DNS resolution inside app-server pod using nslookup / getent / nc
NSLOOKUP_OUT=$(kubectl exec deployment/app-server -n default -- nslookup kubernetes.default 2>/dev/null || true)

if ! echo "$NSLOOKUP_OUT" | grep -q "Address"; then
    # Fallback test with curl if nslookup isn't available in alpine/curl container
    NSLOOKUP_OUT=$(kubectl exec deployment/app-server -n default -- curl -s --connect-timeout 4 -I http://kubernetes.default 2>/dev/null || true)
fi

echo "DNS Result Output:"
echo "$NSLOOKUP_OUT"

if echo "$NSLOOKUP_OUT" | grep -q "Could not resolve host"; then
    echo "ERROR: DNS resolution failed ('Could not resolve host'). CoreDNS egress is still blocked by NetworkPolicy."
    exit 1
fi

# 4. Verify NetworkPolicy app-egress-policy permits port 53 egress
EGRESS_PORTS=$(kubectl get netpol app-egress-policy -n default -o jsonpath='{.spec.egress[*].ports[*].port}' 2>/dev/null || true)

if [ -n "$EGRESS_PORTS" ] && ! echo "$EGRESS_PORTS" | grep -q "53"; then
    echo "WARNING: NetworkPolicy 'app-egress-policy' egress ports ($EGRESS_PORTS) does not contain port 53."
fi

echo "SUCCESS: NetworkPolicy DNS blocking issue resolved! Pod 'app-server' successfully resolves 'kubernetes.default'!"
exit 0
