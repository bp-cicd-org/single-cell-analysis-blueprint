#!/bin/bash
set -eu

# Patch Current Pipeline with AnnData Fix
# ========================================

echo "🔧 Patching Current Pipeline with AnnData Fix"
echo "=============================================="

# Create a patch script that will be applied to existing working pipeline
cat << 'PATCH_EOF' > /tmp/anndata-patch.sh
#!/bin/bash

# This patch adds anndata fixes for notebooks 04 and 05
echo "📦 Applying AnnData patch for current notebook: $NOTEBOOK_NAME"

if [ "$NOTEBOOK_NAME" = "04_scRNA_analysis_dask_out_of_core" ]; then
    echo "🔧 Installing enhanced anndata for Notebook 04 (Dask support)..."
    python -m pip install --user --quiet "anndata>=0.10.0" dask "dask[array]" h5py
    
    echo "🔍 Verifying read_elem_as_dask availability..."
    python -c "from anndata.experimental import read_elem_as_dask; print('✅ read_elem_as_dask available')" || {
        echo "⚠️ read_elem_as_dask not available, installing latest anndata..."
        python -m pip install --user --upgrade anndata
    }
    
elif [ "$NOTEBOOK_NAME" = "05_scRNA_analysis_multi_GPU" ]; then
    echo "🔧 Installing enhanced anndata for Notebook 05 (Multi-GPU + Dask)..."
    python -m pip install --user --quiet "anndata>=0.10.0" dask "dask[array]" h5py dask-cuda
    
    echo "🔍 Verifying read_elem_as_dask availability..."
    python -c "from anndata.experimental import read_elem_as_dask; print('✅ read_elem_as_dask available')" || {
        echo "⚠️ read_elem_as_dask not available, installing latest anndata..."
        python -m pip install --user --upgrade anndata
    }
fi

# Verification for both notebooks
if [ "$NOTEBOOK_NAME" = "04_scRNA_analysis_dask_out_of_core" ] || [ "$NOTEBOOK_NAME" = "05_scRNA_analysis_multi_GPU" ]; then
    echo "🔍 Final verification for $NOTEBOOK_NAME..."
    python -c "import dask; print('✅ dask version:', dask.__version__)"
    python -c "import anndata; print('✅ anndata version:', anndata.__version__)"
    python -c "from anndata.experimental import read_elem_as_dask; print('✅ read_elem_as_dask OK')" || {
        echo "❌ CRITICAL: read_elem_as_dask still not available"
        exit 1
    }
fi
PATCH_EOF

chmod +x /tmp/anndata-patch.sh

echo "✅ AnnData patch script created at /tmp/anndata-patch.sh"

# Now create a simple task that uses this patch
cat << 'EOF' | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: anndata-fix-task
  namespace: tekton-pipelines
  labels:
    app.kubernetes.io/name: anndata-fix-task
    app.kubernetes.io/component: tekton-task
    app.kubernetes.io/version: "1.0.0"
spec:
  description: |
    Fix anndata version issues for notebooks 04 and 05.
    Installs compatible anndata version with read_elem_as_dask support.
    
  params:
  - name: notebook-name
    type: string
    description: Name of the notebook being processed
    
  workspaces:
  - name: shared-storage
    description: Workspace for environment setup
    
  steps:
  - name: apply-anndata-fix
    image: nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12
    securityContext:
      runAsUser: 0
    env:
    - name: NOTEBOOK_NAME
      value: $(params.notebook-name)
    script: |
      #!/bin/bash
      set -eu
      
      echo "🔧 AnnData Fix Task"
      echo "=================="
      
      cd "$(workspaces.shared-storage.path)"
      
      # Apply the specific fix based on notebook
      if [ "$NOTEBOOK_NAME" = "04_scRNA_analysis_dask_out_of_core" ]; then
          echo "🔧 Installing enhanced anndata for Notebook 04 (Dask support)..."
          python -m pip install --user --quiet "anndata>=0.10.0" dask "dask[array]" h5py
          
          echo "🔍 Verifying read_elem_as_dask availability..."
          python -c "from anndata.experimental import read_elem_as_dask; print('✅ read_elem_as_dask available')" || {
              echo "⚠️ read_elem_as_dask not available, installing latest anndata..."
              python -m pip install --user --upgrade anndata
          }
          
      elif [ "$NOTEBOOK_NAME" = "05_scRNA_analysis_multi_GPU" ]; then
          echo "🔧 Installing enhanced anndata for Notebook 05 (Multi-GPU + Dask)..."
          python -m pip install --user --quiet "anndata>=0.10.0" dask "dask[array]" h5py dask-cuda
          
          echo "🔍 Verifying read_elem_as_dask availability..."
          python -c "from anndata.experimental import read_elem_as_dask; print('✅ read_elem_as_dask available')" || {
              echo "⚠️ read_elem_as_dask not available, installing latest anndata..."
              python -m pip install --user --upgrade anndata
          }
      else
          echo "ℹ️ No anndata fix needed for $NOTEBOOK_NAME"
          exit 0
      fi
      
      # Final verification
      echo "🔍 Final verification for $NOTEBOOK_NAME..."
      python -c "import dask; print('✅ dask version:', dask.__version__)"
      python -c "import anndata; print('✅ anndata version:', anndata.__version__)"
      python -c "from anndata.experimental import read_elem_as_dask; print('✅ read_elem_as_dask OK')" || {
          echo "❌ CRITICAL: read_elem_as_dask still not available"
          exit 1
      }
      
      echo "✅ AnnData fix completed successfully for $NOTEBOOK_NAME"
EOF

echo "✅ AnnData fix task deployed"

# Test the fix task
echo ""
echo "🧪 Testing AnnData fix with Notebook 04..."

cat << EOF | kubectl create -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: test-anndata-fix-
  namespace: tekton-pipelines
  labels:
    app: test-anndata-fix
spec:
  serviceAccountName: tekton-gpu-executor
  taskRef:
    name: anndata-fix-task
  params:
  - name: notebook-name
    value: "04_scRNA_analysis_dask_out_of_core"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: source-code-workspace
EOF

echo "✅ AnnData fix test TaskRun created"
echo ""
echo "🔍 Monitor the test:"
echo "kubectl get taskruns -n tekton-pipelines -l app=test-anndata-fix"
echo ""
echo "📄 View logs:"
echo "kubectl logs -n tekton-pipelines -l app=test-anndata-fix -f"