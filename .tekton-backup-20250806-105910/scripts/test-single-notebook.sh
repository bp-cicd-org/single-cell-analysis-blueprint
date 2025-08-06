#!/bin/bash
# Test Single Notebook with Complete Processing
# ============================================

set -euo pipefail

NOTEBOOK_NAME="01_scRNA_analysis_preprocessing"
RUN_NAME="test-single-$(date +%Y%m%d-%H%M%S)"
DASHBOARD_URL="https://tekton.10.34.2.129.nip.io"

echo "🧪 Testing Single Notebook with Complete Processing"
echo "================================================="
echo "Notebook: ${NOTEBOOK_NAME}"
echo "Run Name: ${RUN_NAME}"
echo "Dashboard: ${DASHBOARD_URL}"
echo ""

# Create a simple PipelineRun for testing
cat > /tmp/test-single-notebook.yaml << EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: test-single-${RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: test-single-notebook
    execution.rapids.ai/run: "${RUN_NAME}"
  annotations:
    description: "Test single notebook with complete processing flow"
spec:
  pipelineSpec:
    params:
    - name: execution-run-name
      type: string
      default: "${RUN_NAME}"
      
    workspaces:
    - name: shared-storage
      description: Shared workspace for testing
      
    tasks:
    
    # Setup Environment
    - name: setup-environment
      taskSpec:
        workspaces:
        - name: shared-storage
        steps:
        - name: setup
          image: nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12
          securityContext:
            runAsUser: 0
          script: |
            #!/bin/bash
            set -eu
            echo "🎯 Test Environment Setup"
            cd "\$(workspaces.shared-storage.path)"
            mkdir -p {outputs,logs,artifacts,input}
            chmod -R 777 .
            pip install --quiet --no-cache-dir --upgrade \
              jupyter papermill nbconvert \
              rapids-singlecell scanpy anndata \
              wget pytest pytest-html \
              dask dask-cuda
            echo "✅ Environment setup completed"
      workspaces:
      - name: shared-storage
        workspace: shared-storage
        
    # Clone Repository
    - name: clone-repository
      taskRef:
        name: safe-git-clone
      params:
      - name: git-repo-url
        value: "https://github.com/NVIDIA-AI-Blueprints/single-cell-analysis-blueprint.git"
      - name: workspace-subdir
        value: "single-cell-analysis-blueprint"
      runAfter: ["setup-environment"]
      workspaces:
      - name: source-workspace
        workspace: shared-storage
        
    # Execute Notebook with Complete Processing
    - name: execute-notebook
      taskRef:
        name: gpu-notebook-executor-task
      params:
      - name: notebook-name
        value: "${NOTEBOOK_NAME}"
      - name: execution-timeout
        value: "3600"
      - name: min-gpu-memory-gb
        value: "24"
      - name: pipeline-run-name
        value: "${RUN_NAME}"
      - name: save-outputs
        value: "true"
      runAfter: ["clone-repository"]
      workspaces:
      - name: shared-storage
        workspace: shared-storage
        
  params:
  - name: execution-run-name
    value: "${RUN_NAME}"
    
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
      
  timeouts:
    pipeline: "2h"
    tasks: "1h"
EOF

# Submit the test
PIPELINE_RUN_NAME=$(kubectl create -f /tmp/test-single-notebook.yaml -o jsonpath='{.metadata.name}')

echo "✅ Test started: ${PIPELINE_RUN_NAME}"
echo ""
echo "🌐 Monitoring Links:"
echo "  Pipeline: ${DASHBOARD_URL}/#/namespaces/tekton-pipelines/pipelineruns/${PIPELINE_RUN_NAME}"
echo "  Dashboard: ${DASHBOARD_URL}"
echo ""
echo "📊 CLI Monitoring:"
echo "  kubectl get pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines -w"
echo "  kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME}"
echo ""

# Ask if user wants to monitor
read -p "Monitor execution progress? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🎯 📊 Monitoring Test Execution"
    echo "=========================="
    echo "Pipeline: ${PIPELINE_RUN_NAME}"
    echo ""
    
    # Monitor with shorter timeout for testing
    if kubectl wait --for=condition=Succeeded pipelinerun/${PIPELINE_RUN_NAME} -n tekton-pipelines --timeout=3600s; then
        echo "✅ 🎉 Test completed successfully!"
        
        # Show results
        echo ""
        echo "📋 Test Results:"
        kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=${PIPELINE_RUN_NAME} -o custom-columns="TASK:.metadata.labels.tekton\.dev/pipelineTask,STATUS:.status.conditions[0].reason,DURATION:.status.completionTime"
        
    elif kubectl wait --for=condition=Failed pipelinerun/${PIPELINE_RUN_NAME} -n tekton-pipelines --timeout=1s; then
        echo "❌ Test execution failed"
        
        # Show failure details
        echo "🔍 Checking failure details..."
        kubectl describe pipelinerun ${PIPELINE_RUN_NAME} -n tekton-pipelines | grep -A 10 "Conditions:"
        
    else
        echo "⏱️  Test is still running"
        echo "Continue monitoring with dashboard: ${DASHBOARD_URL}"
    fi
else
    echo "Test started. Monitor progress using the dashboard links above."
fi

# Cleanup
rm -f /tmp/test-single-notebook.yaml