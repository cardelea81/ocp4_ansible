#!/bin/bash
#
# OpenShift Upgrade Recovery Script
# Fixes stuck MachineConfigPool by uncordoning nodes and letting MCO orchestrate properly
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

section() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Check if oc is available
if ! command -v oc &> /dev/null; then
    error "oc command not found. Please ensure you're logged into OpenShift."
    exit 1
fi

echo "================================================"
echo "OpenShift Upgrade Recovery"
echo "================================================"
echo ""
warning "This script will uncordon stuck nodes and let MCO handle the upgrade properly"
echo ""

section "1. Current Status Check"
info "Cluster Operators (degraded only):"
oc get co | grep -E "NAME|True.*True|True.*False" || echo "All operators healthy"

echo ""
info "Node Status:"
oc get nodes

echo ""
info "MachineConfigPool Status:"
oc get mcp

echo ""
info "PodDisruptionBudgets with 0 allowed disruptions:"
oc get pdb -A | grep -E "NAME|0\s*24d|0\s*2d" | head -10

section "2. Root Cause Analysis"
warning "Problem identified:"
echo "  - All master nodes are cordoned (SchedulingDisabled)"
echo "  - PDBs require 2 instances of critical pods (etcd-guard, kube-apiserver-guard, etc.)"
echo "  - MCO cannot drain nodes because all are cordoned simultaneously"
echo "  - Drain times out after 1 hour due to PDB violations"
echo ""
info "Solution:"
echo "  - Uncordon all nodes to allow sequential draining"
echo "  - MCO will cordon and drain nodes one at a time"
echo "  - This respects PDBs and completes the upgrade"

section "3. Pre-Flight Checks"
info "Checking if nodes are cordoned..."

CORDONED_MASTERS=$(oc get nodes -o json | jq -r '.items[] | select(.spec.unschedulable==true and (.metadata.labels."node-role.kubernetes.io/master"!=null)) | .metadata.name')
CORDONED_WORKERS=$(oc get nodes -o json | jq -r '.items[] | select(.spec.unschedulable==true and (.metadata.labels."node-role.kubernetes.io/worker"!=null)) | .metadata.name')

echo "Cordoned master nodes:"
echo "$CORDONED_MASTERS"
echo ""
echo "Cordoned worker nodes:"
echo "$CORDONED_WORKERS"

if [ -z "$CORDONED_MASTERS" ] && [ -z "$CORDONED_WORKERS" ]; then
    warning "No cordoned nodes found. The issue may have resolved itself."
    exit 0
fi

section "4. Recovery Actions"
echo ""
read -p "Do you want to proceed with uncordoning nodes? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    warning "Operation cancelled by user"
    exit 0
fi

# Uncordon master nodes
if [ -n "$CORDONED_MASTERS" ]; then
    info "Uncordoning master nodes..."
    for node in $CORDONED_MASTERS; do
        echo "  - Uncordoning $node"
        oc adm uncordon "$node"
    done
    success "Master nodes uncordoned"
fi

# Uncordon worker nodes
if [ -n "$CORDONED_WORKERS" ]; then
    info "Uncordoning worker nodes..."
    for node in $CORDONED_WORKERS; do
        echo "  - Uncordoning $node"
        oc adm uncordon "$node"
    done
    success "Worker nodes uncordoned"
fi

section "5. Trigger MCO Reconciliation"
info "Deleting machine-config-daemon pods to trigger immediate reconciliation..."

# Get all MCD pods
MCD_PODS=$(oc get pods -n openshift-machine-config-operator -o name | grep machine-config-daemon)

for pod in $MCD_PODS; do
    node=$(oc get $pod -n openshift-machine-config-operator -o jsonpath='{.spec.nodeName}')
    echo "  - Restarting daemon on $node"
    oc delete $pod -n openshift-machine-config-operator --grace-period=30 &
done

wait
success "Machine-config-daemon pods restarted"

section "6. Post-Recovery Monitoring"
echo ""
info "Waiting 30 seconds for pods to restart..."
sleep 30

echo ""
info "Current node status:"
oc get nodes

echo ""
info "Current MCP status:"
oc get mcp

echo ""
info "Machine-config-daemon pods:"
oc get pods -n openshift-machine-config-operator | grep daemon

section "7. Next Steps"
echo ""
success "Recovery actions completed!"
echo ""
echo "The MCO should now be able to update nodes sequentially."
echo ""
echo "Monitor progress with:"
echo "  - watch oc get nodes"
echo "  - watch oc get mcp"
echo "  - oc get co | grep -E 'NAME|False|True.*True'"
echo ""
echo "Expected behavior:"
echo "  1. MCO will cordon ONE node at a time"
echo "  2. Drain the node (respecting PDBs)"
echo "  3. Apply the new MachineConfig"
echo "  4. Reboot the node"
echo "  5. Uncordon and move to the next node"
echo ""
info "Upgrade should complete in 1-2 hours for all nodes"
echo ""
warning "If nodes remain stuck after 30 minutes, check machine-config-controller logs:"
echo "  oc logs -n openshift-machine-config-operator deployment/machine-config-controller"
echo ""
