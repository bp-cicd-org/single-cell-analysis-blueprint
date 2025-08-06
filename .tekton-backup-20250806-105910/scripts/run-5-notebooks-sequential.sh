#!/bin/bash
# RAPIDS SingleCell Analysis - 5 Notebooks Sequential Execution
# =============================================================

set -euo pipefail

EXECUTION_STRATEGY="${1:-sequential}"
BASE_RUN_NAME="rapids-5nb-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🚀 RAPIDS SingleCell Analysis - 5 Notebooks Sequential Strategy"
echo "=============================================================="
echo "Strategy: ${EXECUTION_STRATEGY}"
echo "Base Run Name: ${BASE_RUN_NAME}"
echo "Dashboard: ${DASHBOARD_URL}"
echo ""

echo "📋 Execution Plan:"
echo "=================="
echo "Phase 1: Notebook 01 (Prerequisites & Preprocessing)"
echo "Phase 2: Notebook 02 (Extended Analysis)"
echo "Phase 3: Notebook 03 (Pearson Residuals)"
echo "Phase 4: Notebook 04 (Dask Out-of-Core)"
echo "Phase 5: Notebook 05 (Multi-GPU)"
echo ""
echo "📊 Each notebook goes through complete 9-step workflow:"
echo "  1. Environment Setup → 2. Git Clone → 3. Dataset Download"
echo "  4. Papermill Execution → 5. NBConvert → 6. Test Framework"
echo "  7. Pytest → 8. Collect Artifacts → 9. Final Summary"
echo ""

# Notebook configurations
declare -a NOTEBOOKS=(
    "01_scRNA_analysis_preprocessing"
    "02_scRNA_analysis_extended"
    "03_scRNA_analysis_with_pearson_residuals"
    "04_scRNA_analysis_dask_out_of_core"
    "05_scRNA_analysis_multi_GPU"
)

declare -a PIPELINE_RUNS=()

# Function to start a notebook pipeline
start_notebook_pipeline() {
    local notebook_name="$1"
    local phase_number="$2"
    local run_name="${BASE_RUN_NAME}-nb$(printf '%02d' $phase_number)"
    
    echo "🚀 Phase ${phase_number}: Starting ${notebook_name}"
    echo "   Run Name: ${run_name}"
    
    # Create PipelineRun
    cat > /tmp/notebook-${phase_number}-run.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${run_name}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: complete-notebook-workflow
    execution.rapids.ai/run: "${BASE_RUN_NAME}"
    execution.rapids.ai/notebook: "${notebook_name}"
    execution.rapids.ai/phase: "${phase_number}"
  annotations:
    description: "RAPIDS ${notebook_name} - Complete 9-Step Workflow"
    execution.tekton.dev/estimated-duration: "3h"
    hardware.tekton.dev/gpu-requirement: "1x A100 80GB"
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
    pipeline_run_name=$(kubectl create -f /tmp/notebook-${phase_number}-run.yaml -o jsonpath='{.metadata.name}')
    PIPELINE_RUNS+=("$pipeline_run_name")
    
    echo "   ✅ Started: ${pipeline_run_name}"
    echo "   🌐 Monitor: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run_name}"
    echo ""
    
    # Cleanup temp file
    rm -f /tmp/notebook-${phase_number}-run.yaml
    
    return 0
}

# Function to wait for pipeline completion
wait_for_pipeline() {
    local pipeline_run_name="$1"
    local phase_number="$2"
    local notebook_name="$3"
    
    echo "⏳ Phase ${phase_number}: Waiting for ${notebook_name} to complete..."
    
    while true; do
        local status
        status=$(kubectl get pipelinerun "$pipeline_run_name" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
        
        case "$status" in
            "Succeeded")
                echo "✅ Phase ${phase_number}: ${notebook_name} completed successfully!"
                return 0
                ;;
            "Failed")
                echo "❌ Phase ${phase_number}: ${notebook_name} failed!"
                echo "   🔍 Error details:"
                kubectl describe pipelinerun "$pipeline_run_name" -n tekton-pipelines | grep -A 5 "Message:"
                return 1
                ;;
            "Running"|"Started")
                echo "   🔄 Phase ${phase_number}: ${notebook_name} running... (Status: $status)"
                sleep 30
                ;;
            *)
                echo "   ⏸️  Phase ${phase_number}: ${notebook_name} pending... (Status: $status)"
                sleep 10
                ;;
        esac
    done
}

