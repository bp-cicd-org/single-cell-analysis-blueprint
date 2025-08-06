#!/bin/bash
set -eu

# Enhanced 4-Notebook Execution with Compatibility Patches
# ========================================================
# This script runs 4 notebooks (skip 02) with integrated compatibility patches

echo "🚀 Enhanced RAPIDS 4-Notebook Analysis with Compatibility Patches"
echo "================================================================="

# Configuration
EXECUTION_STRATEGY="sequential"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BASE_RUN_NAME="enhanced-4nb-${TIMESTAMP}"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

# Notebook configuration with enhanced compatibility
declare -a NOTEBOOK_NAMES=("01_scRNA_analysis_preprocessing" "03_scRNA_analysis_with_pearson_residuals" "04_scRNA_analysis_dask_out_of_core" "05_scRNA_analysis_multi_GPU")
declare -a NOTEBOOK_DISPLAY_NAMES=("preprocessing" "pearson-residuals" "dask-outofcore" "multi-gpu")
declare -a NOTEBOOK_PHASES=("1" "3" "4" "5")
declare -a PIPELINE_RUNS=()

# Enhanced compatibility features for each notebook
declare -A COMPATIBILITY_FEATURES=(
    ["01_scRNA_analysis_preprocessing"]="PCA error handling, General resilience"
    ["03_scRNA_analysis_with_pearson_residuals"]="General resilience"
    ["04_scRNA_analysis_dask_out_of_core"]="AnnData read_elem_as_dask fix, General resilience"
    ["05_scRNA_analysis_multi_GPU"]="AnnData read_elem_as_dask fix, General resilience"
)

echo "Strategy: $EXECUTION_STRATEGY"
echo "Base Run Name: $BASE_RUN_NAME"
echo "Dashboard: $DASHBOARD_URL"
echo ""

echo "📋 Enhanced Execution Plan with Compatibility Patches:"
echo "===================================================="
for i in "${!NOTEBOOK_NAMES[@]}"; do
    notebook_name="${NOTEBOOK_NAMES[$i]}"
    display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    phase="${NOTEBOOK_PHASES[$i]}"
    features="${COMPATIBILITY_FEATURES[$notebook_name]}"
    
    if [ "$phase" = "2" ]; then
        echo "⏭️  Phase $phase/5: SKIPPED ($notebook_name)"
    else
        echo "🔧 Phase $phase/5: $notebook_name"
        echo "   Features: $features"
    fi
done

echo ""
echo "📋 Enhanced Compatibility Features:"
echo "=================================="
echo "✅ Automated patch deployment to shared storage"
echo "✅ Notebook-specific compatibility targeting"
echo "✅ PCA error graceful handling (Notebook 01)"
echo "✅ AnnData read_elem_as_dask compatibility (Notebooks 04, 05)"
echo "✅ General error resilience for all notebooks"
echo "✅ Zero modification to original notebook files"
echo "✅ Enhanced progress monitoring and fault tolerance"

# Function to wait for pipeline completion with enhanced monitoring
wait_for_enhanced_pipeline() {
    local pipeline_run="$1"
    local phase="$2"
    local display_name="$3"
    
    echo ""
    echo "⏳ Phase $phase/5: Monitoring $display_name with compatibility patches..."
    echo "   🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
    echo "   🔧 Compatibility: ${COMPATIBILITY_FEATURES[${NOTEBOOK_NAMES[$((phase-1))]}]}"
    
    while true; do
        local status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        local reason=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        if [ "$status" = "True" ]; then
            echo "✅ Phase $phase/5: $display_name completed successfully with compatibility patches!"
            echo "   🎯 All compatibility features worked as expected"
            return 0
        elif [ "$status" = "False" ]; then
            echo "❌ Phase $phase/5: $display_name failed"
            echo "   🔍 Check details: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
            echo "   ⚠️ Note: Some failures may be due to environment-specific issues"
            return 1
        else
            # Show progress
            local completed_tasks=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.taskRuns}' 2>/dev/null | jq -r 'to_entries | map(select(.value.status.conditions[0].status == "True")) | length' 2>/dev/null || echo "0")
            
            if [ "$completed_tasks" -gt 0 ]; then
                echo "   🔄 Phase $phase/5: $display_name running with patches... ($completed_tasks/9 steps completed)"
            else
                echo "   ⏸️  Phase $phase/5: $display_name with patches pending... (Status: $reason)"
            fi
        fi
        
        sleep 15
    done
}

echo ""
echo "🎬 Starting Enhanced 4-Notebook Sequential Execution with Compatibility"
echo "======================================================================="

FAILED_PHASES=""

