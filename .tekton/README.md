# RAPIDS Single-Cell Analysis - Tekton Pipeline

## 📁 Directory Structure

### Core Components (Production Ready)
```
.tekton/
├── pipelines/
│   ├── complete-notebook-workflow.yaml     # Main pipeline with 9-step workflow
│   └── current-working-pipeline.yaml       # Current working version with latest patches
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
└── patches/                               # Compatibility patches (6 files)
    ├── anndata_compat.py                   # AnnData read_elem_as_dask compatibility
    ├── apply_pca_patch.py                  # PCA patch application utility
    ├── pca_compat.py                       # PCA error handling core module
    ├── pca_safe_execution.py               # PCA safe execution wrapper
    ├── startup_compat.py                   # Startup compatibility script
    └── unified_compat.py                   # Unified compatibility system
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
