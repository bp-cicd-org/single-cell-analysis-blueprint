# 🚀 RAPIDS SingleCell Analysis - Tekton Cloud-Native Execution System

## 📋 Overview

This is a cloud-native execution system for running all RAPIDS SingleCell Analysis notebooks using **Tekton Pipelines**. The system provides:

- **Cloud-Native Architecture**: Built on Kubernetes and Tekton Pipelines
- **GPU Resource Management**: Intelligent GPU allocation and monitoring  
- **Sequential Execution**: Optimal notebook execution order avoiding memory conflicts
- **Comprehensive Monitoring**: Real-time tracking and detailed reporting
- **Scalable Design**: Supports single GPU to multi-GPU setups

## 🏗️ Architecture Overview

```
📁 Tekton Components Structure
.tekton/
├── docs/
│   ├── README.md                                # Quick start guide
│   └── EXECUTION_GUIDE.md                       # This comprehensive guide
├── configs/
│   └── gpu-resource-config.yaml                 # GPU resource configurations
├── scripts/
│   └── run-complete-analysis.sh                 # Main launcher script
├── tasks/
│   ├── gpu-notebook-executor-task.yaml         # Universal notebook executor
│   ├── system-validation-task.yaml             # System requirements validation
│   ├── safe-git-clone-task.yaml               # Secure repository cloning (existing)
│   ├── jupyter-nbconvert-complete.yaml         # Notebook HTML conversion (existing)
│   └── large-dataset-download-task.yaml        # Large dataset management (existing)
├── pipelines/
│   ├── complete-scrna-analysis-workflow.yaml   # Master pipeline for all notebooks
│   └── gpu-scrna-analysis-preprocessing-workflow.yaml # Original single notebook (existing)
└── pipelineruns/
    └── complete-analysis-pipelinerun.yaml      # Pipeline execution configuration
```

## 🎯 Execution Strategy

### **Sequential Workflow Design**

```
🔧 Stage 0: Environment Setup
├── Repository Clone
├── Environment Validation  
└── Dependency Installation

📊 Stage 1: Basic Analysis (24GB GPU)
├── 01_scRNA_analysis_preprocessing.ipynb
├── 02_scRNA_analysis_extended.ipynb (depends on 01)
├── 03_scRNA_analysis_with_pearson_residuals.ipynb
└── 06_scRNA_analysis_90k_brain_example.ipynb

🚀 Stage 2: Large Scale Analysis (48GB+ GPU)
├── 04_scRNA_analysis_dask_out_of_core.ipynb (48GB)
└── 07_scRNA_analysis_1.3M_brain_example.ipynb (80GB)

💪 Stage 3: Multi-GPU Analysis (Multiple 80GB GPUs)
└── 05_scRNA_analysis_multi_GPU.ipynb

📈 Stage 4: Results Compilation
└── Generate comprehensive HTML report
```

## 🚀 Quick Start

### **Prerequisites**

1. **Kubernetes Cluster** with GPU nodes
2. **Tekton Pipelines** installed
3. **kubectl** configured and connected
4. **GPU Hardware**: 3x A100 80GB recommended

### **Installation**

```bash
# 1. Install Tekton Pipelines (if not already installed)
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# 2. Navigate to project directory
cd /path/to/single-cell-analysis-blueprint

# 3. Install our tasks and pipelines
.tekton/scripts/run-complete-analysis.sh install

# 4. Validate system requirements
.tekton/scripts/run-complete-analysis.sh validate

# 5. Run complete analysis workflow
.tekton/scripts/run-complete-analysis.sh run
```

### **Alternative Manual Installation**

```bash
# Install tasks
kubectl apply -f .tekton/tasks/ -n tekton-pipelines

# Install pipelines
kubectl apply -f .tekton/pipelines/ -n tekton-pipelines

# Install configurations
kubectl apply -f .tekton/configs/ -n tekton-pipelines

# Run pipeline
kubectl apply -f .tekton/pipelineruns/complete-analysis-pipelinerun.yaml
```

## 📊 Monitoring and Management

