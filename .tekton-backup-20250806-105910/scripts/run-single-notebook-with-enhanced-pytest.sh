#!/bin/bash
set -eu

# Test Single Notebook with Enhanced PyTest
# ==========================================

echo "🚀 Testing Single Notebook with Enhanced PyTest"
echo "==============================================="

NOTEBOOK_NAME="${1:-01_scRNA_analysis_preprocessing}"
RUN_NAME="test-enhanced-${NOTEBOOK_NAME}-$(date +%Y%m%d-%H%M%S)"

echo "📋 Configuration:"
echo "  Notebook: $NOTEBOOK_NAME"
echo "  Run Name: $RUN_NAME"

# Create a PipelineRun with enhanced pytest
cat << EOF | kubectl create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${RUN_NAME}-
  namespace: tekton-pipelines
  labels:
    app: test-enhanced-pytest
    notebook: $NOTEBOOK_NAME
  annotations:
    description: "Testing enhanced pytest with $NOTEBOOK_NAME"
spec:
  serviceAccountName: tekton-gpu-executor
  pipelineRef:
    name: complete-notebook-workflow
  params:
  - name: notebook-name
    value: "$NOTEBOOK_NAME"
  - name: pipeline-run-name
    value: "$RUN_NAME"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
  timeout: 2h
EOF

echo "✅ Enhanced pytest test PipelineRun created"
echo ""
echo "🔍 Monitor execution:"
echo "kubectl get pipelineruns -n tekton-pipelines -l app=test-enhanced-pytest"
echo ""
echo "🌐 Dashboard:"
echo "https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelineruns"