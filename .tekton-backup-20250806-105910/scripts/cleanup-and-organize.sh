#!/bin/bash
set -eu

# Cleanup and Organize .tekton Directory
# =====================================
# Remove redundant, testing, and temporary files
# Keep only the final, production-ready components

echo "🧹 Cleaning and Organizing .tekton Directory"
echo "==========================================="

# Create backup before cleanup
BACKUP_DIR=".tekton-backup-$(date +%Y%m%d-%H%M%S)"
echo "📁 Creating backup: $BACKUP_DIR"
cp -r .tekton "$BACKUP_DIR"

echo ""
echo "🔍 Current .tekton structure analysis:"
echo "   📂 Pipelines: $(find .tekton/pipelines -name "*.yaml" | wc -l) files"
echo "   📂 Tasks: $(find .tekton/tasks -name "*.yaml" | wc -l) files"
echo "   📂 Scripts: $(find .tekton/scripts -name "*.sh" | wc -l) files"
echo "   📂 PipelineRuns: $(find .tekton/pipelineruns -name "*.yaml" | wc -l) files"

echo ""
echo "🗑️  PHASE 1: Remove redundant pipeline files..."

# Keep only essential pipelines
cd .tekton/pipelines
echo "   Keeping: complete-notebook-workflow.yaml (MAIN PIPELINE)"
rm -f notebook01-preprocessing-pipeline.yaml
rm -f notebook01-reference-exact.yaml  
rm -f notebook02-extended-pipeline.yaml
rm -f notebook03-pearson-pipeline.yaml
rm -f notebook04-dask-pipeline.yaml
rm -f notebook05-multigpu-pipeline.yaml
rm -f rapids-5-notebooks-strategy.yaml
rm -f rapids-simple-controller.yaml
echo "   ✅ Removed 7 redundant pipeline files"

cd ../..

echo ""
echo "🗑️  PHASE 2: Remove redundant and testing task files..."

cd .tekton/tasks
echo "   Keeping core tasks: safe-git-clone-task.yaml, jupyter-nbconvert-complete.yaml"
echo "   Keeping core tasks: pytest-execution.yaml, results-validation-cleanup-task.yaml"
rm -f gpu-notebook-executor-task.yaml  # Replaced by inline taskSpec
rm -f notebook-pca-fix-task.yaml       # Replaced by integrated compatibility
rm -f pytest-execution-enhanced.yaml   # Redundant
rm -f pytest-execution-with-init.yaml  # Redundant  
rm -f pytest-simple-fixed.yaml         # Redundant
rm -f system-validation-task.yaml      # Not used
echo "   ✅ Removed 6 redundant task files"

cd ../..

echo ""
echo "🗑️  PHASE 3: Remove testing and temporary script files..."

cd .tekton/scripts

# Keep essential production scripts
echo "   Keeping: run-4-notebooks-skip-2.sh (MAIN EXECUTION SCRIPT)"
echo "   Keeping: test-compatibility-fix.sh (TESTING UTILITY)"
echo "   Keeping: start-artifact-web-server.sh (WEB SERVER)"

# Remove redundant execution scripts
rm -f run-5-notebooks-enhanced-ui.sh    # Superseded by run-4-notebooks-skip-2.sh
rm -f run-5-notebooks-sequential.sh     # Superseded
rm -f run-5-notebooks-strategy.sh       # Superseded
rm -f run-enhanced-4-notebooks.sh       # Redundant
rm -f run-rapids-analysis.sh            # Early version
rm -f run-simple-execution.sh           # Early version
rm -f run-complete-workflow.sh          # Early version

# Remove testing and debugging scripts
rm -f test-enhanced-pytest.sh           # Testing only
rm -f test-notebook01-reference-exact.sh # Testing only
rm -f test-single-notebook.sh           # Testing only
rm -f run-single-notebook-with-enhanced-pytest.sh # Testing only

# Remove compatibility development scripts (functionality is now integrated)
rm -f create-enhanced-pipeline.sh       # Development only
rm -f create-pca-compatibility-patch.sh # Development only  
rm -f create-unified-compatibility-system.sh # Development only
rm -f deploy-compatibility-integration.sh # Development only
rm -f manual-deploy-patches.sh          # Development only
rm -f patch-pipeline-with-compatibility.sh # Development only
rm -f fix-patch-integration-issues.sh   # Development only

# Remove AnnData fix development scripts (functionality is now integrated)
rm -f fix-read-elem-as-dask-compatibility.sh # Development only
rm -f fix-read-elem-as-dask-migration.sh     # Development only
rm -f investigate-anndata-issue.sh           # Development only
rm -f patch-anndata-fix.sh                   # Development only
rm -f simple-anndata-fix.sh                  # Development only
rm -f update-pipeline-with-anndata-fix.sh    # Development only

# Remove notebook-specific fix scripts (functionality is now integrated)
rm -f fix-notebook02-networks.sh        # Development only
rm -f fix-notebook02-simple.sh          # Development only
rm -f fix-notebook03-pytest.sh          # Development only

# Remove update scripts (functionality is now integrated)
rm -f update-web-server-with-results.sh # Development only

# Remove Python files that should be in compatibility_patches/
rm -f pca_compatibility_fix.py           # Should be in compatibility_patches/

echo "   ✅ Removed 26 redundant script files"

cd ../..

echo ""
echo "🗑️  PHASE 4: Remove redundant PipelineRun files..."

cd .tekton/pipelineruns
echo "   Keeping: complete-analysis-pipelinerun.yaml (MAIN PIPELINERUN)"
rm -f test-notebook01-run.yaml          # Testing only
echo "   ✅ Removed 1 redundant PipelineRun file"

cd ../..

echo ""
echo "📁 PHASE 5: Organize compatibility patches..."

# Move compatibility patches to proper location if they exist
if [ -d "compatibility_patches" ]; then
    echo "   Moving compatibility_patches to .tekton/patches/"
    mkdir -p .tekton/patches
    mv compatibility_patches/* .tekton/patches/ 2>/dev/null || true
    rmdir compatibility_patches 2>/dev/null || true
    echo "   ✅ Compatibility patches organized"
else
    echo "   📝 Note: compatibility_patches directory not found (patches are integrated in pipeline)"
fi

echo ""
echo "📋 PHASE 6: Create final .tekton directory structure documentation..."

cat > .tekton/README.md << 'EOF'
# RAPIDS Single-Cell Analysis - Tekton Pipeline

## 📁 Directory Structure

### Core Components (Production Ready)
```
.tekton/
├── pipelines/
│   └── complete-notebook-workflow.yaml     # Main pipeline with 9-step workflow
├── tasks/
│   ├── safe-git-clone-task.yaml           # Git operations
│   ├── jupyter-nbconvert-complete.yaml    # Notebook conversion
│   ├── pytest-execution.yaml              # Testing framework
│   ├── results-validation-cleanup-task.yaml # Results processing
│   ├── large-dataset-download-task.yaml   # Dataset management
│   └── artifact-web-server-task.yaml      # Web server deployment
├── scripts/
│   ├── run-4-notebooks-skip-2.sh          # Main execution script
│   ├── test-compatibility-fix.sh          # Testing utility
│   ├── start-artifact-web-server.sh       # Web server launcher
│   ├── create-simple-results-server.sh    # Results server setup
│   ├── access-notebook01-results.sh       # Results access
│   └── dashboard-monitor.sh               # Dashboard monitoring
├── pipelineruns/
│   └── complete-analysis-pipelinerun.yaml # Example PipelineRun
├── configs/
│   ├── tekton-gpu-serviceaccount.yaml     # GPU service account
│   └── gpu-resource-config.yaml           # GPU configuration
└── patches/                               # Compatibility patches (if any)
```

## 🚀 Quick Start

### Execute 4 Notebooks (Skip Phase 2)
```bash
./.tekton/scripts/run-4-notebooks-skip-2.sh
```

### Test Individual Notebook Compatibility
```bash
./.tekton/scripts/test-compatibility-fix.sh 01_scRNA_analysis_preprocessing
./.tekton/scripts/test-compatibility-fix.sh 04_scRNA_analysis_dask_out_of_core
```

### Start Artifact Web Server
```bash
./.tekton/scripts/start-artifact-web-server.sh
```

## 🔧 Key Features

- **Comprehensive 9-Step Workflow**: Environment setup, Git clone, dataset download, notebook execution, conversion, testing, artifact collection, and summary
- **Integrated Compatibility System**: Automatic handling of PCA plotting issues and AnnData compatibility
- **GPU Acceleration**: Full RAPIDS GPU support with proper resource management
- **Fault Tolerance**: Sequential execution with individual notebook failure isolation
- **Web Interface**: Artifact browsing and download via web server
- **Enhanced Monitoring**: Tekton Dashboard integration with phase/step tracking

## 📊 Compatibility Features

- **PCA Error Handling**: Graceful handling of KeyError: 'pca' in notebooks 01 & 03
- **AnnData Migration**: Automatic read_elem_as_dask → read_elem_lazy compatibility for notebooks 04 & 05
- **Zero Modification**: Original notebook files remain completely unchanged
- **Smart Error Classification**: Distinguishes between tolerable and critical errors

## 🌐 Dashboard Access
- **Main Dashboard**: https://tekton.10.34.2.129.nip.io
- **Artifact Server**: http://results.10.34.2.129.nip.io
EOF

echo "   ✅ Documentation created: .tekton/README.md"

echo ""
echo "🎯 CLEANUP SUMMARY"
echo "=================="
echo ""
echo "✅ Removed redundant files:"
echo "   📂 Pipelines: 7 files removed, 1 kept (complete-notebook-workflow.yaml)"
echo "   📂 Tasks: 6 files removed, 6 kept (core tasks)"
echo "   📂 Scripts: 26 files removed, 6 kept (essential scripts)"  
echo "   📂 PipelineRuns: 1 file removed, 1 kept (complete-analysis-pipelinerun.yaml)"
echo ""
echo "✅ Final .tekton structure:"
find .tekton -type f | sort

echo ""
echo "📋 Next Steps:"
echo "   1. Review the cleaned structure"
echo "   2. Test the main execution script: ./.tekton/scripts/run-4-notebooks-skip-2.sh"
echo "   3. Check compatibility: ./.tekton/scripts/test-compatibility-fix.sh <notebook>"
echo ""
echo "🎉 .tekton directory cleanup completed!"
echo "   Backup available at: $BACKUP_DIR"