### **Real-Time Monitoring**

```bash
# Monitor latest pipeline execution
.tekton/scripts/run-complete-analysis.sh monitor

# View logs in real-time
kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=<run-name> -f

# Check current status
.tekton/scripts/run-complete-analysis.sh status
```

### **Tekton Dashboard** (Optional)

```bash
# Install Tekton Dashboard
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Access dashboard
kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097

# Open in browser
open http://localhost:9097
```

## 🛠️ System Components

### **1. Universal Notebook Executor Task**
- **File**: `.tekton/tasks/gpu-notebook-executor-task.yaml`
- **Purpose**: Parameter-driven execution of any notebook
- **Features**:
  - GPU resource verification
  - Dependency checking
  - Environment setup
  - Results validation
  - Comprehensive logging

### **2. Complete Analysis Pipeline**
- **File**: `.tekton/pipelines/complete-scrna-analysis-workflow.yaml`
- **Purpose**: Orchestrates execution of all 7 notebooks
- **Features**:
  - Sequential execution order
  - Hardware requirement validation
  - Inter-notebook dependency management
  - Final report generation

### **3. System Validation Task**
- **File**: `.tekton/tasks/system-validation-task.yaml`
- **Purpose**: Validates system requirements before execution
- **Checks**:
  - GPU availability and memory
  - CUDA drivers and toolkit
  - Python environment
  - Storage requirements

### **4. PipelineRun Configuration**
- **File**: `.tekton/pipelineruns/complete-analysis-pipelinerun.yaml`
- **Purpose**: Configures pipeline execution parameters
- **Features**:
  - Resource quotas for each notebook
  - Storage allocation
  - Timeout configuration
  - Node selection

## ⚙️ Configuration Options

### **Resource Requirements**

| Notebook | Min GPU Memory | Recommended | CPU | RAM |
|----------|----------------|-------------|-----|-----|
| 01_preprocessing | 24GB | A100 80GB | 8 cores | 32GB |
| 02_extended | 24GB | A100 80GB | 8 cores | 32GB |
| 03_pearson | 24GB | A100 80GB | 8 cores | 32GB |
| 06_brain90k | 24GB | A100 80GB | 8 cores | 32GB |
| 04_dask | 48GB | A100 80GB | 16 cores | 64GB |
| 07_brain1m | 80GB | A100 80GB | 16 cores | 64GB |
| 05_multigpu | 160GB+ | 3x A100 80GB | 32 cores | 128GB |

### **Customization Parameters**

Edit `.tekton/pipelineruns/complete-analysis-pipelinerun.yaml`:

```yaml
params:
- name: skip-optional-notebooks
  value: "true"  # Skip notebooks if hardware insufficient
- name: continue-on-failure
  value: "false" # Stop pipeline on first failure
- name: cleanup-between-notebooks
  value: "true"  # Clear GPU memory between executions
```

### **Storage Configuration**

```yaml
workspaces:
- name: shared-storage
  volumeClaimTemplate:
    spec:
      resources:
        requests:
          storage: 500Gi  # Adjust based on needs
      storageClassName: fast-ssd
```

## 🔍 Troubleshooting

### **Common Issues**

1. **GPU Not Available**
   ```bash
   # Check GPU nodes
   kubectl get nodes -l accelerator=nvidia-tesla-a100
   
   # Verify GPU operator
   kubectl get pods -n gpu-operator-resources
   ```

2. **Insufficient Resources**
   ```bash
   # Check resource quotas
   kubectl describe resourcequota -n tekton-pipelines
   
   # View node resources
   kubectl top nodes
   ```

3. **Pipeline Failures**
   ```bash
   # Get detailed failure information
   kubectl describe pipelinerun <run-name> -n tekton-pipelines
   
   # View specific task logs
   kubectl logs <pod-name> -n tekton-pipelines -c step-execute-notebook
   ```

4. **Storage Issues**
   ```bash
   # Check persistent volume claims
   kubectl get pvc -n tekton-pipelines
   
   # Check storage class
   kubectl get storageclass
   ```

### **Performance Optimization**