# Function to show overall progress
show_progress() {
    echo ""
    echo "📊 Overall Progress Summary:"
    echo "=========================="
    
    for i in "${!PIPELINE_RUNS[@]}"; do
        local pipeline_run="${PIPELINE_RUNS[$i]}"
        local phase=$((i + 1))
        local notebook="${NOTEBOOKS[$i]}"
        
        if [ -n "$pipeline_run" ]; then
            local status
            status=$(kubectl get pipelinerun "$pipeline_run" -n tekton-pipelines -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
            
            case "$status" in
                "Succeeded") echo "   ✅ Phase ${phase}: ${notebook}" ;;
                "Failed") echo "   ❌ Phase ${phase}: ${notebook}" ;;
                "Running"|"Started") echo "   🔄 Phase ${phase}: ${notebook}" ;;
                *) echo "   ⏳ Phase ${phase}: ${notebook}" ;;
            esac
        else
            echo "   ⭕ Phase ${phase}: ${notebook} (Not started)"
        fi
    done
    echo ""
}

# Main execution
echo "🎬 Starting 5-Notebook Sequential Execution"
echo "==========================================="

# Execute notebooks sequentially
for i in "${!NOTEBOOKS[@]}"; do
    notebook="${NOTEBOOKS[$i]}"
    phase=$((i + 1))
    
    # Start the notebook pipeline
    if start_notebook_pipeline "$notebook" "$phase"; then
        pipeline_run="${PIPELINE_RUNS[-1]}"  # Get the last added pipeline run
        
        # Wait for completion before starting next
        if wait_for_pipeline "$pipeline_run" "$phase" "$notebook"; then
            echo "   ✅ Phase ${phase} completed, proceeding to next phase"
            show_progress
        else
            echo "   ❌ Phase ${phase} failed, stopping execution"
            show_progress
            echo ""
            echo "🚨 Execution stopped due to failure in Phase ${phase}"
            echo "📊 To check details:"
            echo "   kubectl describe pipelinerun ${pipeline_run} -n tekton-pipelines"
            echo "   Dashboard: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
            exit 1
        fi
    else
        echo "❌ Failed to start Phase ${phase}"
        exit 1
    fi
    
    # Add delay between phases
    if [ $phase -lt ${#NOTEBOOKS[@]} ]; then
        echo "   ⏱️  Waiting 30 seconds before next phase..."
        sleep 30
    fi
done

# Final summary
echo ""
echo "🎉 All 5 Notebooks Completed Successfully!"
echo "========================================"
echo "Base Run: ${BASE_RUN_NAME}"
echo "Strategy: ${EXECUTION_STRATEGY}"
echo "Duration: $(date)"
echo ""

echo "📊 Final Results:"
show_progress

echo "🌐 Access Results:"
echo "=================="
for i in "${!PIPELINE_RUNS[@]}"; do
    pipeline_run="${PIPELINE_RUNS[$i]}"
    phase=$((i + 1))
    notebook="${NOTEBOOKS[$i]}"
    echo "   Phase ${phase} (${notebook}):"
    echo "     Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${pipeline_run}"
done

echo ""
echo "📁 Artifacts Location: /workspace/shared/pipeline-runs/"
echo "🎯 Integration Report: Will be available in shared workspace"
echo ""
echo "✨ 5-Notebook Sequential Strategy Execution Completed! ✨"