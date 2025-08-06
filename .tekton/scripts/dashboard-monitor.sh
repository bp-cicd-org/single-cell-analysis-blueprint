#!/bin/bash
# Dashboard Monitor for RAPIDS SingleCell Analysis Pipeline
# ========================================================
# Provides easy access to Tekton dashboard and monitoring tools

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Dashboard configuration
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${PURPLE}🎯 $1${NC}"
}

show_dashboard_info() {
    log_header "RAPIDS SingleCell Analysis - Dashboard Monitor"
    echo "=============================================="
    echo ""
    log_success "Production Tekton Dashboard Available:"
    echo "  🌐 URL: ${DASHBOARD_URL}"
    echo ""
    log_info "Dashboard Features:"
    echo "  • Real-time pipeline monitoring"
    echo "  • Task execution logs"
    echo "  • Resource usage tracking"
    echo "  • Error diagnosis"
    echo "  • Historical pipeline runs"
    echo ""
}

show_current_pipelines() {
    log_info "📋 Current Pipeline Runs:"
    echo ""
    
    # Get all pipeline runs
    RUNS=$(kubectl get pipelineruns -n tekton-pipelines --no-headers 2>/dev/null || echo "")
    
    if [ -z "$RUNS" ]; then
        log_warning "No active pipeline runs found"
    else
        echo "Active Pipeline Runs:"
        kubectl get pipelineruns -n tekton-pipelines -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[0].reason,STARTED:.metadata.creationTimestamp,PIPELINE:.spec.pipelineRef.name" --no-headers | while read line; do
            name=$(echo $line | awk '{print $1}')
            status=$(echo $line | awk '{print $2}')
            started=$(echo $line | awk '{print $3}')
            pipeline=$(echo $line | awk '{print $4}')
            
            echo "  📊 $name"
            echo "     Status: $status"
            echo "     Pipeline: $pipeline"
            echo "     Started: $started"
            echo "     🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/$name"
            echo ""
        done
    fi
}

show_notebook_pipeline_status() {
    log_info "🔬 RAPIDS Notebook Pipeline Status:"
    echo ""
    
    # Check for our specific pipelines
    RAPIDS_RUNS=$(kubectl get pipelineruns -n tekton-pipelines -l 'app.kubernetes.io/name in (test-notebook01-standalone,test-master-controller,complete-scrna-analysis)' --no-headers 2>/dev/null || echo "")
    
    if [ -z "$RAPIDS_RUNS" ]; then
        log_warning "No RAPIDS notebook pipeline runs found"
        echo ""
        log_info "Available RAPIDS pipelines:"
        kubectl get pipelines -n tekton-pipelines | grep -E "(notebook|master|complete|scrna)" || echo "  No RAPIDS pipelines found"
    else
        echo "RAPIDS Pipeline Runs:"
        kubectl get pipelineruns -n tekton-pipelines -l 'app.kubernetes.io/name in (test-notebook01-standalone,test-master-controller,complete-scrna-analysis)' -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[0].reason,NOTEBOOK:.metadata.labels.notebook\.rapids\.ai/id,TYPE:.metadata.labels.test\.rapids\.ai/type,STARTED:.metadata.creationTimestamp" --no-headers | while read line; do
            name=$(echo $line | awk '{print $1}')
            status=$(echo $line | awk '{print $2}')
            notebook=$(echo $line | awk '{print $3}')
            type=$(echo $line | awk '{print $4}')
            started=$(echo $line | awk '{print $5}')
            
            echo "  📔 $name"
            echo "     Status: $status"
            echo "     Notebook: ${notebook:-"N/A"}"
            echo "     Type: ${type:-"N/A"}"
            echo "     Started: $started"
            echo "     🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/$name"
            echo ""
        done
    fi
}

