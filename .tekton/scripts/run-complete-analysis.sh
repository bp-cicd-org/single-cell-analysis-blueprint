#!/bin/bash
# RAPIDS SingleCell Analysis - Complete Workflow Launcher
# =====================================================
# Cloud-native Tekton-based execution of all 7 notebooks

set -e

# Configuration
NAMESPACE="tekton-pipelines"
PIPELINE_NAME="complete-scrna-analysis-workflow"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PIPELINERUN_FILE="${PROJECT_ROOT}/.tekton/pipelineruns/complete-analysis-pipelinerun.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}"
    echo "🚀 RAPIDS SingleCell Analysis - Complete Workflow"
    echo "================================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        echo "Please configure kubectl to connect to your cluster"
        exit 1
    fi
    
    # Check if tekton-pipelines namespace exists
    if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
        print_error "Tekton Pipelines namespace not found: ${NAMESPACE}"
        echo "Please install Tekton Pipelines first:"
        echo "  kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

install_tasks_and_pipelines() {
    print_status "Installing/updating Tekton tasks and pipelines..."
    
    cd "${PROJECT_ROOT}"
    
    # Install tasks
    print_status "Installing tasks..."
    kubectl apply -f .tekton/tasks/ -n "${NAMESPACE}"
    
    # Install pipelines  
    print_status "Installing pipelines..."
    kubectl apply -f .tekton/pipelines/ -n "${NAMESPACE}"
    
    # Install configurations
    print_status "Installing configurations..."
    if [ -d ".tekton/configs" ]; then
        kubectl apply -f .tekton/configs/ -n "${NAMESPACE}"
    fi
    
    # Wait for resources to be ready
    print_status "Waiting for resources to be ready..."
    sleep 5
    
    print_success "Tasks and pipelines installed successfully"
}

