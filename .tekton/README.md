# GPU-Enabled Single-Cell Analysis Tekton Pipeline

This directory contains a complete Tekton pipeline setup for running GPU-enabled single-cell RNA analysis using RAPIDS and cuML acceleration.

## 📁 Directory Structure

```
.tekton/
├── README.md                          # This file
├── pipelines/
│   └── gpu-scrna-analysis-preprocessing-workflow.yaml  # Main pipeline definition
├── tasks/
│   ├── safe-git-clone-task.yaml                       # Git repository cloning
│   ├── large-dataset-download-task.yaml               # Dataset downloading
│   ├── jupyter-nbconvert-complete.yaml                # Notebook conversion
│   ├── jupyter-nbconvert-task.yaml                    # Alternative conversion
│   ├── pytest-execution.yaml                          # Test execution
│   ├── results-validation-cleanup-task.yaml           # Results validation
│   ├── gpu-papermill-execution-production-init-rmm-fixed.yaml  # GPU notebook execution
│   └── gpu-papermill-production-init-rmm-fixed.yaml   # Alternative GPU execution
└── runs/
    └── gpu-pipeline-manual-run.yaml                   # Example manual run configuration
```

## 🚀 Pipeline Overview

The GPU-enabled single-cell analysis pipeline consists of 9 main steps:

1. **Container Environment Setup** - Prepare the execution environment
2. **Git Clone Blueprint** - Clone the single-cell analysis repository
3. **Dataset Download** - Download scientific datasets (1.7GB cellxgene data)
4. **Papermill Execution** - Execute Jupyter notebooks with GPU acceleration
5. **Jupyter NBConvert** - Convert notebooks to HTML format
6. **Test Framework Setup** - Clone testing framework
7. **PyTest Execution** - Run comprehensive tests
8. **Results Collection** - Collect and validate all artifacts
9. **Final Summary** - Generate summary and web interface

### Key Features

- **GPU Acceleration**: Uses NVIDIA RAPIDS for accelerated single-cell analysis
- **Robust Error Handling**: Includes PCA error tolerance and retry mechanisms
- **Comprehensive Testing**: Automated pytest validation with coverage reports
- **Web Interface**: Generates accessible web interface for results
- **Production Ready**: Includes proper resource management and cleanup

## 🏃‍♂️ Quick Start

### Prerequisites

1. **Kubernetes cluster** with GPU nodes
2. **Tekton Pipelines** installed (v0.50.0+)
3. **GPU operator** or GPU support configured
4. **Persistent Volume Claims** for workspace storage

### Required PVCs

Create the following PVCs before running the pipeline:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: source-code-workspace
  namespace: tekton-pipelines
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

### 1. Apply Task Definitions

```bash
# Apply all task definitions
kubectl apply -f .tekton/tasks/
```

### 2. Run the Pipeline

#### Option A: Direct Pipeline Run
```bash
# Apply the main pipeline (it's a PipelineRun, not just a Pipeline)
kubectl apply -f .tekton/pipelines/gpu-scrna-analysis-preprocessing-workflow.yaml
```

#### Option B: Using Run Configuration Template
```bash
# First, you'll need to create a Pipeline resource from the PipelineRun spec
# Then apply the run configuration (after modifying it for your needs)
kubectl apply -f .tekton/runs/gpu-pipeline-manual-run.yaml
```

### 3. Monitor Execution

```bash
# Watch pipeline runs
kubectl get pipelineruns -n tekton-pipelines -w

# Get detailed status
kubectl describe pipelinerun <pipeline-run-name> -n tekton-pipelines

# View logs from specific tasks
tkn pipelinerun logs <pipeline-run-name> -f -n tekton-pipelines
```

## ⚙️ Configuration

### GPU Resources

The pipeline is configured for NVIDIA A100 GPUs with the following resource requirements:

