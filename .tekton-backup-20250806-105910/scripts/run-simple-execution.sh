#!/bin/bash
# RAPIDS SingleCell Analysis - Simple Sequential Execution
# =======================================================
# Simplified script for reliable sequential execution

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "${PURPLE}🎯 $1${NC}"; }

# Configuration
EXECUTION_RUN_NAME="rapids-simple-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

show_info() {
    log_header "RAPIDS SingleCell Analysis - Simple Sequential Execution"
    echo "======================================================"
    echo ""
    echo "🎯 Execution Strategy: Sequential (Reliable)"
    echo "  01 → 02 → 03 → 04 → 05"
    echo ""
    echo "📊 All notebooks will run one by one for maximum reliability"
    echo "⏱️  Expected Time: 12-15 hours total"
    echo "🌐 Dashboard: ${DASHBOARD_URL}"
    echo ""
}

deploy_pipelines() {
    log_info "📦 Deploying pipeline components..."
    
    # Deploy pipelines
    kubectl apply -f .tekton/pipelines/ > /dev/null 2>&1
    
    # Verify key components
    if kubectl get pipeline rapids-simple-controller -n tekton-pipelines > /dev/null 2>&1; then
        log_success "Simple controller deployed"
    else
        log_error "Simple controller deployment failed"
        exit 1
    fi
    
    if kubectl get task gpu-notebook-executor-task -n tekton-pipelines > /dev/null 2>&1; then
        log_success "Notebook executor task available"
    else
        log_error "Notebook executor task not found"
        exit 1
    fi
}

start_execution() {
    log_header "🚀 Starting Sequential Execution"
    echo "==============================="
    echo "Execution Run: ${EXECUTION_RUN_NAME}"
    echo ""
    
    # Create simple controller PipelineRun
    cat > /tmp/simple-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: rapids-simple-${EXECUTION_RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: rapids-simple-execution
    execution.rapids.ai/run: "${EXECUTION_RUN_NAME}"
  annotations:
    description: "RAPIDS SingleCell Analysis - Simple Sequential Execution"
spec:
  pipelineRef:
    name: rapids-simple-controller
    
  params:
  - name: execution-run-name
    value: "${EXECUTION_RUN_NAME}"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
      
  timeouts:
    pipeline: "16h"
    tasks: "4h"
EOF

    # Submit the pipeline
    MAIN_RUN_NAME=$(kubectl create -f /tmp/simple-run.yaml -o jsonpath='{.metadata.name}')
    log_success "Pipeline started: ${MAIN_RUN_NAME}"
    
    # Show dashboard links
    echo ""
    log_success "🌐 Monitoring Links:"
    echo "  Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${MAIN_RUN_NAME}"
    echo "  Dashboard: ${DASHBOARD_URL}"
    echo ""
    
    # Show monitoring commands
    log_info "📊 CLI Monitoring:"
    echo "  kubectl get pipelinerun ${MAIN_RUN_NAME} -n tekton-pipelines -w"
    echo "  kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${MAIN_RUN_NAME}"
    echo ""
    
    # Wait for user decision
    read -p "Monitor execution progress? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_execution "${MAIN_RUN_NAME}"
    else
        log_info "Execution started. Use dashboard to monitor progress."
        log_info "Pipeline will run for approximately 12-15 hours."
    fi
    
    # Cleanup
    rm -f /tmp/simple-run.yaml
}

monitor_execution() {
    local run_name=$1
    
    log_header "📊 Monitoring Execution"
    echo "======================"
    echo "Pipeline: ${run_name}"
    echo ""
    
    log_info "⏳ Waiting for pipeline completion..."
    log_info "This will take 12-15 hours. Use Ctrl+C to stop monitoring."
    echo ""
    
    # Monitor with extended timeout
    if kubectl wait --for=condition=Succeeded pipelinerun/${run_name} -n tekton-pipelines --timeout=57600s; then
        log_success "🎉 All 5 notebooks completed successfully!"
        
        # Show final results
        echo ""
        log_header "📋 Execution Results"
        kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${run_name} -o custom-columns="TASK:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason,DURATION:.status.completionTime"
        
    elif kubectl wait --for=condition=Failed pipelinerun/${run_name} -n tekton-pipelines --timeout=1s; then
        log_error "❌ Pipeline execution failed"
        
        # Show failure details
        log_info "🔍 Checking failure details..."
        kubectl describe pipelinerun ${run_name} -n tekton-pipelines | grep -A 10 "Conditions:"
        
        # Show failed tasks
        log_info "Failed tasks:"
        kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${run_name} --field-selector=status.conditions[0].status=False
        
    else
        log_warning "⏱️  Pipeline is still running"
        log_info "Continue monitoring with dashboard: ${DASHBOARD_URL}"
    fi
}

check_status() {
    log_header "📊 Current Status"
    echo "================"
    
    echo "🔧 Available Pipelines:"
    kubectl get pipelines -n tekton-pipelines | grep rapids || echo "  No RAPIDS pipelines found"
    
    echo ""
    echo "🏃 Active Pipeline Runs:"
    kubectl get pipelineruns -n tekton-pipelines -l 'execution.rapids.ai/run' --no-headers | head -5 || echo "  No active executions"
    
    echo ""
    echo "🖥️  GPU Resources:"
    kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | "\(.metadata.name): \(.status.capacity."nvidia.com/gpu") GPUs"' 2>/dev/null || echo "  No GPU info available"
    
    echo ""
    echo "💾 Storage:"
    kubectl get pvc source-code-workspace -n tekton-pipelines -o wide 2>/dev/null || echo "  Workspace PVC not found"
    
    echo ""
    echo "🌐 Dashboard: ${DASHBOARD_URL}"
}

main() {
    case "${1:-"run"}" in
        "run")
            show_info
            deploy_pipelines
            start_execution
            ;;
        "status")
            check_status
            ;;
        "deploy")
            deploy_pipelines
            log_success "Pipelines deployed successfully"
            ;;
        *)
            echo "Usage: $0 [run|status|deploy]"
            echo ""
            echo "Commands:"
            echo "  run    - Deploy and run complete analysis (default)"
            echo "  status - Show current status"
            echo "  deploy - Deploy pipelines only"
            echo ""
            echo "🌐 Dashboard: ${DASHBOARD_URL}"
            echo "Login: admin/admin123 or user/user123"
            exit 1
            ;;
    esac
}

main "$@"