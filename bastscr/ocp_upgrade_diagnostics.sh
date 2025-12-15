#!/bin/bash
#
# OpenShift Upgrade Diagnostics Script
# Checks stuck MachineConfigPool and identifies blocking issues
#

set -e

echo "================================================"
echo "OpenShift Upgrade Diagnostics"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

section() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

subsection() {
    echo -e "\n${YELLOW}--- $1 ---${NC}\n"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Check if oc is available
if ! command -v oc &> /dev/null; then
    error "oc command not found. Please ensure you're logged into OpenShift."
    exit 1
fi

section "1. Cluster Operators Status"
oc get co | grep -E 'NAME|False|True.*True|True.*False'

section "2. Node Status"
oc get nodes -o wide

section "3. MachineConfigPool Status"
oc get mcp

section "4. Detailed MachineConfigPool - Master"
oc describe mcp master | grep -A 20 "Status:"

section "5. Detailed MachineConfigPool - Worker"
oc describe mcp worker | grep -A 20 "Status:"

section "6. Machine-Config-Daemon Pods Status"
oc get pods -n openshift-machine-config-operator -o wide | grep daemon

section "7. PodDisruptionBudgets (All Namespaces)"
oc get pdb -A

section "8. Pods on master-1.ocp.lab.example.com"
subsection "Running Pods (excluding Completed)"
oc get pods -A -o wide --field-selector spec.nodeName=master-1.ocp.lab.example.com | grep -v Completed || echo "No pods found"

section "9. Pods on master-3.ocp.lab.example.com"
subsection "Running Pods (excluding Completed)"
oc get pods -A -o wide --field-selector spec.nodeName=master-3.ocp.lab.example.com | grep -v Completed || echo "No pods found"

section "10. Pods on worker-2.ocp.lab.example.com"
subsection "Running Pods (excluding Completed)"
oc get pods -A -o wide --field-selector spec.nodeName=worker-2.ocp.lab.example.com | grep -v Completed || echo "No pods found"

section "11. Machine-Config-Daemon Logs - master-1"
subsection "Last 50 lines focusing on drain issues"
POD_MASTER1=$(oc get pods -n openshift-machine-config-operator -o wide | grep master-1 | grep daemon | awk '{print $1}')
if [ -n "$POD_MASTER1" ]; then
    oc logs -n openshift-machine-config-operator $POD_MASTER1 --tail=50 | grep -i -A 5 -B 5 drain || echo "No drain-related logs found"
else
    error "Could not find machine-config-daemon pod for master-1"
fi

section "12. Machine-Config-Daemon Logs - master-3"
subsection "Last 50 lines focusing on drain issues"
POD_MASTER3=$(oc get pods -n openshift-machine-config-operator -o wide | grep master-3 | grep daemon | awk '{print $1}')
if [ -n "$POD_MASTER3" ]; then
    oc logs -n openshift-machine-config-operator $POD_MASTER3 --tail=50 | grep -i -A 5 -B 5 drain || echo "No drain-related logs found"
else
    error "Could not find machine-config-daemon pod for master-3"
fi

section "13. Machine-Config-Daemon Logs - worker-2"
subsection "Last 50 lines focusing on drain issues"
POD_WORKER2=$(oc get pods -n openshift-machine-config-operator -o wide | grep worker-2 | grep daemon | awk '{print $1}')
if [ -n "$POD_WORKER2" ]; then
    oc logs -n openshift-machine-config-operator $POD_WORKER2 --tail=50 | grep -i -A 5 -B 5 drain || echo "No drain-related logs found"
else
    error "Could not find machine-config-daemon pod for worker-2"
fi

section "14. Machine-Config-Controller Logs"
subsection "Last 100 lines"
POD_CONTROLLER=$(oc get pods -n openshift-machine-config-operator | grep machine-config-controller | head -1 | awk '{print $1}')
if [ -n "$POD_CONTROLLER" ]; then
    oc logs -n openshift-machine-config-operator $POD_CONTROLLER --tail=100 | grep -i -E "drain|error|fail" || echo "No relevant errors found"
else
    error "Could not find machine-config-controller pod"
fi

section "15. Certificate Signing Requests"
oc get csr | tail -10

section "16. Summary of Stuck Nodes"
echo ""
echo "Master Pool:"
echo "  - Target Config: rendered-master-7dc9b73dfe8a9dd85d159ca4597357d9"
echo "  - Current Config: rendered-master-4e863049e6333b9f9f3ef99004041b20"
echo ""
echo "Worker Pool:"
echo "  - Target Config: rendered-worker-e093e17e07595b0708bd41368c870dbb"
echo "  - Current Config: rendered-worker-c55776763dc886cd5d424ff2dd7e4b23"
echo ""
echo "Nodes requiring update:"
echo "  - master-1.ocp.lab.example.com (v1.31.8 -> v1.31.13)"
echo "  - master-3.ocp.lab.example.com (v1.31.8 -> v1.31.13)"
echo "  - worker-2.ocp.lab.example.com (v1.31.8 -> v1.31.13)"
echo ""

section "Diagnostics Complete"
echo "Review the output above to identify blocking issues."
echo ""
echo "Common fixes:"
echo "  1. Identify and delete problematic pods blocking drain"
echo "  2. Adjust or delete blocking PodDisruptionBudgets"
echo "  3. Force uncordon nodes: oc adm uncordon <node>"
echo "  4. Restart machine-config-daemon pods"
echo "  5. As last resort, pause MCP and manually update nodes"
echo ""
