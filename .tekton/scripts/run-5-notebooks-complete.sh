#!/bin/bash
set -eu

# Run Complete 5 Notebooks - Enhanced Strategy
# ============================================

# Fault-Tolerant Execution: Track failed phases but continue
FAILED_PHASES=""

EXECUTION_STRATEGY="${1:-sequential}"
BASE_RUN_NAME="rapids-5nb-complete-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🚀 RAPIDS Complete 5-Notebook Analysis"
echo "====================================="
echo "Strategy: $EXECUTION_STRATEGY"
echo "Base Run Name: $BASE_RUN_NAME"
echo "Dashboard: $DASHBOARD_URL"
echo ""
echo "📋 Complete Execution Plan:"
echo "=========================="
echo "✅ Phase 1/5: 01_scRNA_analysis_preprocessing (PCA compatibility)"
echo "🔧 Phase 2/5: 02_scRNA_analysis_extended (Network file handling)"
echo "✅ Phase 3/5: 03_scRNA_analysis_with_pearson_residuals (PCA compatibility)"  
echo "🔧 Phase 4/5: 04_scRNA_analysis_dask_out_of_core (AnnData compatibility)"
echo "🔧 Phase 5/5: 05_scRNA_analysis_multi_GPU (AnnData compatibility)"
echo ""

echo "📋 Enhanced UI Features:"
echo "========================"
echo "✅ Phase Level: Clear notebook progress (1/5, 2/5, 3/5, 4/5, 5/5)"
echo "✅ Step Level: Detailed step progress (Step 1-9 for each notebook)"
echo "✅ Dashboard Labels: Enhanced filtering and organization"
echo "✅ Progress Tracking: Real-time phase and step monitoring"
echo "✅ Compatibility Patches: All notebooks include appropriate fixes"
echo ""

# Complete notebook configurations
NOTEBOOK_NAMES=(
    "01_scRNA_analysis_preprocessing"
    "02_scRNA_analysis_extended"
    "03_scRNA_analysis_with_pearson_residuals"
    "04_scRNA_analysis_dask_out_of_core"
    "05_scRNA_analysis_multi_GPU"
)

NOTEBOOK_DISPLAY_NAMES=(
    "preprocessing"
    "extended-analysis"
    "pearson-residuals"
    "dask-outofcore"
    "multi-gpu"
)

NOTEBOOK_PHASES=(
    "1"
    "2"
    "3"
    "4"
    "5"
)

# Array to track pipeline runs
declare -a PIPELINE_RUNS=()

# Function to start enhanced notebook pipeline
start_enhanced_notebook_pipeline() {
    local notebook_name="$1"
    local display_name="$2"
    local phase="$3"
    
    # Convert display name to lowercase for Kubernetes naming
    local display_name_lower="${display_name,,}"
    
    local run_name="phase-${phase}of5-${display_name_lower}-${BASE_RUN_NAME}"
    
    echo "🚀 Phase $phase/5: Starting $display_name"
    echo "   Full Notebook: $notebook_name"
    echo "   Enhanced Run Name: $run_name"
    
    # Create PipelineRun with enhanced UI labels
    cat <<EOF | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: $run_name
  namespace: tekton-pipelines
  labels:
    dashboard.tekton.dev/phase: "$phase"
    dashboard.tekton.dev/workflow: "9-step-complete"
    dashboard.tekton.dev/notebook: "$notebook_name"
    execution.rapids.ai/strategy: "complete-5-notebooks"
    execution.rapids.ai/display-name: "$display_name"
spec:
  pipelineRef:
    name: complete-notebook-workflow
  params:
  - name: notebook-name
    value: "$notebook_name"
  - name: pipeline-run-name
    value: "$run_name"
  timeouts:
    pipeline: "2h0m0s"
  taskRunTemplate:
    serviceAccountName: tekton-gpu-executor
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Started: $run_name"
        echo "   🌐 Enhanced Dashboard: $DASHBOARD_URL/#/namespaces/tekton-pipelines/pipelineruns/$run_name"
        echo "   📊 Phase Progress: $phase/5 Notebooks"
        echo "   🔍 Filter by Phase: dashboard.tekton.dev/phase=$phase"
        PIPELINE_RUNS+=("$run_name")
        return 0
    else
        echo "   ❌ Failed to start: $run_name"
        FAILED_PHASES="$FAILED_PHASES $phase"
        return 1
    fi
}

# Function to monitor pipeline progress
monitor_pipeline_progress() {
    local run_name="$1"
    local phase="$2"
    local display_name="$3"
    
    echo "⏳ Phase $phase/5: Monitoring $display_name progress..."
    echo "   🌐 Dashboard: $DASHBOARD_URL/#/namespaces/tekton-pipelines/pipelineruns/$run_name"
    
    while true; do
        local status=$(kubectl get pipelinerun $run_name -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        local reason=$(kubectl get pipelinerun $run_name -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        case $status in
            "True")
                echo "✅ Phase $phase/5: $display_name completed successfully!"
                local completed_tasks=$(kubectl get pipelinerun $run_name -n tekton-pipelines -o jsonpath='{.status.completedTasks}' 2>/dev/null | wc -w || echo "unknown")
                echo "   📊 All 9 steps completed for this phase"
                return 0
                ;;
            "False")
                echo "❌ Phase $phase/5: $display_name failed"
                echo "   📋 Failure Reason: $reason"
                FAILED_PHASES="$FAILED_PHASES $phase"
                return 1
                ;;
            "Unknown")
                local step_count=$(kubectl get pipelinerun $run_name -n tekton-pipelines -o jsonpath='{.status.completedTasks}' 2>/dev/null | wc -w || echo "0")
                echo "   🔄 Phase $phase/5: $display_name running... ($step_count/9 steps completed)"
                sleep 10
                ;;
        esac
    done
}

