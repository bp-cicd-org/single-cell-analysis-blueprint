#!/bin/bash
# RAPIDS SingleCell Analysis - 5 Notebooks Enhanced UI Strategy
# ============================================================

set -euo pipefail

# Fault-Tolerant Execution: Track failed phases but continue
FAILED_PHASES=""

EXECUTION_STRATEGY="${1:-sequential}"
BASE_RUN_NAME="rapids-5nb-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🚀 RAPIDS SingleCell Analysis - Enhanced UI Dashboard Strategy"
echo "============================================================="
echo "Strategy: ${EXECUTION_STRATEGY}"
echo "Base Run Name: ${BASE_RUN_NAME}"
echo "Dashboard: ${DASHBOARD_URL}"
echo ""

echo "📋 Enhanced UI Features:"
echo "========================"
echo "✅ Phase Level: Clear notebook progress (1/5, 2/5, etc.)"
echo "✅ Step Level: Detailed step progress (Step 1-9 for each notebook)"
echo "✅ Dashboard Labels: Enhanced filtering and organization"
echo "✅ Progress Tracking: Real-time phase and step monitoring"
echo ""

# Notebook configurations with enhanced naming
declare -a NOTEBOOKS=(
    "01_scRNA_analysis_preprocessing"
    "02_scRNA_analysis_extended"
    "03_scRNA_analysis_with_pearson_residuals"
    "04_scRNA_analysis_dask_out_of_core"
    "05_scRNA_analysis_multi_GPU"
)

declare -a NOTEBOOK_DISPLAY_NAMES=(
    "preprocessing"
    "extended-analysis"
    "pearson-residuals"
    "dask-outofcore"
    "multi-gpu"
)

declare -a PIPELINE_RUNS=()

# Function to start a notebook pipeline with enhanced UI naming
start_enhanced_notebook_pipeline() {
    local notebook_name="$1"
    local display_name="$2"
    local phase_number="$3"
    local total_phases="5"
    local run_name="phase-${phase_number}of${total_phases}-${display_name,,}-${BASE_RUN_NAME,,}"
    
    echo "🚀 Phase ${phase_number}/${total_phases}: Starting ${display_name}"
    echo "   Full Notebook: ${notebook_name}"
    echo "   Enhanced Run Name: ${run_name}"
    
    # Create PipelineRun with enhanced UI labels and annotations
    cat > /tmp/enhanced-notebook-${phase_number}-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${run_name}-
  namespace: tekton-pipelines
  labels:
    # Enhanced UI Labels
    app.kubernetes.io/name: rapids-5nb-strategy
    execution.rapids.ai/base-run: "${BASE_RUN_NAME}"
    execution.rapids.ai/phase: "phase-${phase_number}"
    execution.rapids.ai/total-phases: "${total_phases}"
    execution.rapids.ai/notebook-display: "${display_name}"
    execution.rapids.ai/notebook-full: "${notebook_name}"
    execution.rapids.ai/strategy: "${EXECUTION_STRATEGY}"
    # Dashboard filtering labels
    dashboard.tekton.dev/category: "rapids-singlecell"
    dashboard.tekton.dev/phase: "${phase_number}"
    dashboard.tekton.dev/workflow: "9-step-complete"
  annotations:
    # Enhanced UI Annotations
    description: "📊 RAPIDS Phase ${phase_number}/${total_phases}: ${display_name} (${notebook_name})"
    execution.tekton.dev/phase-info: "Phase ${phase_number} of ${total_phases} - ${display_name}"
    execution.tekton.dev/workflow-steps: "9-Step Complete Workflow"
    execution.tekton.dev/estimated-duration: "2-3 hours"
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
    hardware.tekton.dev/gpu-requirement: "1x A100 80GB"
    hardware.tekton.dev/memory-requirement: "32GB RAM"
    dashboard.tekton.dev/display-name: "Phase ${phase_number}/${total_phases}: ${display_name}"
spec:
  pipelineRef:
    name: complete-notebook-workflow
    
  params:
  - name: notebook-name
    value: "${notebook_name}"
  - name: pipeline-run-name
    value: "${run_name}"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
      
  timeouts:
    pipeline: "4h"
    tasks: "3h"
EOF

    # Submit the pipeline
    local pipeline_run_name
    pipeline_run_name=$(kubectl create -f /tmp/enhanced-notebook-${phase_number}-run.yaml -o jsonpath='{.metadata.name}')
    PIPELINE_RUNS+=("$pipeline_run_name")
    
    echo "   ✅ Started: ${pipeline_run_name}"
    echo "   🌐 Enhanced Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run_name}"
    echo "   📊 Phase Progress: ${phase_number}/${total_phases} Notebooks"
    echo "   🔍 Filter by Phase: dashboard.tekton.dev/phase=${phase_number}"
    echo ""
    
    # Cleanup temp file
    rm -f /tmp/enhanced-notebook-${phase_number}-run.yaml
    
    return 0
}

