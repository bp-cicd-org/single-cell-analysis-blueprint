#!/bin/bash
set -eu

# Access Notebook 01 Results - Immediate Download Script
# =====================================================

echo "🚀 RAPIDS Notebook 01 Results Access"
echo "===================================="

# Try multiple methods to access the artifacts

echo ""
echo "📋 Method 1: Check existing artifact servers"
echo "============================================"

# Check if we have any existing web servers running
EXISTING_SERVERS=$(kubectl get pods -n tekton-pipelines | grep -E "(artifact|web)" | grep Running | head -3)

if [ -n "$EXISTING_SERVERS" ]; then
  echo "✅ Found existing artifact servers:"
  echo "$EXISTING_SERVERS"
  
  # Try to get services for these servers
  echo ""
  echo "🔍 Checking services for artifact access:"
  kubectl get svc -n tekton-pipelines | grep -E "(artifact|web)" || echo "No artifact services found"
  
  echo ""
  echo "🌐 Checking ingress for web access:"
  kubectl get ingress -n tekton-pipelines | grep -E "(artifact|web)" || echo "No artifact ingress found"
  
  # Try to check if any of these servers have our artifacts
  for server in gpu-artifacts-web gpu-workflow-artifacts-web artifact-web-server; do
    echo ""
    echo "🔍 Checking server: $server"
    if kubectl get pod $server -n tekton-pipelines >/dev/null 2>&1; then
      echo "  ✅ Pod exists, trying to access..."
      
      # Try different common paths
      for path in "/artifacts" "/app" "/var/www" "/workspace" "/data" "/shared-storage"; do
        echo "    🔍 Checking path: $path"
        if kubectl exec -it $server -n tekton-pipelines -- ls -la $path/ 2>/dev/null | head -3; then
          echo "    ✅ Found content in $path"
          break
        fi
      done
    fi
  done
fi

echo ""
echo "📋 Method 2: Create temporary access pod"
echo "======================================="

# Create a temporary pod to access shared storage
cat << 'PODEOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: notebook-results-access
  namespace: tekton-pipelines
  labels:
    app: rapids-results-access
spec:
  containers:
  - name: access
    image: alpine:latest
    command: ["sleep", "300"]
    volumeMounts:
    - name: shared-storage
      mountPath: /workspace/shared-storage
  volumes:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: shared-workspace-pvc
  restartPolicy: Never
PODEOF

echo "⏳ Waiting for access pod to start..."
kubectl wait --for=condition=Ready pod/notebook-results-access -n tekton-pipelines --timeout=60s

if [ $? -eq 0 ]; then
  echo "✅ Access pod ready!"
  
  echo ""
  echo "🔍 Exploring shared storage structure:"
  echo "====================================="
  kubectl exec -it notebook-results-access -n tekton-pipelines -- sh -c "
    echo '📁 Root directory:'
    ls -la /workspace/shared-storage/ | head -10
    
    echo ''
    echo '📁 Pipeline runs directory:'
    ls -la /workspace/shared-storage/pipeline-runs/ 2>/dev/null | head -10 || echo 'No pipeline-runs directory found'
    
    echo ''
    echo '📁 Looking for HTML files:'
    find /workspace/shared-storage -name '*.html' -type f 2>/dev/null | head -5 || echo 'No HTML files found'
    
    echo ''
    echo '📁 Looking for notebooks:'
    find /workspace/shared-storage -name '*.ipynb' -type f 2>/dev/null | head -5 || echo 'No notebook files found'
    
    echo ''
    echo '📁 Looking for artifacts directories:'
    find /workspace/shared-storage -name 'artifacts' -type d 2>/dev/null | head -5 || echo 'No artifacts directories found'
  "
  
  echo ""
  echo "🎯 DOWNLOAD COMMANDS FOR YOUR LOCAL MACHINE:"
  echo "==========================================="
  echo "# Download the main HTML report:"
  echo "kubectl cp tekton-pipelines/notebook-results-access:/workspace/shared-storage/output_analysis.html ./notebook01-result.html"
  echo ""
  echo "# Download executed notebook:"
  echo "kubectl cp tekton-pipelines/notebook-results-access:/workspace/shared-storage/output_analysis.ipynb ./notebook01-result.ipynb"
  echo ""
  echo "# List all available files for download:"
  echo "kubectl exec -it notebook-results-access -n tekton-pipelines -- find /workspace/shared-storage -type f -name '*.html' -o -name '*.ipynb' -o -name '*.xml'"
  
  echo ""
  echo "🔧 Clean up command:"
  echo "kubectl delete pod notebook-results-access -n tekton-pipelines"
  
else
  echo "❌ Failed to start access pod"
  echo "🔍 Check pod status:"
  kubectl describe pod notebook-results-access -n tekton-pipelines
fi

echo ""
echo "📋 Method 3: Direct service access (if available)"
echo "=============================================="

# Check for any LoadBalancer or NodePort services that might expose artifacts
kubectl get svc -n tekton-pipelines -o wide | grep -E "(LoadBalancer|NodePort)" || echo "No external services found"

echo ""
echo "🎉 ACCESS SUMMARY"
echo "================"
echo "1. ✅ Use the temporary pod access method above"
echo "2. 🌐 Check existing web servers for artifact access"
echo "3. 📥 Download files directly using kubectl cp commands"
echo ""
echo "📝 Note: The newest completed notebook is from pipeline:"
echo "   phase-1of5-preprocessing-rapids-5nb-20250806-074859-rlgwf"