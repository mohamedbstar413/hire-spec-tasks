#!/bin/bash
set -e

echo "=== Kubernetes Lab Verification: Service Intermittent 502 Bad Gateway ==="

# Set KUBECONFIG if k3s is used
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# 1. Verify cluster connection
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Unable to communicate with Kubernetes cluster."
    exit 1
fi

# 2. Check if Service web-api-service exists
if ! kubectl get service web-api-service -n default >/dev/null 2>&1; then
    echo "ERROR: Service 'web-api-service' not found in default namespace."
    exit 1
fi

# 3. Get Service ClusterIP
SERVICE_IP=$(kubectl get service web-api-service -n default -o jsonpath='{.spec.clusterIP}')
if [ -z "$SERVICE_IP" ]; then
    echo "ERROR: Unable to retrieve ClusterIP for 'web-api-service'."
    exit 1
fi

echo "Testing ClusterIP Service http://$SERVICE_IP with 20 sequential requests..."

# 4. Perform 20 HTTP requests to verify 100% success rate (0% 502 Bad Gateway)
SUCCESS_COUNT=0
FAIL_COUNT=0

for i in {1..20}; do
    # Run curl directly or via kubectl exec/run
    HTTP_CODE=$(kubectl run test-curl-$i --rm -i --quiet --restart=Never --image=curlimages/curl -- curl -s -o /dev/null -w "%{http_code}" http://web-api-service 2>/dev/null || true)
    
    # Fallback to direct curl if cluster IP reachable directly
    if [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" = "000" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$SERVICE_IP" 2>/dev/null || true)
    fi

    if [ "$HTTP_CODE" = "200" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "Request $i failed with HTTP status code: '$HTTP_CODE'"
    fi
done

echo "Test Summary: $SUCCESS_COUNT Successful (200 OK), $FAIL_COUNT Failed."

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "ERROR: Detected $FAIL_COUNT failed request(s) returning 502 or non-200 status codes."
    exit 1
fi

# 5. Check Service selector to ensure broken-canary is not included in endpoints
ENDPOINTS=$(kubectl get endpoints web-api-service -n default -o jsonpath='{.subsets[*].addresses[*].targetRef.name}' 2>/dev/null || true)
if echo "$ENDPOINTS" | grep -q "broken-canary"; then
    echo "ERROR: Service endpoints still include pod from 'web-api-broken-canary'."
    exit 1
fi

echo "SUCCESS: Intermittent 502 Bad Gateway issue resolved! 100% of requests to 'web-api-service' returned 200 OK!"
exit 0