validate_system() {
    print_status "Running system validation..."
    
    # Create a validation PipelineRun
    VALIDATION_RUN_NAME="system-validation-$(date +%Y%m%d-%H%M%S)"
    
    cat > "/tmp/validation-pipelinerun.yaml" << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: ${VALIDATION_RUN_NAME}
  namespace: ${NAMESPACE}
spec:
  pipelineSpec:
    workspaces:
    - name: shared-storage
    tasks:
    - name: validate-system
      taskRef:
        name: system-validation-task
      params:
      - name: min-gpu-count
        value: "1"
      - name: min-gpu-memory-gb  
        value: "24"
      - name: required-storage-gb
        value: "100"
      workspaces:
      - name: shared-storage
        workspace: shared-storage
  workspaces:
  - name: shared-storage
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
EOF
    
    kubectl apply -f "/tmp/validation-pipelinerun.yaml"
    
    print_status "Waiting for validation to complete..."
    kubectl wait --for=condition=Succeeded pipelinerun "${VALIDATION_RUN_NAME}" -n "${NAMESPACE}" --timeout=300s
    
    # Get validation results
    VALIDATION_STATUS=$(kubectl get pipelinerun "${VALIDATION_RUN_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[0].reason}')
    
    if [ "${VALIDATION_STATUS}" = "Succeeded" ]; then
        print_success "System validation passed"
    else
        print_error "System validation failed"
        echo "Check validation logs:"
        echo "  kubectl logs -n ${NAMESPACE} -l tekton.dev/pipelineRun=${VALIDATION_RUN_NAME}"
        exit 1
    fi
    
    # Cleanup validation run
    kubectl delete pipelinerun "${VALIDATION_RUN_NAME}" -n "${NAMESPACE}" --ignore-not-found=true
    rm -f "/tmp/validation-pipelinerun.yaml"
}

start_complete_analysis() {
    print_status "Starting complete analysis workflow..."
    
    # Generate unique run name
    RUN_NAME="complete-analysis-$(date +%Y%m%d-%H%M%S)"
    
    # Create temporary PipelineRun with unique name
    TEMP_PIPELINERUN="/tmp/${RUN_NAME}-pipelinerun.yaml"
    cp "${PIPELINERUN_FILE}" "${TEMP_PIPELINERUN}"
    
    # Update the name in the temporary file
    sed -i "s/generateName: complete-scrna-analysis-/name: ${RUN_NAME}/" "${TEMP_PIPELINERUN}"
    sed -i "s/complete-analysis-\$(date +%Y%m%d-%H%M%S)/${RUN_NAME}/" "${TEMP_PIPELINERUN}"
    
    # Submit the PipelineRun
    kubectl apply -f "${TEMP_PIPELINERUN}" -n "${NAMESPACE}"
    
    print_success "Pipeline run submitted: ${RUN_NAME}"
    echo ""
    print_status "You can monitor the execution with:"
    echo "  kubectl get pipelinerun ${RUN_NAME} -n ${NAMESPACE} -w"
    echo ""
    print_status "View logs with:"
    echo "  kubectl logs -n ${NAMESPACE} -l tekton.dev/pipelineRun=${RUN_NAME} -f"
    echo ""
    print_status "Or use Tekton Dashboard if available:"
    echo "  kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097"
    echo "  Open: http://localhost:9097"
    
    # Cleanup temp file
    rm -f "${TEMP_PIPELINERUN}"
    
    return 0
}

monitor_execution() {
    print_status "Monitoring latest pipeline execution..."
    
    # Find the latest PipelineRun
    LATEST_RUN=$(kubectl get pipelinerun -n "${NAMESPACE}" \
        -l app.kubernetes.io/name=complete-scrna-analysis \
        --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null)
    
    if [ -z "${LATEST_RUN}" ]; then
        print_error "No complete analysis pipeline runs found"
        exit 1
    fi
    
    print_status "Monitoring pipeline run: ${LATEST_RUN}"
    
    # Watch the PipelineRun status
    kubectl get pipelinerun "${LATEST_RUN}" -n "${NAMESPACE}" -w
}

show_status() {
    print_status "Current pipeline runs status:"
    echo ""
    
    kubectl get pipelinerun -n "${NAMESPACE}" \
        -l app.kubernetes.io/name=complete-scrna-analysis \
        --sort-by=.metadata.creationTimestamp
    
    echo ""
    print_status "Available commands:"
    echo "  kubectl logs -n ${NAMESPACE} -l tekton.dev/pipelineRun=<run-name> -f"
    echo "  kubectl describe pipelinerun <run-name> -n ${NAMESPACE}"
    echo "  kubectl delete pipelinerun <run-name> -n ${NAMESPACE}"
}

cleanup_runs() {
    print_status "Cleaning up old pipeline runs..."
    
    # Keep only the last 5 runs
    kubectl get pipelinerun -n "${NAMESPACE}" \
        -l app.kubernetes.io/name=complete-scrna-analysis \
        --sort-by=.metadata.creationTimestamp \
        -o name | head -n -5 | xargs -r kubectl delete -n "${NAMESPACE}"
    
    print_success "Cleanup completed"
}

show_help() {
    print_header
    echo "Cloud-native execution of all RAPIDS SingleCell Analysis notebooks"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install     Install/update Tekton tasks and pipelines"
    echo "  validate    Run system validation only"
    echo "  run         Start complete analysis workflow (default)"
    echo "  monitor     Monitor latest pipeline execution"
    echo "  status      Show current pipeline runs status"
    echo "  cleanup     Clean up old pipeline runs"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Run complete workflow with prerequisites check"
    echo "  $0 install        # Install tasks and pipelines only"
    echo "  $0 validate       # Validate system requirements"
    echo "  $0 monitor        # Monitor latest execution"
    echo ""
    echo "Requirements:"
    echo "  - Kubernetes cluster with GPU nodes"
    echo "  - Tekton Pipelines installed"
    echo "  - kubectl configured"
    echo "  - 3x A100 80GB GPUs recommended"
    echo ""
    echo "Notebooks executed (in order):"
    echo "  1. 01_scRNA_analysis_preprocessing.ipynb (24GB GPU)"
    echo "  2. 02_scRNA_analysis_extended.ipynb (24GB GPU)"
    echo "  3. 03_scRNA_analysis_with_pearson_residuals.ipynb (24GB GPU)"
    echo "  4. 06_scRNA_analysis_90k_brain_example.ipynb (24GB GPU)"
    echo "  5. 04_scRNA_analysis_dask_out_of_core.ipynb (48GB GPU)"
    echo "  6. 07_scRNA_analysis_1.3M_brain_example.ipynb (80GB GPU)"
    echo "  7. 05_scRNA_analysis_multi_GPU.ipynb (Multiple 80GB GPUs)"
    echo ""
    echo "Estimated execution time: 4-8 hours"
    echo ""
    echo "Documentation: ${PROJECT_ROOT}/.tekton/docs/EXECUTION_GUIDE.md"
}

main() {
    case "${1:-run}" in
        "install")
            print_header
            check_prerequisites
            install_tasks_and_pipelines
            ;;
        "validate")
            print_header
            check_prerequisites
            install_tasks_and_pipelines
            validate_system
            ;;
        "run")
            print_header
            check_prerequisites
            install_tasks_and_pipelines
            validate_system
            start_complete_analysis
            ;;
        "monitor")
            monitor_execution
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup_runs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"