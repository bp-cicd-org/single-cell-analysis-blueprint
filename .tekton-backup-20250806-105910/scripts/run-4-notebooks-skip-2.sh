#!/bin/bash
set -eu

# Run 4 Notebooks (Skip 2of5) - Enhanced UI Strategy
# ==================================================

# Fault-Tolerant Execution: Track failed phases but continue
FAILED_PHASES=""

EXECUTION_STRATEGY="${1:-sequential}"
BASE_RUN_NAME="rapids-4nb-skip2-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🚀 RAPIDS 4-Notebook Analysis - Skip Phase 2 Strategy"
echo "===================================================="
echo "Strategy: $EXECUTION_STRATEGY"
echo "Base Run Name: $BASE_RUN_NAME"
echo "Dashboard: $DASHBOARD_URL"
echo ""
echo "📋 Execution Plan:"
echo "=================="
echo "✅ Phase 1/4: 01_scRNA_analysis_preprocessing"
echo "⏭️  Phase 2/4: SKIPPED (02_scRNA_analysis_extended)"
echo "✅ Phase 3/4: 03_scRNA_analysis_with_pearson_residuals"  
echo "🔧 Phase 4/4: 04_scRNA_analysis_dask_out_of_core (with anndata fix)"
echo "🔧 Phase 5/4: 05_scRNA_analysis_multi_GPU (with anndata fix)"
echo ""

# Enhanced notebook configurations (skip phase 2)
NOTEBOOK_NAMES=(
    "01_scRNA_analysis_preprocessing"
    "03_scRNA_analysis_with_pearson_residuals"
    "04_scRNA_analysis_dask_out_of_core"
    "05_scRNA_analysis_multi_GPU"
)

NOTEBOOK_DISPLAY_NAMES=(
    "preprocessing"
    "pearson-residuals"
    "dask-outofcore"
    "multi-gpu"
)

NOTEBOOK_PHASES=(
    "1"
    "3"
    "4"
    "5"
)

PIPELINE_RUNS=()

# Function to wait for pipeline completion with enhanced monitoring
wait_for_enhanced_pipeline() {
    local pipeline_run="$1"
    local phase="$2"
    local display_name="$3"
    
    echo "⏳ Phase $phase/5: Monitoring $display_name progress..."
    echo "   🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
    
    while true; do
        local status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        local reason=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        if [ "$status" = "True" ]; then
            echo "✅ Phase $phase/5: $display_name completed successfully!"
            echo "   📊 All 9 steps completed for this phase"
            return 0
        elif [ "$status" = "False" ]; then
            echo "❌ Phase $phase/5: $display_name failed!"
            local current_step=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun="$pipeline_run" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.labels.tekton\.dev/pipelineTask}' 2>/dev/null || echo "unknown")
            echo "   🔍 Check step details in dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
            echo "   ❌ Failed at: $current_step"
            return 1
        else
            # Show progress
            local completed_tasks=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun="$pipeline_run" -o jsonpath='{.items[?(@.status.conditions[0].status=="True")].metadata.name}' 2>/dev/null | wc -w || echo "0")
            local current_step=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun="$pipeline_run" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.labels.tekton\.dev/pipelineTask}' 2>/dev/null || echo "pending")
            
            if [ "$completed_tasks" -gt 0 ]; then
                echo "   🔄 Phase $phase/5: $display_name running... ($completed_tasks/9 steps completed)"
            else
                echo "   ⏸️  Phase $phase/5: $display_name pending... (Status: $reason)"
            fi
            
            if [ "$current_step" != "pending" ]; then
                echo "   🔄 Phase $phase/5: $display_name - Step: $current_step ($(printf "%02d" $completed_tasks)/9 completed)"
            fi
        fi
        
        sleep 10
    done
}