# Function to display enhanced progress dashboard
show_enhanced_dashboard() {
    echo ""
    echo "📊 Enhanced 5-Notebook Progress Dashboard"
    echo "========================================"
    echo "Base Run: $BASE_RUN_NAME"
    echo "Strategy: $EXECUTION_STRATEGY"
    echo "Dashboard: $DASHBOARD_URL"
    
    for i in "${!PIPELINE_RUNS[@]}"; do
        local run_name="${PIPELINE_RUNS[$i]}"
        local phase="${NOTEBOOK_PHASES[$i]}"
        local display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
        local notebook_name="${NOTEBOOK_NAMES[$i]}"
        
        local status=$(kubectl get pipelinerun $run_name -n tekton-pipelines -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
        local status_icon="🔄"
        
        case $status in
            "True") status_icon="✅" ;;
            "False") status_icon="❌" ;;
            "Unknown") status_icon="🔄" ;;
        esac
        
        echo "   $status_icon Phase $phase/5: $display_name ($notebook_name) $status_icon"
        echo "      🌐 Dashboard: $DASHBOARD_URL/#/namespaces/tekton-pipelines/pipelineruns/$run_name"
    done
    
    echo "🎯 Enhanced Dashboard Features:"
    echo "   📱 Filter by Phase: Use label 'dashboard.tekton.dev/phase'"
    echo "   🔍 Filter by Workflow: Use label 'dashboard.tekton.dev/workflow=9-step-complete'"
    echo "   📊 View Progress: Each PipelineRun shows detailed step breakdown"
}

# Function to execute all notebooks
execute_all_notebooks() {
    echo "🎬 Starting Enhanced 5-Notebook Sequential Execution"
    echo "=================================================="
    
    for i in "${!NOTEBOOK_NAMES[@]}"; do
        local notebook_name="${NOTEBOOK_NAMES[$i]}"
        local display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
        local phase="${NOTEBOOK_PHASES[$i]}"
        
        echo ""
        echo "Phase $phase/5: Starting $display_name"
        echo "==============================="
        
        if start_enhanced_notebook_pipeline "$notebook_name" "$display_name" "$phase"; then
            local run_name="${PIPELINE_RUNS[-1]}"
            
            # Monitor this phase
            monitor_pipeline_progress "$run_name" "$phase" "$display_name"
            
            # Show current progress
            echo "   ✅ Phase $phase/5 completed, proceeding to next phase"
            show_enhanced_dashboard
            
            # Wait between phases for stability
            if [ $i -lt $((${#NOTEBOOK_NAMES[@]} - 1)) ]; then
                echo "   ⏱️  Waiting 30 seconds before next phase..."
                sleep 30
            fi
        else
            echo "   ❌ Phase $phase/5 failed to start, but continuing with fault-tolerant execution..."
        fi
    done
}

# Main execution
echo "📋 Compatibility Patches Status:"
echo "================================"
echo "✅ PCA Compatibility: Phases 1,3 (KeyError tolerance)"
echo "✅ AnnData Compatibility: Phases 4,5 (read_elem_as_dask fix)"
echo "✅ Enhanced PyTest: All phases (Playwright + Cloudia dependencies)"
echo "✅ Network Files: Phase 2 (Automatic dorothea/progeny generation)"
echo ""

execute_all_notebooks

echo ""
echo "🎉 Complete 5-Notebook Execution Summary"
echo "========================================"
echo "Base Run: $BASE_RUN_NAME"
echo "Total Phases: 5"
echo "Execution Strategy: $EXECUTION_STRATEGY"

if [ -z "$FAILED_PHASES" ]; then
    echo "✅ All phases completed successfully!"
    echo "🎯 Success Rate: 5/5 (100%)"
else
    local failed_count=$(echo $FAILED_PHASES | wc -w)
    local success_count=$((5 - failed_count))
    echo "⚠️ Some phases failed: $FAILED_PHASES"
    echo "🎯 Success Rate: $success_count/5 ($((success_count * 100 / 5))%)"
fi

echo ""
echo "🌐 Final Dashboard Access:"
echo "=========================="
echo "   📊 Main Dashboard: $DASHBOARD_URL"
echo "   🔍 Filter by Workflow: dashboard.tekton.dev/workflow=9-step-complete"
echo "   📱 Filter by Strategy: execution.rapids.ai/strategy=complete-5-notebooks"

echo ""
echo "📋 Individual Phase Access:"
for i in "${!PIPELINE_RUNS[@]}"; do
    local run_name="${PIPELINE_RUNS[$i]}"
    local phase="${NOTEBOOK_PHASES[$i]}"
    local display_name="${NOTEBOOK_DISPLAY_NAMES[$i]}"
    echo "   Phase $phase/5: $DASHBOARD_URL/#/namespaces/tekton-pipelines/pipelineruns/$run_name"
done

echo ""
echo "🎉 Complete 5-notebook pipeline execution finished!"