check_gpu_resources() {
    log_info "🖥️  GPU Resource Status:"
    echo ""
    
    # Check GPU nodes
    GPU_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.capacity."nvidia.com/gpu" != null) | .metadata.name' 2>/dev/null || echo "")
    
    if [ -z "$GPU_NODES" ]; then
        log_error "No GPU nodes found in cluster"
    else
        echo "GPU Nodes:"
        echo "$GPU_NODES" | while read node; do
            if [ -n "$node" ]; then
                total_gpu=$(kubectl get node $node -o json | jq -r '.status.capacity."nvidia.com/gpu"' 2>/dev/null || echo "0")
                alloc_gpu=$(kubectl get node $node -o json | jq -r '.status.allocatable."nvidia.com/gpu"' 2>/dev/null || echo "0")
                echo "  🔧 $node: $alloc_gpu/$total_gpu GPUs available"
            fi
        done
    fi
    echo ""
    
    # Check GPU usage
    log_info "Current GPU allocation in tekton-pipelines namespace:"
    kubectl get pods -n tekton-pipelines -o json | jq -r '.items[] | select(.spec.containers[]?.resources.requests."nvidia.com/gpu" != null) | "\(.metadata.name): \(.spec.containers[0].resources.requests."nvidia.com/gpu") GPU(s)"' 2>/dev/null || echo "  No GPU-consuming pods found"
}

show_troubleshooting_info() {
    log_header "🔧 Troubleshooting Information"
    echo ""
    
    # Check service account
    log_info "Service Account Status:"
    if kubectl get serviceaccount tekton-gpu-executor -n tekton-pipelines > /dev/null 2>&1; then
        log_success "tekton-gpu-executor service account exists"
    else
        log_error "tekton-gpu-executor service account not found"
        log_info "Run: kubectl apply -f .tekton/configs/tekton-gpu-serviceaccount.yaml"
    fi
    
    # Check recent events
    log_info "Recent Events in tekton-pipelines namespace:"
    kubectl get events -n tekton-pipelines --sort-by='.lastTimestamp' | tail -5
    
    echo ""
    log_info "For detailed troubleshooting, see:"
    echo "  📖 .tekton/docs/TROUBLESHOOTING.md"
}

monitor_specific_run() {
    local run_name=$1
    
    if [ -z "$run_name" ]; then
        log_error "Please provide a pipeline run name"
        echo "Usage: $0 monitor <pipeline-run-name>"
        return 1
    fi
    
    log_header "Monitoring Pipeline Run: $run_name"
    echo ""
    
    # Check if run exists
    if ! kubectl get pipelinerun $run_name -n tekton-pipelines > /dev/null 2>&1; then
        log_error "Pipeline run '$run_name' not found"
        return 1
    fi
    
    # Show current status
    log_info "Current Status:"
    kubectl get pipelinerun $run_name -n tekton-pipelines -o wide
    echo ""
    
    # Show dashboard link
    log_success "Dashboard Link:"
    echo "  🌐 ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/$run_name"
    echo ""
    
    # Show related tasks
    log_info "Related Tasks:"
    kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=$run_name -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[0].reason,STARTED:.metadata.creationTimestamp" --no-headers | while read line; do
        if [ -n "$line" ]; then
            task_name=$(echo $line | awk '{print $1}')
            task_status=$(echo $line | awk '{print $2}')
            task_started=$(echo $line | awk '{print $3}')
            echo "  🔧 $task_name: $task_status (started: $task_started)"
        fi
    done
    
    echo ""
    log_info "Monitor commands:"
    echo "  kubectl get pipelinerun $run_name -n tekton-pipelines -w"
    echo "  kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=$run_name -f"
}

open_dashboard() {
    log_info "Opening Tekton Dashboard..."
    echo ""
    log_success "Dashboard URL: ${DASHBOARD_URL}"
    echo ""
    log_info "If you can't access the dashboard, check:"
    echo "1. Network connectivity to 10.34.2.129"
    echo "2. DNS resolution for tekton.10.34.2.129.nip.io"
    echo "3. Ingress controller status"
    echo ""
    
    # Try to open in browser (if available)
    if command -v xdg-open > /dev/null 2>&1; then
        xdg-open "${DASHBOARD_URL}" 2>/dev/null &
    elif command -v open > /dev/null 2>&1; then
        open "${DASHBOARD_URL}" 2>/dev/null &
    else
        log_info "Manual open required: ${DASHBOARD_URL}"
    fi
}

main() {
    case "${1:-"status"}" in
        "status"|"")
            show_dashboard_info
            show_current_pipelines
            show_notebook_pipeline_status
            check_gpu_resources
            ;;
        "monitor")
            monitor_specific_run "${2:-}"
            ;;
        "troubleshoot")
            show_troubleshooting_info
            ;;
        "open"|"dashboard")
            open_dashboard
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  status        - Show overall status (default)"
            echo "  monitor <run> - Monitor specific pipeline run"
            echo "  troubleshoot  - Show troubleshooting information"
            echo "  open          - Open dashboard in browser"
            echo "  help          - Show this help"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"