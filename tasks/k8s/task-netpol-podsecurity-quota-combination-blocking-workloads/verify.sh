#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: NetworkPolicy + PodSecurity + ResourceQuota Combination ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if deployment secure-app exists in secure-app-ns
if ! kubectl get deployment secure-app -n secure-app-ns >/dev/null 2>&1; then
    echo "ERROR: Deployment 'secure-app' not found in namespace secure-app-ns."
    exit 1
fi

# 3. Verify Container Resources defined (ResourceQuota requirement)
REQ_CPU=$(kubectl get deployment secure-app -n secure-app-ns -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
REQ_MEM=$(kubectl get deployment secure-app -n secure-app-ns -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)

if [ -z "$REQ_CPU" ] || [ -z "$REQ_MEM" ]; then
    echo "ERROR: Deployment 'secure-app' is missing CPU/Memory requests required by ResourceQuota."
    exit 1
fi

# 4. Verify PodSecurityContext / SecurityContext compliance
ALLOW_ESC=$(kubectl get deployment secure-app -n secure-app-ns -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null || true)
RUN_NON_ROOT=$(kubectl get deployment secure-app -n secure-app-ns -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null || true)
CONTAINER_NON_ROOT=$(kubectl get deployment secure-app -n secure-app-ns -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null || true)

if [ "$ALLOW_ESC" != "false" ] && [ "$RUN_NON_ROOT" != "true" ] && [ "$CONTAINER_NON_ROOT" != "true" ]; then
    echo "ERROR: Deployment 'secure-app' securityContext does not comply with restricted PodSecurityStandard (missing allowPrivilegeEscalation: false or runAsNonRoot: true)."
    exit 1
fi

# 5. Verify NetworkPolicy egress is not empty / blocking all egress
EGRESS_RULES=$(kubectl get netpol secure-netpol -n secure-app-ns -o jsonpath='{.spec.egress}' 2>/dev/null || true)
if [ "$EGRESS_RULES" = "[]" ] || [ -z "$EGRESS_RULES" ]; then
    echo "ERROR: NetworkPolicy 'secure-netpol' in namespace secure-app-ns still has empty egress ([]), blocking all outgoing traffic."
    exit 1
fi

# 6. Check readyReplicas for deployment secure-app (must be >= 1)
READY_REPLICAS=$(kubectl get deployment secure-app -n secure-app-ns -o jsonpath='{.status.readyReplicas}')
if [ -z "$READY_REPLICAS" ]; then
    READY_REPLICAS=0
fi

echo "Current Deployment Ready Replicas: $READY_REPLICAS / 1"

if [ "$READY_REPLICAS" -lt 1 ]; then
    echo "ERROR: Deployment 'secure-app' in namespace secure-app-ns is not ready (1/1 required, actual: $READY_REPLICAS/1)."
    exit 1
fi

echo "SUCCESS: NetworkPolicy, PodSecurity, and ResourceQuota policy conflicts resolved and Deployment 'secure-app' is 1/1 READY!"
exit 0