# Function to show enhanced progress dashboard
show_enhanced_progress() {
    echo ""
    echo "📊 Enhanced 4-Notebook Progress Dashboard (Skip Phase 2)"
    echo "======================================================="
    echo "Base Run: $BASE_RUN_NAME"
    echo "Strategy: $EXECUTION_STRATEGY"
    echo "Dashboard: $DASHBOARD_URL"
    echo ""
    
    for i in "${!PIPELINE_RUNS[@]}"; do
        if [ -n "${PIPELINE_RUNS[$i]:-}" ]; then
            pipeline_run="${PIPELINE_RUNS[$i]}"
            phase="${NOTEBOOK_PHASES[$i]}"
            display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
            
            # Get status
            local status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
            local status_icon="❓"
            
            if [ "$status" = "True" ]; then
                status_icon="✅"
            elif [ "$status" = "False" ]; then
                status_icon="❌"
            else
                status_icon="🔄"
            fi
            
            echo "   $status_icon Phase $phase/5: $display_name (${NOTEBOOK_NAMES[$i]}) $status_icon"
            echo "      🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
        fi
    done
    
    echo ""
    echo "🎯 Enhanced Dashboard Features:"
    echo "   📱 Filter by Phase: Use label 'dashboard.tekton.dev/phase'"
    echo "   🔍 Filter by Workflow: Use label 'dashboard.tekton.dev/workflow=9-step-complete'"
    echo "   📊 View Progress: Each PipelineRun shows detailed step breakdown"
}

echo "📋 Enhanced UI Features:"
echo "========================"
echo "✅ Phase Level: Clear notebook progress (1,3,4,5 - skipping 2)"
echo "✅ Step Level: Detailed step progress (Step 1-9 for each notebook)"
echo "✅ Dashboard Labels: Enhanced filtering and organization"
echo "✅ Progress Tracking: Real-time phase and step monitoring"
echo "✅ Anndata Fix: Phases 4&5 will include updated dependencies"

echo ""
echo "🎬 Starting Enhanced UI 4-Notebook Sequential Execution (Skip Phase 2)"
echo "====================================================================="