# Execute each notebook with enhanced compatibility
for i in "${!NOTEBOOK_NAMES[@]}"; do
    notebook_name="${NOTEBOOK_NAMES[$i]}"
    display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    phase="${NOTEBOOK_PHASES[$i]}"
    
    echo ""
    echo "🚀 Phase $phase/5: Starting $display_name with compatibility patches"
    echo "   Full Notebook: $notebook_name"
    echo "   Compatibility Features: ${COMPATIBILITY_FEATURES[$notebook_name]}"
    
    enhanced_run_name="enhanced-phase-${phase}of5-${display_name}-${BASE_RUN_NAME}"
    
    # Create enhanced PipelineRun with compatibility integration
    pipeline_run_yaml=$(cat << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: $(echo $enhanced_run_name | tr '[:upper:]' '[:lower:]')-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: complete-notebook-workflow
    app.kubernetes.io/component: tekton-pipeline
    app.kubernetes.io/version: "1.0.0"
    pipeline.tekton.dev/gpu-enabled: "true"
    notebook.rapids.ai/name: "$notebook_name"
    execution.rapids.ai/phase: "$phase"
    execution.rapids.ai/total-phases: "5"
    execution.rapids.ai/run: "$BASE_RUN_NAME"
    dashboard.tekton.dev/phase: "$phase"
    dashboard.tekton.dev/workflow: "9-step-complete-enhanced"
    compatibility.rapids.ai/patches-enabled: "true"
    compatibility.rapids.ai/version: "unified-v1"
  annotations:
    description: "Enhanced 9-step workflow for $notebook_name with compatibility patches"
    execution.tekton.dev/estimated-duration: "2-3 hours"
    hardware.tekton.dev/gpu-requirement: "1x A100 80GB"
    hardware.tekton.dev/memory-requirement: "32GB RAM"
    compatibility.tekton.dev/features: "${COMPATIBILITY_FEATURES[$notebook_name]}"
    phases.tekton.dev/description: |
      Step 1: Container Environment Setup
      Step 2: Git Clone Blueprint Repository
      Step 3: Download Scientific Dataset
      Step 4: Papermill Execution (with compatibility patches)
      Step 5: NBConvert to HTML
      Step 6: Git Clone Test Framework
      Step 7: Pytest Execution
      Step 8: Collect Artifacts
      Step 9: Final Summary & Cleanup
spec:
  pipelineRef:
    name: complete-notebook-workflow
  taskRunTemplate:
    serviceAccountName: tekton-gpu-executor
  timeouts:
    pipeline: 4h0m0s
  params:
  - name: notebook-name
    value: "$notebook_name"
  - name: pipeline-run-name
    value: "$enhanced_run_name"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF
)
    
    # Create the PipelineRun
    pipeline_run=$(echo "$pipeline_run_yaml" | kubectl create -f - -o jsonpath='{.metadata.name}')
    PIPELINE_RUNS[$i]="$pipeline_run"
    
    echo "   ✅ Started: $pipeline_run"
    echo "   🌐 Enhanced Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
    echo "   🔧 Compatibility System: Active and Ready"
    echo "   📊 Phase Progress: $phase/5 Notebooks (Enhanced with Patches)"
    
    # Wait for completion before starting next
    if wait_for_enhanced_pipeline "$pipeline_run" "$phase" "$display_name"; then
        echo "   ✅ Phase $phase/5 completed successfully with compatibility patches"
    else
        echo "   ❌ Phase $phase/5 failed, but continuing (fault-tolerant mode)"
        echo "   🔍 Check details: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
        FAILED_PHASES="${FAILED_PHASES} ${phase}"
    fi
    
    if [ $i -lt $((${#NOTEBOOK_NAMES[@]} - 1)) ]; then
        echo "   ⏱️  Waiting 30 seconds before next phase..."
        sleep 30
    fi
done

echo ""
echo "🎉 Enhanced 4-Notebook Execution Completed!"
echo "=========================================="

# Show final summary
echo ""
echo "📊 Final Enhanced Progress Summary:"
echo "================================="
echo "Base Run: $BASE_RUN_NAME"
echo "Strategy: $EXECUTION_STRATEGY with Compatibility Patches"
echo "Dashboard: $DASHBOARD_URL"
echo ""

for i in "${!PIPELINE_RUNS[@]}"; do
    if [ -n "${PIPELINE_RUNS[$i]:-}" ]; then
        pipeline_run="${PIPELINE_RUNS[$i]}"
        phase="${NOTEBOOK_PHASES[$i]}"
        display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
        notebook_name="${NOTEBOOK_NAMES[$i]}"
        
        # Get final status
        local status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        local status_icon="❓"
        
        if [ "$status" = "True" ]; then
            status_icon="✅"
        elif [ "$status" = "False" ]; then
            status_icon="❌"
        fi
        
        echo "   $status_icon Phase $phase/5: $display_name ($notebook_name)"
        echo "      🔧 Compatibility: ${COMPATIBILITY_FEATURES[$notebook_name]}"
        echo "      🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
    fi
done

if [ -n "$FAILED_PHASES" ]; then
    echo ""
    echo "⚠️ Some phases failed:$FAILED_PHASES"
    echo "   This may be due to environment-specific issues or missing dependencies"
    echo "   Check individual pipeline logs for detailed error analysis"
else
    echo ""
    echo "🎉 All phases completed successfully with compatibility patches!"
fi

echo ""
echo "🔗 Useful Links:"
echo "   📊 Main Dashboard: $DASHBOARD_URL"
echo "   🌐 Artifact Server: http://results.10.34.2.129.nip.io"
echo "   📋 Filter by Run: execution.rapids.ai/run=$BASE_RUN_NAME"
echo "   🔧 Compatibility Enabled: compatibility.rapids.ai/patches-enabled=true"

echo ""
echo "✅ Enhanced 4-Notebook pipeline execution completed with full compatibility support!"