- **GPU Memory**: 32Gi
- **CPU**: 8 cores
- **Storage**: 50Gi+ workspace

### Container Image

Uses `nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12` which includes:
- RAPIDS 25.04
- CUDA 12.8
- Python 3.12
- cuML, cuDF, cuGraph
- Jupyter, papermill, pytest

### Datasets

- **Primary Dataset**: 1.7GB single-cell dataset from CellxGene
- **Source**: `https://datasets.cellxgene.cziscience.com/7b91e7f8-d997-4ed3-a0cc-b88272ea7d15.h5ad`
- **Format**: H5AD (HDF5-based AnnData format)

## 📊 Expected Results

### Execution Time
- **Full Pipeline**: 30-60 minutes on A100 GPU
- **Dataset Download**: ~5-10 minutes
- **Notebook Execution**: ~20-30 minutes
- **Testing & Validation**: ~5-10 minutes

### Generated Artifacts

1. **Executed Notebook**: `output_analysis.ipynb`
2. **HTML Report**: `output_analysis.html`
3. **Test Results**: `pytest_report.html`, `coverage.xml`
4. **Logs**: Complete execution logs
5. **Web Interface**: Accessible results dashboard

### Web Access

The pipeline generates a web interface accessible at:
- **Artifacts**: `http://artifacts.10.34.2.129.nip.io/pipeline-runs/run-<ID>/`
- **Web Interface**: `http://artifacts.10.34.2.129.nip.io/pipeline-runs/run-<ID>/web/`

## 🔧 Customization

### Modifying Parameters

Key parameters you can customize in the pipeline:

```yaml
# In the PipelineRun spec
spec:
  params:
  - name: dataset-choice
    value: "original"  # or "subset" for smaller dataset
  - name: n-top-genes
    value: "5000"      # Number of top genes for analysis
  - name: data-size-limit
    value: "999999999" # Data size limit
```

### GPU Configuration

Adjust GPU settings in task specifications:

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
    memory: 32Gi
    cpu: 8
```

### Storage Requirements

Minimum storage recommendations:
- **Workspace**: 50Gi (for datasets and outputs)
- **Cache**: 20Gi (for dataset caching)
- **Artifacts**: 10Gi (for results storage)

## 🐛 Troubleshooting

### Common Issues

1. **GPU Not Available**
   - Verify GPU operator installation
   - Check node labels: `kubectl get nodes -l accelerator=nvidia-tesla-gpu`

2. **PVC Not Found**
   - Ensure PVCs are created before pipeline execution
   - Check PVC status: `kubectl get pvc -n tekton-pipelines`

3. **Dataset Download Fails**
   - Check network connectivity to external datasets
   - Verify storage space availability

4. **OOM (Out of Memory)**
   - Reduce dataset size using `data-size-limit` parameter
   - Increase PVC storage allocation

### Debug Commands

```bash
# Check pipeline run status
kubectl get pipelineruns -n tekton-pipelines

# View task run details
kubectl get taskruns -n tekton-pipelines

# Check pod logs
kubectl logs <pod-name> -n tekton-pipelines

# Access workspace for debugging
kubectl exec -it <pod-name> -n tekton-pipelines -- /bin/bash
```

## 📚 Additional Resources

- [Tekton Documentation](https://tekton.dev/docs/)
- [RAPIDS Single-Cell Documentation](https://rapids-singlecell.readthedocs.io/)
- [NVIDIA AI Blueprints](https://github.com/NVIDIA-AI-Blueprints)
- [CellxGene Data Portal](https://cellxgene.cziscience.com/)

## 🤝 Contributing

To modify or extend the pipeline:

1. **Task Development**: Add new tasks to the `tasks/` directory
2. **Pipeline Modification**: Update the main pipeline specification
3. **Testing**: Validate changes using the test framework
4. **Documentation**: Update this README with any changes

## 📝 License

This pipeline configuration is provided under the same license as the source repositories it integrates.