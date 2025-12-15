#!/bin/bash
#
# Monitor OpenShift Upgrade Progress
# Continuously monitors nodes and MCPs until upgrade completes
#

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

echo "================================================"
echo "OpenShift Upgrade Progress Monitor"
echo "================================================"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    clear
    echo -e "${BLUE}=== Upgrade Progress Monitor - $(date) ===${NC}\n"

    echo -e "${GREEN}Node Versions:${NC}"
    oc get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[?\(@.type==\"Ready\"\)].status,SCHED:.spec.unschedulable,VERSION:.status.nodeInfo.kubeletVersion 2>/dev/null || echo "Error getting nodes"

    echo ""
    echo -e "${GREEN}MachineConfigPool Status:${NC}"
    oc get mcp -o custom-columns=NAME:.metadata.name,UPDATED:.status.updatedMachineCount,TOTAL:.status.machineCount,READY:.status.readyMachineCount,DEGRADED:.status.degradedMachineCount 2>/dev/null || echo "Error getting MCPs"

    echo ""
    echo -e "${GREEN}Cluster Operators (degraded/progressing):${NC}"
    oc get co 2>/dev/null | grep -E 'NAME|False|True.*True' | head -10 || echo "Error getting cluster operators"

    echo ""
    echo -e "${GREEN}machine-config-daemon Pods:${NC}"
    oc get pods -n openshift-machine-config-operator 2>/dev/null | grep daemon | awk '{printf "%-50s %s/%s %s %s\n", $1, $2, $2, $3, $5}' || echo "Error getting daemon pods"

    echo ""
    echo -e "${YELLOW}Waiting 30 seconds before next check...${NC}"
    sleep 30
done
