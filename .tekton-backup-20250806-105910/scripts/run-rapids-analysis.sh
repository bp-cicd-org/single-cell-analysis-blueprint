#!/bin/bash
# RAPIDS SingleCell Analysis - Smart Parallel Execution
# ===================================================
# Production script implementing 3-phase smart parallel strategy

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
EXECUTION_RUN_NAME="rapids-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"
MODE="${1:-"smart-parallel"}"

show_strategy() {
    log_header "RAPIDS SingleCell Analysis - Smart Parallel Strategy"
    echo "=================================================="
    echo ""
    echo "🎯 Execution Strategy: 3-Phase Smart Parallel"
    echo "  Phase 1: Notebooks 01 + 03 (Parallel Foundation)"
    echo "  Phase 2: Notebooks 02 + 04 (Smart Parallel - 02 waits for 01)"
    echo "  Phase 3: Notebook 05 (Exclusive Multi-GPU)"
    echo ""
    echo "📊 Resource Utilization:"
    echo "  Phase 1: 48GB GPU (15% of 320GB total)"
    echo "  Phase 2: 72GB GPU (22% of 320GB total)"
    echo "  Phase 3: 160GB GPU (50% of 320GB total)"
    echo ""
    echo "⏱️  Expected Time: 6-8 hours (vs 12-15 hours sequential)"
    echo "🌐 Dashboard: ${DASHBOARD_URL}"
    echo ""
}

deploy_pipelines() {
    log_info "📦 Deploying all pipeline components..."
    
    # Deploy all pipelines
    kubectl apply -f .tekton/pipelines/ > /dev/null 2>&1
    
    # Verify deployments
    local pipelines=("rapids-analysis-main-controller" "notebook01-preprocessing-pipeline" "notebook02-extended-pipeline" "notebook03-pearson-pipeline" "notebook04-dask-pipeline" "notebook05-multigpu-pipeline")
    
    for pipeline in "${pipelines[@]}"; do
        if kubectl get pipeline $pipeline -n tekton-pipelines > /dev/null 2>&1; then
            log_success "Pipeline deployed: $pipeline"
        else
            log_error "Pipeline deployment failed: $pipeline"
            exit 1
        fi
    done
}

start_execution() {
    log_header "🚀 Starting Smart Parallel Execution"
    echo "==================================="
    echo "Execution Run: ${EXECUTION_RUN_NAME}"
    echo ""
    
    # Create main controller PipelineRun
    cat > /tmp/main-controller-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: rapids-main-${EXECUTION_RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: rapids-main-controller
    execution.rapids.ai/run: "${EXECUTION_RUN_NAME}"
  annotations:
    description: "RAPIDS SingleCell Analysis - Smart Parallel Execution"
    execution.rapids.ai/strategy: "smart-parallel"
spec:
  pipelineRef:
    name: rapids-analysis-main-controller
    
  params:
  - name: execution-run-name
    value: "${EXECUTION_RUN_NAME}"
  - name: execution-mode
    value: "smart-parallel"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
        
  timeouts:
    pipeline: "10h"
    tasks: "4h"
EOF

    # Submit the main controller
    MAIN_RUN_NAME=$(kubectl create -f /tmp/main-controller-run.yaml -o jsonpath='{.metadata.name}')
    log_success "Main Controller started: ${MAIN_RUN_NAME}"
    
    # Show dashboard link
    echo ""
    log_success "🌐 Dashboard Links:"
    echo "  Main Controller: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${MAIN_RUN_NAME}"
    echo "  All Pipeline Runs: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns"
    echo ""
    
    # Show monitoring commands
    log_info "📊 Monitoring Commands:"
    echo "  kubectl get pipelinerun ${MAIN_RUN_NAME} -n tekton-pipelines -w"
    echo "  kubectl get pipelineruns -n tekton-pipelines -l execution.rapids.ai/run=${EXECUTION_RUN_NAME}"
    echo "  ./.tekton/scripts/dashboard-monitor.sh status"
    echo ""
    
    # Wait for user decision
    read -p "Monitor execution progress? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_execution "${MAIN_RUN_NAME}"
    else
        log_info "Execution started. Monitor progress using the dashboard or commands above."
    fi
    
    # Cleanup
    rm -f /tmp/main-controller-run.yaml
}

monitor_execution() {
    local main_run_name=$1
    
    log_header "📊 Monitoring Execution Progress"
    echo "==============================="
    echo "Main Run: ${main_run_name}"
    echo ""
    
    log_info "⏳ Monitoring execution progress..."
    log_info "Use Ctrl+C to stop monitoring (execution will continue)"
    echo ""
    
    # Monitor with timeout
    if kubectl wait --for=condition=Succeeded pipelinerun/${main_run_name} -n tekton-pipelines --timeout=36000s; then
        log_success "🎉 RAPIDS Analysis completed successfully!"
        
        # Show final status
        echo ""
        log_header "📋 Final Execution Summary"
        kubectl get pipelineruns -n tekton-pipelines -l execution.rapids.ai/run=${EXECUTION_RUN_NAME} -o custom-columns="NOTEBOOK:.metadata.labels.notebook-id,NAME:.metadata.name,STATUS:.status.conditions[0].reason,STARTED:.metadata.creationTimestamp"
        
    elif kubectl wait --for=condition=Failed pipelinerun/${main_run_name} -n tekton-pipelines --timeout=1s; then
        log_error "❌ RAPIDS Analysis failed"
        
        # Show failure details
        log_info "🔍 Failure details:"
        kubectl describe pipelinerun ${main_run_name} -n tekton-pipelines | grep -A 10 "Conditions:" || true
        
    else
        log_warning "⏱️  Execution is taking longer than expected"
        log_info "Continue monitoring with dashboard: ${DASHBOARD_URL}"
    fi
}

show_status() {
    log_header "📊 RAPIDS Analysis Current Status"
    echo "================================"
    
    echo "🔧 Available Pipelines:"
    kubectl get pipelines -n tekton-pipelines | grep -E "(rapids|notebook)" || echo "  No RAPIDS pipelines found"
    
    echo ""
    echo "🏃 Active Executions:"
    kubectl get pipelineruns -n tekton-pipelines -l 'execution.rapids.ai/run' --no-headers | head -10 || echo "  No active executions"
    
    echo ""
    echo "🖥️  GPU Resources:"
    kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | "\(.metadata.name): \(.status.capacity."nvidia.com/gpu") GPUs"' 2>/dev/null || echo "  No GPU information available"
    
    echo ""
    echo "🌐 Dashboard: ${DASHBOARD_URL}"
}

main() {
    case "${MODE}" in
        "smart-parallel")
            show_strategy
            deploy_pipelines
            start_execution
            ;;
        "status")
            show_status
            ;;
        "deploy")
            deploy_pipelines
            log_success "All pipelines deployed successfully"
            ;;
        *)
            echo "Usage: $0 [smart-parallel|status|deploy]"
            echo ""
            echo "Commands:"
            echo "  smart-parallel - Run complete analysis with smart parallel strategy (default)"
            echo "  status         - Show current status"
            echo "  deploy         - Deploy pipelines only"
            echo ""
            echo "🌐 Dashboard: ${DASHBOARD_URL}"
            echo "Login: admin/admin123 or user/user123"
            exit 1
            ;;
    esac
}

main "$@"