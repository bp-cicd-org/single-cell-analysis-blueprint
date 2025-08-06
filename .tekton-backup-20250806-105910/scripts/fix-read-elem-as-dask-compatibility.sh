#!/bin/bash
set -eu

# Fix read_elem_as_dask Compatibility Issue
# =======================================
# This script creates a compatibility patch for anndata 0.12+ 
# where read_elem_as_dask was renamed to read_elem_lazy
# WITHOUT modifying the original notebook files

echo "🔧 Creating AnnData read_elem_as_dask Compatibility Patch"
echo "========================================================"

# Create a compatibility task that provides backward compatibility
cat << 'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: anndata-compatibility-patch
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: anndata-compatibility-patch
    app.kubernetes.io/component: tekton-task
    app.kubernetes.io/version: "1.0.0"
spec:
  description: |
    Creates backward compatibility for read_elem_as_dask function
    in anndata 0.12+ without modifying original notebook files.
    
  params:
  - name: notebook-name
    type: string
    description: Name of the notebook being processed
    
  workspaces:
  - name: shared-storage
    description: Workspace for compatibility setup
    
  steps:
  - name: create-compatibility-patch
    image: nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12
    securityContext:
      runAsUser: 0
    env:
    - name: NOTEBOOK_NAME
      value: $(params.notebook-name)
    script: |
      #!/bin/bash
      set -eu
      
      echo "🔧 AnnData Compatibility Patch for $NOTEBOOK_NAME"
      echo "=============================================="
      
      cd "$(workspaces.shared-storage.path)"
      
      # Only apply patch for notebooks 04 and 05 that use read_elem_as_dask
      if [ "$NOTEBOOK_NAME" = "04_scRNA_analysis_dask_out_of_core" ] || [ "$NOTEBOOK_NAME" = "05_scRNA_analysis_multi_GPU" ]; then
          echo "📝 Creating compatibility patch for $NOTEBOOK_NAME..."
          
          # Create a Python compatibility module that provides backward compatibility
          mkdir -p compatibility_patches
          
          cat > compatibility_patches/anndata_compat.py << 'PYEOF'
"""
AnnData Backward Compatibility Module
=====================================
This module provides backward compatibility for anndata 0.12+ changes
without modifying the original notebook files.

In anndata 0.12.0, read_elem_as_dask was renamed to read_elem_lazy.
This module monkey-patches the old function name to work with new versions.
"""

import sys
import warnings

def setup_read_elem_as_dask_compatibility():
    """Setup backward compatibility for read_elem_as_dask function."""
    try:
        # Try to import the new function
        from anndata.experimental import read_elem_lazy
        
        # Check if the old function doesn't exist
        try:
            from anndata.experimental import read_elem_as_dask
            print("✅ read_elem_as_dask already available - no patch needed")
        except ImportError:
            # Create backward compatibility by adding the old name
            import anndata.experimental
            anndata.experimental.read_elem_as_dask = read_elem_lazy
            
            print("🔧 Applied backward compatibility patch: read_elem_as_dask -> read_elem_lazy")
            print(f"✅ anndata.experimental.read_elem_as_dask is now available")
            
    except ImportError as e:
        print(f"⚠️ Cannot setup compatibility patch: {e}")
        print("   This may cause notebook execution to fail")

if __name__ == "__main__":
    setup_read_elem_as_dask_compatibility()
PYEOF
          
          # Create a startup script that applies the patch
          cat > compatibility_patches/apply_anndata_patch.py << 'PYEOF'
#!/usr/bin/env python3
"""
Apply AnnData compatibility patches before notebook execution.
This ensures notebooks can run without modification.
"""

import os
import sys

# Add compatibility patches to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

# Apply the compatibility patch
from anndata_compat import setup_read_elem_as_dask_compatibility
setup_read_elem_as_dask_compatibility()

print("🎯 AnnData compatibility patches applied successfully")
PYEOF
          
          chmod +x compatibility_patches/apply_anndata_patch.py
          
          echo "✅ Compatibility patch created successfully"
          echo "📁 Files created:"
          echo "   - compatibility_patches/anndata_compat.py"
          echo "   - compatibility_patches/apply_anndata_patch.py"
          
      else
          echo "ℹ️ No compatibility patch needed for $NOTEBOOK_NAME"
      fi
      
      echo "✅ Compatibility patch task completed"
EOF

echo "✅ AnnData compatibility patch task deployed"

# Test the compatibility patch
echo ""
echo "🧪 Testing AnnData compatibility patch..."

cat << EOF | kubectl create -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: test-anndata-compat-
  namespace: tekton-pipelines
  labels:
    app: test-anndata-compat
spec:
  serviceAccountName: tekton-gpu-executor
  taskRef:
    name: anndata-compatibility-patch
  params:
  - name: notebook-name
    value: "04_scRNA_analysis_dask_out_of_core"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF

echo "✅ Compatibility test TaskRun created"
echo ""
echo "🔍 Monitor the test:"
echo "kubectl get taskruns -n tekton-pipelines -l app=test-anndata-compat"
echo ""
echo "📄 View logs:"
echo "kubectl logs -n tekton-pipelines -l app=test-anndata-compat -f"
echo ""
echo "📋 Usage in pipeline:"
echo "   This compatibility patch should be applied BEFORE papermill execution"
echo "   in Step 4 of the complete-notebook-workflow for notebooks 04 and 05."