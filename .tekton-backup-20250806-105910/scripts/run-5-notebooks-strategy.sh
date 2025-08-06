#!/bin/bash
# RAPIDS SingleCell Analysis - 5 Notebooks Execution Strategy
# =========================================================

set -euo pipefail

EXECUTION_STRATEGY="${1:-smart-parallel}"
RUN_NAME="rapids-5nb-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🚀 RAPIDS SingleCell Analysis - 5 Notebooks Strategy"
echo "=================================================="
echo "Strategy: ${EXECUTION_STRATEGY}"
echo "Run Name: ${RUN_NAME}"
echo "Dashboard: ${DASHBOARD_URL}"
echo ""

echo "📋 Execution Plan:"
echo "=================="
echo "Phase 1: Notebook 01 (Prerequisites & Preprocessing)"
echo "Phase 2: Notebooks 02 & 03 (Extended Analysis & Pearson Residuals) - Parallel"
echo "Phase 3: Notebook 04 (Dask Out-of-Core)"
echo "Phase 4: Notebook 05 (Multi-GPU) - Exclusive"
echo ""
echo "📊 Each notebook goes through complete 9-step workflow:"
echo "  1. Environment Setup → 2. Git Clone → 3. Dataset Download"
echo "  4. Papermill Execution → 5. NBConvert → 6. Test Framework"
echo "  7. Pytest → 8. Collect Artifacts → 9. Final Summary"
echo ""

# Deploy updated pipeline
echo "📦 Deploying 5-Notebooks Strategy Pipeline..."
kubectl apply -f .tekton/pipelines/complete-notebook-workflow.yaml -n tekton-pipelines > /dev/null
kubectl apply -f .tekton/pipelines/rapids-5-notebooks-strategy.yaml -n tekton-pipelines > /dev/null

# Create PipelineRun
cat > /tmp/5-notebooks-strategy-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: rapids-5nb-${RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: rapids-5-notebooks-strategy
    execution.rapids.ai/run: "${RUN_NAME}"
    execution.rapids.ai/strategy: "${EXECUTION_STRATEGY}"
  annotations:
    description: "RAPIDS 5-Notebooks Complete Strategy Execution"
    execution.tekton.dev/estimated-duration: "8h"
    hardware.tekton.dev/gpu-requirement: "4x A100 80GB recommended"
spec:
  pipelineRef:
    name: rapids-5-notebooks-strategy
    
  params:
  - name: execution-run-name
    value: "${RUN_NAME}"
  - name: execution-strategy
    value: "${EXECUTION_STRATEGY}"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
      
  timeouts:
    pipeline: "12h"
    tasks: "3h"
EOF

# Submit the execution
PIPELINE_RUN_NAME=$(kubectl create -f /tmp/5-notebooks-strategy-run.yaml -o jsonpath='{.metadata.name}')

echo "✅ 5-Notebooks Strategy started: ${PIPELINE_RUN_NAME}"
echo ""
echo "🌐 Monitoring Links:"
echo "  Main Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
echo "  Dashboard: ${DASHBOARD_URL}"
echo ""
echo "📊 CLI Monitoring:"
echo "  kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines -w"
echo "  kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME}"
echo ""

# Function to show execution status
show_execution_status() {
    echo "📊 5-Notebooks Execution Status:"
    echo "==============================="
    
    # Get all task runs for this pipeline
    echo "Current Tasks:"
    kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME} \
        -o custom-columns="NOTEBOOK:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason,START:.status.startTime" \
        --sort-by=.status.startTime 2>/dev/null || echo "No tasks started yet"
    echo ""
    
    # Show notebook progress
    NOTEBOOKS=("notebook01" "notebook02" "notebook03" "notebook04" "notebook05")
    for nb in "${NOTEBOOKS[@]}"; do
        STATUS=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME} -l tekton.dev/pipelineTask=${nb}-complete-workflow -o jsonpath='{.items[0].status.conditions[0].reason}' 2>/dev/null || echo "Pending")
        case $STATUS in
            "Succeeded") echo "✅ ${nb}: Completed" ;;
            "Running") echo "🔄 ${nb}: Running" ;;
            "Failed") echo "❌ ${nb}: Failed" ;;
            *) echo "⏳ ${nb}: Pending" ;;
        esac
    done
    echo ""
}

# Ask if user wants to monitor
read -p "Monitor execution progress? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🎯 📊 Monitoring 5-Notebooks Strategy Execution"
    echo "=============================================="
    echo "Pipeline: ${PIPELINE_RUN_NAME}"
    echo ""
    
    # Monitor with periodic updates
    while true; do
        STATUS=$(kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        if [ "$STATUS" = "Succeeded" ]; then
            echo "✅ 🎉 All 5 notebooks completed successfully!"
            echo ""
            show_execution_status
            
            echo "📊 Final Results Summary:"
            echo "========================"
            kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME} \
                -o custom-columns="TASK:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason,DURATION:.status.completionTime" \
                --sort-by=.status.startTime
            break
            
        elif [ "$STATUS" = "Failed" ]; then
            echo "❌ 5-Notebooks execution failed"
            echo ""
            show_execution_status
            
            # Show failure details
            echo "🔍 Failure details:"
            kubectl describe pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines | grep -A 10 "Conditions:"
            break
            
        else
            echo "⏳ Status: $STATUS - Strategy execution in progress..."
            show_execution_status
            echo "⏰ Next update in 60 seconds..."
            sleep 60
        fi
    done
else
    echo "5-Notebooks Strategy started. Monitor progress using the dashboard links above."
    echo ""
    echo "📋 Execution Details:"
    echo "   Expected duration: 8-12 hours"
    echo "   Total notebooks: 5"
    echo "   Steps per notebook: 9"
    echo "   Total pipeline tasks: 45+ tasks"
    echo ""
    echo "🎯 Key Features:"
    echo "   ✅ Complete 9-step workflow for each notebook"
    echo "   ✅ Smart parallel execution strategy"
    echo "   ✅ PCA compatibility fixes"
    echo "   ✅ Comprehensive testing and artifacts"
    echo "   ✅ HTML conversion and reports"
fi

# Cleanup
rm -f /tmp/5-notebooks-strategy-run.yaml

echo ""
echo "🎯 Access Results:"
echo "  Main Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
echo "  CLI Status: kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines"
echo "  Task Details: kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME}"