1. **Use Local SSD Storage**
   ```yaml
   storageClassName: local-ssd
   ```

2. **Node Affinity for GPU Nodes**
   ```yaml
   nodeSelector:
     accelerator: nvidia-tesla-a100
   ```

3. **Resource Limits Tuning**
   ```yaml
   resources:
     limits:
       memory: "128Gi"
       nvidia.com/gpu: "1"
   ```

## 📈 Expected Results

### **Execution Timeline**
- **Total Duration**: 4-8 hours (depending on hardware)
- **Basic Analysis**: 2-3 hours (notebooks 01, 02, 03, 06)
- **Large Scale**: 2-4 hours (notebooks 04, 07)
- **Multi-GPU**: 1-2 hours (notebook 05)

### **Generated Outputs**
```
outputs/
├── 01_scRNA_analysis_preprocessing.executed.ipynb
├── 01_scRNA_analysis_preprocessing.html
├── 02_scRNA_analysis_extended.executed.ipynb
├── 02_scRNA_analysis_extended.html
├── ... (all notebooks)
└── reports/
    └── complete_analysis_report_YYYYMMDD_HHMMSS.html
```

### **Performance Metrics**
- GPU memory utilization tracking
- Execution time per notebook
- Resource usage statistics
- Success/failure rates

## 🔧 Advanced Usage

### **Custom Notebook Execution**

Execute individual notebooks:

```yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: custom-notebook-run
spec:
  taskRef:
    name: gpu-notebook-executor-task
  params:
  - name: notebook-name
    value: "01_scRNA_analysis_preprocessing"
  - name: min-gpu-memory-gb
    value: "24"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: my-pvc
```

### **Integration with CI/CD**

```yaml
# .github/workflows/tekton-pipeline.yml
name: Run Analysis Pipeline
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly execution
  
jobs:
  trigger-pipeline:
    runs-on: ubuntu-latest
    steps:
    - name: Trigger Tekton Pipeline
      run: |
        kubectl apply -f .tekton/pipelineruns/complete-analysis-pipelinerun.yaml
```

### **Multi-Cluster Deployment**

For large-scale deployments across multiple clusters:

```bash
# Deploy to production cluster
kubectl config use-context production-cluster
.tekton/scripts/run-complete-analysis.sh install

# Deploy to staging cluster  
kubectl config use-context staging-cluster
.tekton/scripts/run-complete-analysis.sh install
```

## 🏷️ Best Practices

### **Resource Management**
- Use resource quotas to prevent resource exhaustion
- Implement node affinity for GPU scheduling
- Monitor cluster resource usage

### **Data Management**
- Use persistent volumes for data persistence
- Implement data cleanup policies
- Consider data caching strategies

### **Security**
- Use service accounts with minimal permissions
- Implement pod security policies
- Secure sensitive data with secrets

### **Monitoring**
- Implement comprehensive logging
- Use metrics collection (Prometheus/Grafana)
- Set up alerting for failures

## 📞 Support and Troubleshooting

### **Get Help**
- Check pipeline logs: `kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=<run-name>`
- View system validation: `.tekton/scripts/run-complete-analysis.sh validate`
- Monitor execution: `.tekton/scripts/run-complete-analysis.sh monitor`

### **Cleanup**
```bash
# Clean old pipeline runs
.tekton/scripts/run-complete-analysis.sh cleanup

# Remove all resources
kubectl delete -f .tekton/ -n tekton-pipelines
```

---

## 🎉 Summary

This Tekton-based execution system provides a production-ready, cloud-native solution for running the complete RAPIDS SingleCell Analysis workflow. Key benefits:

- ✅ **Scalable**: From single GPU to multi-GPU setups
- ✅ **Reliable**: Comprehensive error handling and recovery
- ✅ **Observable**: Detailed monitoring and reporting
- ✅ **Maintainable**: Modular, configurable architecture
- ✅ **Cloud-Native**: Built for Kubernetes environments

The system automatically handles resource management, dependency resolution, and provides comprehensive execution reports, making it ideal for both research and production environments.