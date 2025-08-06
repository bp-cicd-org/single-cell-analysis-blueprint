#!/bin/bash
set -eu

# Simple Fix for Notebook 02 Network Files
# =========================================

echo "🔧 Fixing Notebook 02 Network Files (Simple Method)"
echo "=================================================="

# Create network files directly in shared storage
echo "📋 Step 1: Accessing shared storage directly"

# Find a running pod to execute in
RUNNING_POD=$(kubectl get pods -n tekton-pipelines --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$RUNNING_POD" ]; then
    echo "🚀 No running pods found. Creating a simple pod for file generation..."
    
    # Create a simple pod
    kubectl run fix-notebook02-nets --image=nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12 \
        --restart=Never \
        --rm -i --tty \
        --serviceaccount=tekton-gpu-executor \
        --namespace=tekton-pipelines \
        --overrides='{"spec":{"containers":[{"name":"fix-notebook02-nets","image":"nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12","volumeMounts":[{"name":"shared-storage","mountPath":"/workspace/shared-storage"}],"command":["/bin/bash","-c","sleep 300"]}],"volumes":[{"name":"shared-storage","persistentVolumeClaim":{"claimName":"source-code-workspace"}}]}}' \
        -- sleep 300 &
    
    # Wait a bit for pod to start
    sleep 10
    RUNNING_POD="fix-notebook02-nets"
fi

echo "📋 Using pod: $RUNNING_POD"

# Generate network files
echo "📦 Step 2: Installing decoupler and generating files..."

kubectl exec -n tekton-pipelines $RUNNING_POD -- bash -c "
cd /workspace/shared-storage
echo '🔧 Starting network file generation...'

# Install required packages
pip install -q decoupler omnipath pandas pyarrow

# Create nets directory
mkdir -p nets
cd nets

echo '📥 Generating dorothea.parquet...'
python3 -c \"
import decoupler as dc
import pandas as pd
import os

print('🔍 Downloading Dorothea network...')
dorothea_df = dc.get_dorothea(organism='human', levels=['A', 'B', 'C'])
print(f'✅ Dorothea network shape: {dorothea_df.shape}')
dorothea_df.to_parquet('dorothea.parquet', index=False)
print('✅ dorothea.parquet saved successfully')

print('🔍 Downloading PROGENy network...')
progeny_df = dc.get_progeny(organism='human', top=500)
print(f'✅ PROGENy network shape: {progeny_df.shape}')
progeny_df.to_parquet('progeny.parquet', index=False)
print('✅ progeny.parquet saved successfully')

# Display file info
for file in ['dorothea.parquet', 'progeny.parquet']:
    if os.path.exists(file):
        size = os.path.getsize(file)
        print(f'📁 {file}: {size:,} bytes ({size/1024/1024:.2f} MB)')
\"

echo '✅ Network files generated!'
ls -la dorothea.parquet progeny.parquet

echo '🔍 Verifying files...'
python3 -c \"
import pandas as pd
df1 = pd.read_parquet('dorothea.parquet')
print(f'✅ dorothea.parquet: {df1.shape[0]} rows, {df1.shape[1]} columns')
df2 = pd.read_parquet('progeny.parquet')
print(f'✅ progeny.parquet: {df2.shape[0]} rows, {df2.shape[1]} columns')
print('🎉 All files verified successfully!')
\"
"

echo ""
echo "🎉 Network files generation completed!"
echo "===================================="

# Check if files exist
echo "📋 Verifying files in shared storage..."
kubectl exec -n tekton-pipelines $RUNNING_POD -- ls -la /workspace/shared-storage/nets/ 2>/dev/null || echo "Files not found yet"

echo ""
echo "🚀 Notebook 02 should now be ready to run!"
echo "==========================================="
echo ""
echo "📋 Next steps:"
echo "1. ✅ Network files generated (dorothea.parquet, progeny.parquet)"
echo "2. 🚀 Run Notebook 02: ./.tekton/scripts/run-5-notebooks-enhanced-ui.sh"
echo "3. 📊 Monitor progress on Tekton Dashboard"

# Clean up the temporary pod if we created it
if [ "$RUNNING_POD" = "fix-notebook02-nets" ]; then
    echo "🧹 Cleaning up temporary pod..."
    kubectl delete pod fix-notebook02-nets -n tekton-pipelines --ignore-not-found=true
fi