# 🚀 RAPIDS SingleCell Analysis - Tekton Cloud-Native Execution System

## 📁 Directory Structure

```
.tekton/
├── docs/                                    # Documentation
│   ├── README.md                            # This file
│   └── EXECUTION_GUIDE.md                   # Complete execution guide
├── configs/                                 # Configuration files
│   └── gpu-resource-config.yaml            # GPU resource configurations
├── scripts/                                 # Utility scripts
│   └── run-complete-analysis.sh             # Main launcher script
├── tasks/                                   # Tekton Task definitions
│   ├── gpu-notebook-executor-task.yaml     # Universal notebook executor
│   ├── system-validation-task.yaml         # System validation
│   ├── safe-git-clone-task.yaml           # Repository cloning (existing)
│   ├── jupyter-nbconvert-complete.yaml     # HTML conversion (existing)
│   └── large-dataset-download-task.yaml    # Dataset management (existing)
├── pipelines/                              # Tekton Pipeline definitions
│   ├── complete-scrna-analysis-workflow.yaml     # Complete workflow
│   └── gpu-scrna-analysis-preprocessing-workflow.yaml  # Single notebook (existing)
└── pipelineruns/                           # Pipeline execution configs
    └── complete-analysis-pipelinerun.yaml  # Complete workflow execution
```

## 🚀 Quick Start

```bash
# Navigate to the project root
cd /path/to/single-cell-analysis-blueprint

# Run the complete workflow
.tekton/scripts/run-complete-analysis.sh

# Or step by step:
.tekton/scripts/run-complete-analysis.sh install   # Install tasks and pipelines
.tekton/scripts/run-complete-analysis.sh validate # Validate system
.tekton/scripts/run-complete-analysis.sh run      # Execute workflow
```

## 📚 Documentation

- **[Complete Execution Guide](.tekton/docs/EXECUTION_GUIDE.md)** - Comprehensive documentation
- **[GPU Resource Configuration](.tekton/configs/gpu-resource-config.yaml)** - Hardware configurations
- **[Main Script](.tekton/scripts/run-complete-analysis.sh)** - Launcher script

## 🎯 Workflow Overview

This system executes all 7 RAPIDS SingleCell Analysis notebooks in optimal order:

1. **01_scRNA_analysis_preprocessing.ipynb** (24GB GPU)
2. **02_scRNA_analysis_extended.ipynb** (24GB GPU, depends on 01)
3. **03_scRNA_analysis_with_pearson_residuals.ipynb** (24GB GPU)
4. **06_scRNA_analysis_90k_brain_example.ipynb** (24GB GPU)
5. **04_scRNA_analysis_dask_out_of_core.ipynb** (48GB GPU)
6. **07_scRNA_analysis_1.3M_brain_example.ipynb** (80GB GPU)
7. **05_scRNA_analysis_multi_GPU.ipynb** (Multiple 80GB GPUs)

## 🏗️ Features

- **Cloud-Native**: Built on Kubernetes and Tekton Pipelines
- **GPU Optimized**: Intelligent GPU resource management
- **Sequential Execution**: Avoids memory conflicts
- **Comprehensive Monitoring**: Real-time tracking and reporting
- **Scalable**: Single GPU to multi-GPU support

## 📋 Prerequisites

- Kubernetes cluster with GPU nodes
- Tekton Pipelines installed
- kubectl configured
- 3x A100 80GB GPUs recommended