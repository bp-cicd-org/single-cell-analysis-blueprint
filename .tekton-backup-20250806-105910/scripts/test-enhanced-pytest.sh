#!/bin/bash
set -eu

# Test Enhanced PyTest Task
# =========================

echo "🧪 Testing Enhanced PyTest Task"
echo "==============================="

# Create a simple test TaskRun
cat << EOF | kubectl create -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: test-enhanced-pytest-
  namespace: tekton-pipelines
  labels:
    app: test-enhanced-pytest
spec:
  serviceAccountName: tekton-gpu-executor
  taskRef:
    name: pytest-execution-enhanced
  params:
  - name: html-input-file
    value: "output_analysis.html"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF

echo "✅ Enhanced pytest test TaskRun created"
echo ""
echo "🔍 Monitor execution:"
echo "kubectl get taskruns -n tekton-pipelines -l app=test-enhanced-pytest"
echo ""
echo "📄 View logs:"
echo "kubectl logs -n tekton-pipelines -l app=test-enhanced-pytest -f"