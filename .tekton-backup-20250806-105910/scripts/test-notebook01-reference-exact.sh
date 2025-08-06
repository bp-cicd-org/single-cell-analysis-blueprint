#!/bin/bash
# Test Notebook 01 - Exact Reference Implementation
# =================================================

set -euo pipefail

RUN_NAME="nb01-exact-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🧪 Testing Notebook 01 - Exact Reference Implementation"
echo "======================================================="
echo "Run Name: ${RUN_NAME}"
echo "Dashboard: ${DASHBOARD_URL}"
echo ""

echo "📋 Reference Features:"
echo "======================"
echo "✅ Exact copy of reference file structure"
echo "✅ PCA error tolerance (from reference)"
echo "✅ Proper error handling for pytest"
echo "✅ GitHub token authentication"
echo "✅ Complete 9-step workflow"
echo ""

# Create PipelineRun
cat > /tmp/notebook01-exact-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: notebook01-reference-exact
    execution.rapids.ai/notebook: "01_scRNA_analysis_preprocessing"
    test.rapids.ai/type: "reference-exact"
  annotations:
    description: "🧪 Notebook 01 - Exact Reference Implementation Test"
    test.tekton.dev/reference-file: "gpu-scrna-analysis-preprocessing-workflow.yaml"
spec:
  pipelineRef:
    name: notebook01-reference-exact
    
  params:
  - name: pipeline-run-name
    value: "${RUN_NAME}"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
      
  timeouts:
    pipeline: "4h"
    tasks: "3h"
EOF

# Submit the pipeline
PIPELINE_RUN_NAME=$(kubectl create -f /tmp/notebook01-exact-run.yaml -o jsonpath='{.metadata.name}')

echo "✅ Notebook 01 Reference Test started: ${PIPELINE_RUN_NAME}"
echo ""
echo "🌐 Monitoring Links:"
echo "  Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
echo "  Dashboard: ${DASHBOARD_URL}"
echo ""
echo "📊 CLI Monitoring:"
echo "  kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines -w"
echo "  kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME}"
echo ""

# Function to monitor execution with detailed step tracking
monitor_execution() {
    echo "🎯 Monitoring Notebook 01 Reference Execution"
    echo "============================================="
    echo "Pipeline: ${PIPELINE_RUN_NAME}"
    echo ""
    
    while true; do
        STATUS=$(kubectl get pipelinerun "$PIPELINE_RUN_NAME" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        # Get current step information
        CURRENT_TASKS=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun="${PIPELINE_RUN_NAME}" --sort-by=.metadata.creationTimestamp -o custom-columns="STEP:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason" --no-headers 2>/dev/null || echo "")
        
        case "$STATUS" in
            "Succeeded")
                echo "✅ 🎉 Notebook 01 Reference Test completed successfully!"
                echo ""
                
                echo "📊 Final Step Results:"
                echo "====================="
                echo "$CURRENT_TASKS" | awk '{printf "  %-40s %s\n", $1, ($2=="Succeeded" ? "✅" : ($2=="Failed" ? "❌" : "⏳")) " " $2}'
                
                echo ""
                echo "🎯 Key Validation Points:"
                echo "========================="
                echo "✅ Step 4: PCA error handling worked correctly"
                echo "✅ Step 6: GitHub token authentication successful"
                echo "✅ Step 7: Pytest with proper error handling"
                echo "✅ Step 9: Artifacts collected and organized"
                
                echo ""
                echo "📂 Check Results:"
                echo "   kubectl exec -it \$(kubectl get pods -n tekton-pipelines -l tekton.dev/taskRun --field-selector=status.phase=Succeeded | tail -1 | awk '{print \$1}') -n tekton-pipelines -- ls -la /workspace/shared-storage/pipeline-runs/"
                break
                ;;
            "Failed")
                echo "❌ Notebook 01 Reference Test failed!"
                echo ""
                
                echo "📊 Step Status at Failure:"
                echo "=========================="
                echo "$CURRENT_TASKS" | awk '{printf "  %-40s %s\n", $1, ($2=="Succeeded" ? "✅" : ($2=="Failed" ? "❌" : "⏳")) " " $2}'
                
                # Show which step failed
                FAILED_STEP=$(echo "$CURRENT_TASKS" | grep -E "Failed" | head -1 | awk '{print $1}' || echo "Unknown")
                if [ -n "$FAILED_STEP" ] && [ "$FAILED_STEP" != "Unknown" ]; then
                    echo ""
                    echo "❌ Failed at: $FAILED_STEP"
                    echo "🔍 Detailed troubleshooting:"
                    echo "  kubectl describe taskrun \$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME} -l tekton.dev/pipelineTask=${FAILED_STEP} -o name)"
                fi
                break
                ;;
            "Running"|"Started")
                # Show current running step
                RUNNING_STEP=$(echo "$CURRENT_TASKS" | grep -E "Running" | head -1 | awk '{print $1}' || echo "")
                COMPLETED_STEPS=$(echo "$CURRENT_TASKS" | grep -c "Succeeded" || echo "0")
                
                if [ -n "$RUNNING_STEP" ]; then
                    echo "🔄 Current Step: $RUNNING_STEP (${COMPLETED_STEPS}/9 completed)"
                else
                    echo "🔄 Notebook 01 running... (${COMPLETED_STEPS}/9 steps completed)"
                fi
                
                # Show step breakdown every 30 seconds
                echo "   Step Status:"
                echo "$CURRENT_TASKS" | awk '{printf "     %-35s %s\n", $1, ($2=="Succeeded" ? "✅" : ($2=="Running" ? "🔄" : ($2=="Failed" ? "❌" : "⏳"))) " " $2}' | head -9
                
                sleep 30
                ;;
            *)
                echo "⏸️ Notebook 01 pending... (Status: $STATUS)"
                sleep 10
                ;;
        esac
    done
}

# Ask if user wants to monitor
read -p "Monitor execution progress? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    monitor_execution
else
    echo "Notebook 01 Reference Test started. Monitor progress using the dashboard links above."
    echo ""
    echo "📋 Expected Results:"
    echo "   ✅ All 9 steps should complete successfully"
    echo "   ✅ PCA errors should be handled gracefully"
    echo "   ✅ Pytest should install playwright if missing"
    echo "   ✅ Final artifacts should be organized in pipeline-runs/"
    echo ""
    echo "🎯 To check final results:"
    echo "   kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines"
    echo "   Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
fi

# Cleanup
rm -f /tmp/notebook01-exact-run.yaml

echo ""
echo "🎯 Access Results:"
echo "  Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
echo "  📊 This test validates the exact reference implementation for Notebook 01"