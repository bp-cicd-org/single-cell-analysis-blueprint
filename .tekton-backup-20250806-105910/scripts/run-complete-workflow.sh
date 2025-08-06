#!/bin/bash
# Run Complete 9-Step Notebook Workflow
# ====================================

set -euo pipefail

NOTEBOOK_NAME="${1:-01_scRNA_analysis_preprocessing}"
RUN_NAME="complete-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🚀 RAPIDS SingleCell Analysis - Complete 9-Step Workflow"
echo "========================================================"
echo "Notebook: ${NOTEBOOK_NAME}"
echo "Run Name: ${RUN_NAME}"
echo "Dashboard: ${DASHBOARD_URL}"
echo ""
echo "📋 Workflow Steps:"
echo "  1. Container Environment Setup"
echo "  2. Git Clone Blueprint"
echo "  3. Download Scientific Dataset"
echo "  4. Papermill Execution"
echo "  5. NBConvert to HTML"
echo "  6. Git Clone Test Framework"
echo "  7. Pytest Execution"
echo "  8. Collect Artifacts"
echo "  9. Final Summary"
echo ""

# Create PipelineRun
cat > /tmp/complete-workflow-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: complete-${RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: complete-notebook-workflow
    execution.rapids.ai/run: "${RUN_NAME}"
    notebook.rapids.ai/name: "${NOTEBOOK_NAME}"
  annotations:
    description: "Complete 9-step workflow for ${NOTEBOOK_NAME}"
    execution.tekton.dev/estimated-duration: "2h"
spec:
  pipelineRef:
    name: complete-notebook-workflow
    
  params:
  - name: notebook-name
    value: "${NOTEBOOK_NAME}"
  - name: pipeline-run-name
    value: "${RUN_NAME}"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
      
  timeouts:
    pipeline: "3h"
    tasks: "1h"
EOF

# Submit the workflow
PIPELINE_RUN_NAME=$(kubectl create -f /tmp/complete-workflow-run.yaml -o jsonpath='{.metadata.name}')

echo "✅ Complete workflow started: ${PIPELINE_RUN_NAME}"
echo ""
echo "🌐 Monitoring Links:"
echo "  Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
echo "  Dashboard: ${DASHBOARD_URL}"
echo ""
echo "📊 CLI Monitoring:"
echo "  kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines -w"
echo "  kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME}"
echo ""

# Function to show step status
show_step_status() {
    echo "📊 Current Step Status:"
    echo "======================"
    kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME} \
        -o custom-columns="STEP:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason,START:.status.startTime,DURATION:.status.completionTime" \
        --sort-by=.status.startTime 2>/dev/null || echo "No steps started yet"
    echo ""
}

# Ask if user wants to monitor
read -p "Monitor execution progress? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🎯 📊 Monitoring Complete Workflow Execution"
    echo "=========================================="
    echo "Pipeline: ${PIPELINE_RUN_NAME}"
    echo ""
    
    # Monitor with progress updates
    while true; do
        STATUS=$(kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        if [ "$STATUS" = "Succeeded" ]; then
            echo "✅ 🎉 Complete workflow completed successfully!"
            echo ""
            show_step_status
            break
        elif [ "$STATUS" = "Failed" ]; then
            echo "❌ Complete workflow failed"
            echo ""
            show_step_status
            
            # Show failure details
            echo "🔍 Failure details:"
            kubectl describe pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines | grep -A 10 "Conditions:"
            break
        else
            echo "⏳ Status: $STATUS - Workflow is running..."
            show_step_status
            sleep 30
        fi
    done
else
    echo "Complete workflow started. Monitor progress using the dashboard links above."
    echo ""
    echo "Expected completion time: 2-3 hours"
    echo "All 9 steps will be visible in the dashboard"
fi

# Cleanup
rm -f /tmp/complete-workflow-run.yaml

echo ""
echo "🎯 To check final results:"
echo "  kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines"
echo "  Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"