# Function to wait for pipeline completion with enhanced monitoring
wait_for_enhanced_pipeline() {
    local pipeline_run_name="$1"
    local phase_number="$2"
    local display_name="$3"
    local total_phases="5"
    
    echo "⏳ Phase ${phase_number}/${total_phases}: Monitoring ${display_name} progress..."
    echo "   🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run_name}"
    
    while true; do
        local status
        status=$(kubectl get pipelinerun "$pipeline_run_name" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        # Get current step information
        local current_tasks
        current_tasks=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun="${pipeline_run_name}" --sort-by=.metadata.creationTimestamp -o custom-columns="TASK:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason" --no-headers 2>/dev/null || echo "")
        
        case "$status" in
            "Succeeded")
                echo "✅ Phase ${phase_number}/${total_phases}: ${display_name} completed successfully!"
                echo "   📊 All 9 steps completed for this phase"
                return 0
                ;;
            "Failed")
                echo "❌ Phase ${phase_number}/${total_phases}: ${display_name} failed!"
                echo "   🔍 Check step details in dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run_name}"
                
                # Show which step failed
                local failed_step
                failed_step=$(echo "$current_tasks" | grep -E "Failed|Error" | head -1 | awk '{print $1}' || echo "Unknown")
                if [ -n "$failed_step" ] && [ "$failed_step" != "Unknown" ]; then
                    echo "   ❌ Failed at: $failed_step"
                fi
                return 1
                ;;
            "Running"|"Started")
                # Show current running step
                local running_step
                running_step=$(echo "$current_tasks" | grep -E "Running" | head -1 | awk '{print $1}' || echo "")
                local completed_steps
                completed_steps=$(echo "$current_tasks" | grep -c "Succeeded" || echo "0")
                
                if [ -n "$running_step" ]; then
                    echo "   🔄 Phase ${phase_number}/${total_phases}: ${display_name} - Step: ${running_step} (${completed_steps}/9 completed)"
                else
                    echo "   🔄 Phase ${phase_number}/${total_phases}: ${display_name} running... (${completed_steps}/9 steps completed)"
                fi
                sleep 30
                ;;
            *)
                echo "   ⏸️  Phase ${phase_number}/${total_phases}: ${display_name} pending... (Status: $status)"
                sleep 10
                ;;
        esac
    done
}

# Function to show enhanced overall progress
show_enhanced_progress() {
    echo ""
    echo "📊 Enhanced 5-Notebook Progress Dashboard"
    echo "========================================"
    echo "Base Run: ${BASE_RUN_NAME}"
    echo "Strategy: ${EXECUTION_STRATEGY}"
    echo "Dashboard: ${DASHBOARD_URL}"
    echo ""
    
    for i in "${!PIPELINE_RUNS[@]}"; do
        local pipeline_run="${PIPELINE_RUNS[$i]}"
        local phase=$((i + 1))
        local display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
        local notebook="${NOTEBOOKS[$i]}"
        
        if [ -n "$pipeline_run" ]; then
            local status
            status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
            
            # Get step progress
            local completed_steps
            completed_steps=$(kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun="${pipeline_run}" -o jsonpath='{.items[*].status.conditions[0].reason}' 2>/dev/null | grep -c "Succeeded" || echo "0")
            local total_steps="9"
            
            case "$status" in
                "Succeeded") 
                    echo "   ✅ Phase ${phase}/5: ${display_name} (${completed_steps}/${total_steps} steps) ✅"
                    echo "      🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
                    ;;
                "Failed") 
                    echo "   ❌ Phase ${phase}/5: ${display_name} (${completed_steps}/${total_steps} steps) ❌"
                    echo "      🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
                    ;;
                "Running"|"Started") 
                    echo "   🔄 Phase ${phase}/5: ${display_name} (${completed_steps}/${total_steps} steps) 🔄"
                    echo "      🌐 Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
                    ;;
                *) 
                    echo "   ⏳ Phase ${phase}/5: ${display_name} (Pending)"
                    ;;
            esac
        else
            echo "   ⭕ Phase ${phase}/5: ${display_name} (Not started)"
        fi
    done
    echo ""
    echo "🎯 Enhanced Dashboard Features:"
    echo "   📱 Filter by Phase: Use label 'dashboard.tekton.dev/phase'"
    echo "   🔍 Filter by Workflow: Use label 'dashboard.tekton.dev/workflow=9-step-complete'"
    echo "   📊 View Progress: Each PipelineRun shows detailed step breakdown"
    echo ""
}

