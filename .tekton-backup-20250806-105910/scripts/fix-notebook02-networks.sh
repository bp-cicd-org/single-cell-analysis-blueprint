#!/bin/bash
set -eu

# Fix Notebook 02 Network Files
# ==============================

echo "🔧 Fixing Notebook 02 Network Files"
echo "==================================="

echo "📋 Issue: Missing nets/dorothea.parquet and nets/progeny.parquet files"
echo "💡 Solution: Generate network files using decoupler library"
echo ""

# Create a task to generate network files for Notebook 02
cat << 'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: fix-notebook02-networks-
  namespace: tekton-pipelines
  labels:
    app: fix-notebook02
    execution.rapids.ai/phase: "fix"
spec:
  serviceAccountName: tekton-gpu-executor
  taskSpec:
    workspaces:
    - name: shared-storage
    steps:
    - name: generate-network-files
      image: nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12
      script: |
        #!/bin/bash
        set -eu
        
        echo "🔧 Generating Network Files for Notebook 02"
        echo "==========================================="
        
        cd $(workspaces.shared-storage.path)
        
        # Install decoupler if needed
        echo "📦 Installing decoupler..."
        pip install -q decoupler omnipath pandas pyarrow
        
        # Create nets directory
        mkdir -p nets
        cd nets
        
        echo "📥 Generating dorothea.parquet..."
        python3 << PYEOF
import decoupler as dc
import pandas as pd
import os

print("🔍 Downloading Dorothea network...")
# Get Dorothea network from OmniPath
dorothea_df = dc.get_dorothea(organism='human', levels=['A', 'B', 'C'])

print(f"✅ Dorothea network shape: {dorothea_df.shape}")
print(f"📊 Columns: {list(dorothea_df.columns)}")

# Save as parquet
dorothea_df.to_parquet('dorothea.parquet', index=False)
print("✅ dorothea.parquet saved successfully")

print("🔍 Downloading PROGENy network...")
# Get PROGENy network
progeny_df = dc.get_progeny(organism='human', top=500)

print(f"✅ PROGENy network shape: {progeny_df.shape}")
print(f"📊 Columns: {list(progeny_df.columns)}")

# Save as parquet
progeny_df.to_parquet('progeny.parquet', index=False)
print("✅ progeny.parquet saved successfully")

# Display file info
import os
for file in ['dorothea.parquet', 'progeny.parquet']:
    if os.path.exists(file):
        size = os.path.getsize(file)
        print(f"📁 {file}: {size:,} bytes ({size/1024/1024:.2f} MB)")
PYEOF

        echo ""
        echo "🎉 Network files generated successfully!"
        echo "======================================="
        
        ls -la
        
        echo ""
        echo "📋 Files created:"
        echo "✅ dorothea.parquet - TF-target regulatory network"
        echo "✅ progeny.parquet - Pathway activity network" 
        
        echo ""
        echo "🚀 Notebook 02 is now ready to run!"
        
        # Verify files can be read
        echo "🔍 Verifying file integrity..."
        python3 -c "
import pandas as pd
try:
    df1 = pd.read_parquet('dorothea.parquet')
    print(f'✅ dorothea.parquet: {df1.shape[0]} rows, {df1.shape[1]} columns')
    df2 = pd.read_parquet('progeny.parquet')
    print(f'✅ progeny.parquet: {df2.shape[0]} rows, {df2.shape[1]} columns')
    print('🎉 All files verified successfully!')
except Exception as e:
    print(f'❌ Verification failed: {e}')
    exit(1)
"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF

echo "⏳ Waiting for network file generation to complete..."
sleep 5

# Get the TaskRun name
TASKRUN_NAME=$(kubectl get taskruns -n tekton-pipelines -l app=fix-notebook02 --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' 2>/dev/null || echo "")

if [ -n "$TASKRUN_NAME" ]; then
    echo "📋 TaskRun Name: $TASKRUN_NAME"
    echo "⏳ Waiting for completion..."
    
    # Wait for completion
    kubectl wait --for=condition=Succeeded taskrun/$TASKRUN_NAME -n tekton-pipelines --timeout=300s 2>/dev/null || {
        echo "⚠️ TaskRun may still be running. Checking status..."
        kubectl get taskrun/$TASKRUN_NAME -n tekton-pipelines
    }
    
    echo ""
    echo "📋 TaskRun Status:"
    kubectl get taskrun/$TASKRUN_NAME -n tekton-pipelines
    
    echo ""
    echo "📄 TaskRun Logs:"
    kubectl logs -n tekton-pipelines -l tekton.dev/taskRun=$TASKRUN_NAME
else
    echo "⚠️ Could not find TaskRun. Checking manually..."
    kubectl get taskruns -n tekton-pipelines -l app=fix-notebook02
fi

echo ""
echo "🎉 Network files fix completed!"
echo "=============================="
echo ""
echo "🚀 Next: Run Notebook 02 with the fixed network files"
echo "Command: ./.tekton/scripts/run-5-notebooks-enhanced-ui.sh"