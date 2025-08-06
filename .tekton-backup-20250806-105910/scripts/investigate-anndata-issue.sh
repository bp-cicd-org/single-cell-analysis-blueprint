#!/bin/bash
set -eu

# Investigate AnnData read_elem_as_dask Issue
# ===========================================

echo "🔍 Investigating AnnData read_elem_as_dask Issue"
echo "=============================================="

# Create a task to investigate what's available in anndata.experimental
cat << 'EOF' | kubectl create -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: investigate-anndata-
  namespace: tekton-pipelines
  labels:
    app: investigate-anndata
spec:
  serviceAccountName: tekton-gpu-executor
  taskSpec:
    workspaces:
    - name: shared-storage
    steps:
    - name: investigate
      image: nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12
      script: |
        #!/bin/bash
        set -eu
        
        echo "🔍 Investigating AnnData Experimental Module"
        echo "==========================================="
        
        # Check anndata version
        python -c "import anndata; print('AnnData version:', anndata.__version__)"
        
        # List what's available in anndata.experimental
        echo "📋 Available in anndata.experimental:"
        python -c "import anndata.experimental; print(dir(anndata.experimental))"
        
        # Check if read_elem_as_dask exists in different locations
        echo "🔍 Searching for read_elem_as_dask..."
        python -c "
import anndata
import inspect

def find_dask_functions():
    print('Searching in anndata module...')
    for name in dir(anndata):
        if 'dask' in name.lower():
            print(f'  Found: anndata.{name}')
    
    print('Searching in anndata.experimental...')
    try:
        import anndata.experimental
        for name in dir(anndata.experimental):
            if 'dask' in name.lower() or 'read' in name.lower():
                print(f'  Found: anndata.experimental.{name}')
    except Exception as e:
        print(f'  Error: {e}')
    
    # Check if there's a different import path
    print('Checking alternative imports...')
    try:
        from anndata import read_h5ad
        print('  ✅ anndata.read_h5ad available')
    except:
        print('  ❌ anndata.read_h5ad not available')
    
    try:
        import scanpy as sc
        print('  ✅ scanpy available')
        if hasattr(sc, 'read_h5ad'):
            print('  ✅ scanpy.read_h5ad available')
    except:
        print('  ❌ scanpy not available')

find_dask_functions()
"
        
        # Check the actual notebooks to see how they're trying to import
        echo "📋 Checking notebook import patterns..."
        cd "$(workspaces.shared-storage.path)"
        
        if [ -d "single-cell-analysis-blueprint/notebooks" ]; then
            echo "🔍 Searching for read_elem_as_dask usage in notebooks..."
            grep -r "read_elem_as_dask" single-cell-analysis-blueprint/notebooks/ || echo "No direct usage found"
            
            echo "🔍 Searching for dask imports in notebooks..."
            grep -r "import.*dask\|from.*dask" single-cell-analysis-blueprint/notebooks/ || echo "No dask imports found"
            
            echo "🔍 Searching for anndata.experimental imports..."
            grep -r "anndata.experimental" single-cell-analysis-blueprint/notebooks/ || echo "No anndata.experimental imports found"
        fi
        
        echo "✅ Investigation completed"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF

echo "✅ Investigation TaskRun created"
echo ""
echo "🔍 Monitor the investigation:"
echo "kubectl get taskruns -n tekton-pipelines -l app=investigate-anndata"
echo ""
echo "📄 View logs:"
echo "kubectl logs -n tekton-pipelines -l app=investigate-anndata -f"