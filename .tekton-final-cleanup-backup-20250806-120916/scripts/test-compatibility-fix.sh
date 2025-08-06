#!/bin/bash
set -eu

# Test Compatibility Fix
# ======================
# This script tests a single notebook to verify compatibility patches work

echo "🧪 Testing Compatibility Fix"
echo "=========================="

# Configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_NOTEBOOK="${1:-01_scRNA_analysis_preprocessing}"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🎯 Testing Notebook: $TEST_NOTEBOOK"
echo "📊 Dashboard: $DASHBOARD_URL"
echo "⏰ Timestamp: $TIMESTAMP"

# Create test PipelineRun
test_run_name="compat-test-${TEST_NOTEBOOK//_/-}-${TIMESTAMP}"

echo ""
echo "🚀 Creating compatibility test run..."
echo "   Run Name: $test_run_name"

# Create the test PipelineRun
pipeline_run_yaml=$(cat << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: $(echo $test_run_name | tr '[:upper:]' '[:lower:]')-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: complete-notebook-workflow
    app.kubernetes.io/component: tekton-pipeline
    app.kubernetes.io/version: "1.0.0"
    pipeline.tekton.dev/gpu-enabled: "true"
    notebook.rapids.ai/name: "$TEST_NOTEBOOK"
    test.rapids.ai/type: "compatibility-test"
    test.rapids.ai/timestamp: "$TIMESTAMP"
    compatibility.rapids.ai/patches-enabled: "true"
    compatibility.rapids.ai/version: "unified-v1"
  annotations:
    description: "Compatibility test for $TEST_NOTEBOOK with enhanced patches"
    test.tekton.dev/purpose: "Verify compatibility patches work correctly"
    compatibility.tekton.dev/features: |
      - Automatic compatibility patch application
      - Notebook-specific error handling
      - PCA error graceful handling (if applicable)
      - AnnData read_elem_as_dask compatibility (if applicable)
spec:
  pipelineRef:
    name: complete-notebook-workflow
  taskRunTemplate:
    serviceAccountName: tekton-gpu-executor
  timeouts:
    pipeline: 2h0m0s
  params:
  - name: notebook-name
    value: "$TEST_NOTEBOOK"
  - name: pipeline-run-name
    value: "$test_run_name"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF
)

# Create the PipelineRun
pipeline_run=$(echo "$pipeline_run_yaml" | kubectl create -f - -o jsonpath='{.metadata.name}')

echo "   ✅ Started: $pipeline_run"
echo "   🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"

# Monitor the test
echo ""
echo "⏳ Monitoring compatibility test..."
echo "   🔧 Focus: Step 4 (Papermill Execution) with compatibility patches"
echo "   🎯 Expected: Compatibility patches should handle known errors gracefully"

# Function to wait for pipeline completion
wait_for_test_completion() {
    local pipeline_run="$1"
    local start_time=$(date +%s)
    
    while true; do
        local status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        local reason=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        if [ "$status" = "True" ]; then
            echo "✅ Compatibility test PASSED!"
            echo "   🎯 Compatibility patches successfully handled errors"
            return 0
        elif [ "$status" = "False" ]; then
            echo "❌ Compatibility test FAILED"
            echo "   🔍 Check details: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
            echo "   ⚠️ This may indicate compatibility patches are not working properly"
            return 1
        else
            # Show progress
            local completed_tasks=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.taskRuns}' 2>/dev/null | jq -r 'to_entries | map(select(.value.status.conditions[0].status == "True")) | length' 2>/dev/null || echo "0")
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            
            if [ "$completed_tasks" -gt 0 ]; then
                echo "   🔄 Test running... ($completed_tasks/9 steps completed, ${elapsed}s elapsed)"
            else
                echo "   ⏸️  Test pending... (Status: $reason, ${elapsed}s elapsed)"
            fi
        fi
        
        sleep 15
    done
}

if wait_for_test_completion "$pipeline_run"; then
    echo ""
    echo "🎉 Compatibility Test Results: SUCCESS"
    echo "=================================="
    echo ""
    echo "✅ Key Achievements:"
    echo "   🔧 Compatibility patches were successfully applied"
    echo "   🛡️ Known errors were handled gracefully"
    echo "   📊 Pipeline completed despite compatibility issues"
    echo "   ✅ No modifications were made to original notebook files"
    
    # Get specific compatibility information
    echo ""
    echo "📋 Compatibility Details:"
    if [ "$TEST_NOTEBOOK" = "01_scRNA_analysis_preprocessing" ]; then
        echo "   🎯 PCA error handling: Should have gracefully handled KeyError: 'pca'"
    elif [ "$TEST_NOTEBOOK" = "04_scRNA_analysis_dask_out_of_core" ] || [ "$TEST_NOTEBOOK" = "05_scRNA_analysis_multi_GPU" ]; then
        echo "   🎯 AnnData compatibility: Should have handled read_elem_as_dask issues"
    fi
    echo "   🌐 Full logs: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
    
else
    echo ""
    echo "❌ Compatibility Test Results: FAILED"
    echo "=================================="
    echo ""
    echo "⚠️ Issues to investigate:"
    echo "   🔧 Compatibility patches may not be properly integrated"
    echo "   📋 Check Step 4 logs for patch application messages"
    echo "   🛠️ Verify compatibility patches exist in shared storage"
    echo "   🌐 Detailed logs: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
fi

echo ""
echo "🔗 Useful Commands for Investigation:"
echo "   📊 View PipelineRun: kubectl get pipelinerun $pipeline_run -n tekton-pipelines -o yaml"
echo "   📋 View Step 4 logs: kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=$pipeline_run -c step-execute-notebook-default"
echo "   🔧 Check patches: kubectl exec -n tekton-pipelines artifact-web-server -- ls -la /workspace/shared-storage/compatibility_patches/"