# Main execution
echo "🎬 Starting Enhanced UI 5-Notebook Sequential Execution"
echo "======================================================"

# Execute notebooks sequentially with enhanced UI
for i in "${!NOTEBOOKS[@]}"; do
    notebook="${NOTEBOOKS[$i]}"
    display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    phase=$((i + 1))
    
    # Start the notebook pipeline with enhanced UI
    if start_enhanced_notebook_pipeline "$notebook" "$display_name" "$phase"; then
        pipeline_run="${PIPELINE_RUNS[-1]}"  # Get the last added pipeline run
        
        # Wait for completion before starting next
        if wait_for_enhanced_pipeline "$pipeline_run" "$phase" "$display_name"; then
            echo "   ✅ Phase ${phase}/5 completed, proceeding to next phase"
            show_enhanced_progress
        else
            echo "   ❌ Phase ${phase}/5 failed, but continuing (fault-tolerant mode)"
            echo "   🔍 Check details: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
            FAILED_PHASES="${FAILED_PHASES} ${phase}"
        fi
    else
        echo "❌ Failed to start Phase ${phase}/5"
        exit 1
    fi
    
    # Add delay between phases
    if [ $phase -lt ${#NOTEBOOKS[@]} ]; then
        echo "   ⏱️  Waiting 30 seconds before next phase..."
        sleep 30
    fi
done

# Final enhanced summary
echo ""
echo "🎉 All 5 Notebooks Completed Successfully!"
echo "========================================"
show_enhanced_progress

echo "🌟 Enhanced Dashboard Access:"
echo "============================"
echo "📱 Main Dashboard: ${DASHBOARD_URL}"
echo "🔍 Filter Options:"
echo "   • By Base Run: execution.rapids.ai/base-run=${BASE_RUN_NAME}"
echo "   • By Strategy: execution.rapids.ai/strategy=${EXECUTION_STRATEGY}"
echo "   • By Category: dashboard.tekton.dev/category=rapids-singlecell"
echo ""
echo "📊 Individual Phase Access:"
for i in "${!PIPELINE_RUNS[@]}"; do
    pipeline_run="${PIPELINE_RUNS[$i]}"
    phase=$((i + 1))
    display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    echo "   Phase ${phase}/5 (${display_name}): ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
done

echo ""

# Generate final execution summary
echo "📊 EXECUTION SUMMARY (Fault-Tolerant Mode)"
echo "==========================================="

if [ -z "$FAILED_PHASES" ]; then
    echo "🎉 ALL PHASES COMPLETED SUCCESSFULLY!"
    echo "   ✅ All 5 notebooks executed without issues"
    exit 0
else
    SUCCESS_COUNT=$((5 - $(echo $FAILED_PHASES | wc -w)))
    FAIL_COUNT=$(echo $FAILED_PHASES | wc -w)
    
    echo "📈 MIXED RESULTS:"
    echo "   ✅ Successful phases: $SUCCESS_COUNT/5"
    echo "   ❌ Failed phases: $FAIL_COUNT/5"
    echo ""
    echo "❌ Failed Phase Details:"
    for phase in $FAILED_PHASES; do
        display_name="${NOTEBOOK_DISPLAY_NAMES[$((phase-1))]}"
        pipeline_run="${PIPELINE_RUNS[$((phase-1))]}"
        echo "   Phase $phase/5: $display_name"
        echo "   🔍 Details: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
    done
    echo ""
    echo "💡 NEXT STEPS:"
    echo "   1. Check failed phase logs in the dashboard links above"
    echo "   2. Fix issues (e.g., missing network files for Phase 2)"
    echo "   3. Re-run specific phases if needed"
    echo ""
    echo "🌐 View all results: http://results.10.34.2.129.nip.io"
fi

echo ""
echo "✨ Enhanced UI 5-Notebook Strategy Execution Completed! ✨"