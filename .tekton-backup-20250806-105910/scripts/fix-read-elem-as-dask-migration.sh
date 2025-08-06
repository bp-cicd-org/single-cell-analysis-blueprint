#!/bin/bash
set -eu

# Fix read_elem_as_dask Migration to read_elem_lazy
# =================================================

echo "🔧 Fixing read_elem_as_dask → read_elem_lazy Migration"
echo "===================================================="

# Create a replacement task that provides compatibility layer for read_elem_as_dask
cat << 'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: anndata-migration-fix-task
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: anndata-migration-fix-task
    app.kubernetes.io/component: tekton-task
    app.kubernetes.io/version: "1.0.0"
spec:
  description: |
    Fix anndata read_elem_as_dask migration to read_elem_lazy.
    This task provides a compatibility layer for notebooks that use the old API.
    
  params:
  - name: notebook-name
    type: string
    description: Name of the notebook being processed
    
  workspaces:
  - name: shared-storage
    description: Workspace for patching
    
  steps:
  - name: apply-migration-fix
    image: nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12
    securityContext:
      runAsUser: 0
    env:
    - name: NOTEBOOK_NAME
      value: $(params.notebook-name)
    script: |
      #!/bin/bash
      set -eu
      
      echo "🔧 AnnData Migration Fix"
      echo "======================="
      
      cd "$(workspaces.shared-storage.path)"
      
      # Check if this notebook needs the migration fix
      if [ "$NOTEBOOK_NAME" = "04_scRNA_analysis_dask_out_of_core" ] || [ "$NOTEBOOK_NAME" = "05_scRNA_analysis_multi_GPU" ]; then
          echo "📋 Applying read_elem_as_dask → read_elem_lazy migration for $NOTEBOOK_NAME"
          
          # Install latest anndata with the new API
          echo "📦 Installing latest anndata with read_elem_lazy support..."
          python -m pip install --user --upgrade "anndata>=0.12.0"
          
          # Create a compatibility module for backward compatibility
          echo "🔗 Creating compatibility module..."
          mkdir -p /tmp/anndata_compat
          cat > /tmp/anndata_compat/__init__.py << 'COMPAT_EOF'
"""
Compatibility module for anndata read_elem_as_dask migration.
This provides backward compatibility for notebooks using the old API.
"""
import warnings

def read_elem_as_dask(*args, **kwargs):
    """Compatibility wrapper for the old read_elem_as_dask function."""
    warnings.warn(
        "read_elem_as_dask is deprecated and has been renamed to read_elem_lazy. "
        "Please update your code to use anndata.experimental.read_elem_lazy instead.",
        DeprecationWarning,
        stacklevel=2
    )
    
    try:
        from anndata.experimental import read_elem_lazy
        return read_elem_lazy(*args, **kwargs)
    except ImportError:
        raise ImportError(
            "anndata.experimental.read_elem_lazy is not available. "
            "Please upgrade anndata to version >=0.12.0"
        )

# Monkey patch the anndata.experimental module
try:
    import anndata.experimental
    if not hasattr(anndata.experimental, 'read_elem_as_dask'):
        anndata.experimental.read_elem_as_dask = read_elem_as_dask
        print("✅ Applied compatibility patch for read_elem_as_dask")
except ImportError:
    print("⚠️ Could not import anndata.experimental")
COMPAT_EOF
          
          # Add the compatibility module to Python path
          export PYTHONPATH="/tmp/anndata_compat:$PYTHONPATH"
          
          # Test the migration
          echo "🧪 Testing migration fix..."
          python -c "
try:
    from anndata.experimental import read_elem_lazy
    print('✅ read_elem_lazy is available')
    
    # Test the compatibility wrapper
    import sys
    sys.path.insert(0, '/tmp/anndata_compat')
    import anndata_compat
    from anndata.experimental import read_elem_as_dask
    print('✅ read_elem_as_dask compatibility wrapper is available')
    
    print('✅ Migration test completed successfully')
except Exception as e:
    print(f'❌ Migration test failed: {e}')
    exit(1)
"
          
          # Verify enhanced anndata installation
          echo "🔍 Final verification for $NOTEBOOK_NAME..."
          python -c "
import anndata
print(f'✅ anndata version: {anndata.__version__}')

try:
    from anndata.experimental import read_elem_lazy
    print('✅ read_elem_lazy is available')
except ImportError as e:
    print(f'❌ read_elem_lazy not available: {e}')
    exit(1)

import dask
print(f'✅ dask version: {dask.__version__}')

try:
    import h5py
    print(f'✅ h5py version: {h5py.__version__}')
except ImportError as e:
    print(f'⚠️ h5py not available: {e}')
"
          
          echo "✅ Migration fix completed successfully for $NOTEBOOK_NAME"
      else
          echo "ℹ️ No migration fix needed for $NOTEBOOK_NAME"
      fi
      
      echo "✅ AnnData migration task completed"
EOF

echo "✅ AnnData migration fix task deployed"

# Test the migration fix
echo ""
echo "🧪 Testing migration fix with Notebook 04..."

cat << EOF | kubectl create -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: test-migration-fix-
  namespace: tekton-pipelines
  labels:
    app: test-migration-fix
spec:
  serviceAccountName: tekton-gpu-executor
  taskRef:
    name: anndata-migration-fix-task
  params:
  - name: notebook-name
    value: "04_scRNA_analysis_dask_out_of_core"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF

echo "✅ Migration fix test TaskRun created"
echo ""
echo "🔍 Monitor the test:"
echo "kubectl get taskruns -n tekton-pipelines -l app=test-migration-fix"
echo ""
echo "📄 View logs:"
echo "kubectl logs -n tekton-pipelines -l app=test-migration-fix -f"