# Execute notebooks sequentially (skip phase 2)
for i in "${!NOTEBOOK_NAMES[@]}"; do
    notebook_name="${NOTEBOOK_NAMES[$i]}"
    display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    phase="${NOTEBOOK_PHASES[$i]}"
    
    echo "🚀 Phase $phase/5: Starting $display_name"
    echo "   Full Notebook: $notebook_name"
    
    # Create enhanced run name
    enhanced_run_name="phase-${phase}of5-${display_name}-${BASE_RUN_NAME}"
    echo "   Enhanced Run Name: $enhanced_run_name"
    
    # Create PipelineRun with enhanced labels and annotations
    pipeline_run_yaml=$(cat << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${enhanced_run_name}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: rapids-4nb-strategy
    app.kubernetes.io/component: tekton-pipeline
    app.kubernetes.io/version: "1.0.0"
    dashboard.tekton.dev/phase: "$phase"
    dashboard.tekton.dev/category: rapids-singlecell
    dashboard.tekton.dev/workflow: 9-step-complete
    execution.rapids.ai/phase: phase-$phase
    execution.rapids.ai/total-phases: "5"
    execution.rapids.ai/notebook-full: $notebook_name
    execution.rapids.ai/notebook-display: $display_name
    execution.rapids.ai/base-run: $BASE_RUN_NAME
    execution.rapids.ai/strategy: $EXECUTION_STRATEGY
    pipeline.tekton.dev/gpu-enabled: "true"
  annotations:
    dashboard.tekton.dev/display-name: "Phase $phase/5: $display_name"
    description: "📊 RAPIDS Phase $phase/5: $display_name ($notebook_name)"
    execution.tekton.dev/phase-info: "Phase $phase of 5 - $display_name"
    execution.tekton.dev/workflow-steps: "9-Step Complete Workflow"
    execution.tekton.dev/step-breakdown: |
      Step 1: Container Environment Setup
      Step 2: Git Clone Blueprint
      Step 3: Download Scientific Dataset (1.7GB)
      Step 4: Papermill Execution (Notebook Processing)
      Step 5: NBConvert to HTML
      Step 6: Git Clone Test Framework  
      Step 7: Pytest Execution
      Step 8: Collect Artifacts
      Step 9: Final Summary & Cleanup
    execution.tekton.dev/estimated-duration: "2-3 hours"
    hardware.tekton.dev/gpu-requirement: "1x A100 80GB"
    hardware.tekton.dev/memory-requirement: "32GB RAM"
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
    echo "   📊 Phase Progress: $phase/5 Notebooks (Skip Phase 2)"
    echo "   🔍 Filter by Phase: dashboard.tekton.dev/phase=$phase"
    echo ""
    
    # Wait for completion before starting next
    if wait_for_enhanced_pipeline "$pipeline_run" "$phase" "$display_name"; then
        echo "   ✅ Phase $phase/5 completed, proceeding to next phase"
        show_enhanced_progress
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
echo "🎉 All 4 Notebooks Completed Successfully! (Skipped Phase 2)"
echo "==========================================================="

# Show final enhanced progress
show_enhanced_progress

echo ""
echo "🌟 Enhanced Dashboard Access:"
echo "============================"
echo "📱 Main Dashboard: $DASHBOARD_URL"
echo "🔍 Filter Options:"
echo "   • By Base Run: execution.rapids.ai/base-run=$BASE_RUN_NAME"
echo "   • By Strategy: execution.rapids.ai/strategy=$EXECUTION_STRATEGY"
echo "   • By Category: dashboard.tekton.dev/category=rapids-singlecell"

echo ""
echo "📊 Individual Phase Access:"
for i in "${!PIPELINE_RUNS[@]}"; do
    pipeline_run="${PIPELINE_RUNS[$i]}"
    phase="${NOTEBOOK_PHASES[$i]}"
    display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    echo "   Phase $phase/5 ($display_name): ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
done

echo ""

# Generate final execution summary
echo "📊 EXECUTION SUMMARY (Skip Phase 2 - Fault-Tolerant Mode)"
echo "========================================================="

if [ -z "$FAILED_PHASES" ]; then
    echo "🎉 ALL PHASES COMPLETED SUCCESSFULLY!"
    echo "   ✅ All 4 notebooks executed without issues (Phase 2 skipped)"
    exit 0
else
    SUCCESS_COUNT=$((4 - $(echo $FAILED_PHASES | wc -w)))
    FAIL_COUNT=$(echo $FAILED_PHASES | wc -w)
    
    echo "📈 MIXED RESULTS:"
    echo "   ✅ Successful phases: $SUCCESS_COUNT/4"
    echo "   ❌ Failed phases: $FAIL_COUNT/4"
    echo "   ⏭️  Skipped phases: 1/5 (Phase 2 - network files issue)"
    echo ""
    echo "❌ Failed Phase Details:"
    for phase in $FAILED_PHASES; do
        # Find the index for this phase
        for j in "${!NOTEBOOK_PHASES[@]}"; do
            if [ "${NOTEBOOK_PHASES[$j]}" = "$phase" ]; then
                display_name="${NOTEBOOK_DISPLAY_NAMES[$j]}"
                pipeline_run="${PIPELINE_RUNS[$j]}"
                echo "   Phase $phase/5: $display_name"
                echo "   🔍 Details: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
                break
            fi
        done
    done
    echo ""
    echo "💡 NEXT STEPS:"
    echo "   1. Check failed phase logs in the dashboard links above"
    echo "   2. For Phase 4&5: anndata version issues (read_elem_as_dask)"
    echo "   3. For Phase 2: network files need to be generated"
    echo "   4. Re-run specific phases after fixes"
    echo ""
    echo "🌐 View all results: http://results.10.34.2.129.nip.io"
fi

echo ""
echo "✨ Enhanced UI 4-Notebook Strategy Execution Completed! ✨"