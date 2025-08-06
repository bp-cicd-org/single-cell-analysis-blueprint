# Troubleshooting Guide - RAPIDS SingleCell Analysis Pipeline
===============================================================

This document contains common issues and solutions encountered during the execution of the RAPIDS SingleCell Analysis pipeline in Tekton.

## 🔧 Quick Diagnostic Commands

```bash
# Check cluster GPU availability
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'

# Check pipeline status
kubectl get pipelineruns -n tekton-pipelines

# View specific pipeline run details
kubectl describe pipelinerun <run-name> -n tekton-pipelines

# Follow logs in real-time
kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=<run-name> -f

# Check task execution status
kubectl get taskruns -n tekton-pipelines

# Check GPU resource usage
kubectl top nodes
kubectl describe nodes | grep -A 5 nvidia.com/gpu
```

## 🚨 Common Issues and Solutions

### 1. GPU Resources Issues

#### **Problem**: `Insufficient GPU memory`
```
ERROR: Insufficient GPU memory
Available: 16GB
Required: 24GB
```

**Solutions**:
- Check current GPU usage: `nvidia-smi`
- Wait for other workloads to complete
- Reduce batch size in notebook parameters (if supported)
- Use a different GPU node with more memory

#### **Problem**: `GPU not available`
```
ERROR: NVIDIA GPU not available or drivers not installed
```

**Solutions**:
- Verify GPU nodes exist: `kubectl get nodes -l accelerator=nvidia-tesla-v100`
- Check NVIDIA device plugin: `kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds`
- Ensure proper node labels and taints are configured

#### **Problem**: `Pod stuck in Pending state with GPU request`
```
Warning  FailedScheduling  pod/notebook-01-xxx  0/3 nodes are available: 3 Insufficient nvidia.com/gpu.
```

**Solutions**:
- Check available GPU resources: `kubectl describe nodes | grep nvidia.com/gpu`
- Reduce GPU request or use nodeSelector to target specific nodes
- Check if GPU quota is exceeded: `kubectl describe quota -n tekton-pipelines`

### 2. Service Account and RBAC Issues

#### **Problem**: `ServiceAccount "tekton-gpu-executor" not found`
```
error validating data: ValidationError(TaskRun.spec): unknown field "taskServiceAccountName"
```

**Solutions**:
```bash
# Deploy service account configuration
kubectl apply -f .tekton/configs/tekton-gpu-serviceaccount.yaml

# Verify service account exists
kubectl get serviceaccount tekton-gpu-executor -n tekton-pipelines

# Check RBAC permissions
kubectl auth can-i create pods --as=system:serviceaccount:tekton-pipelines:tekton-gpu-executor
```

#### **Problem**: `Permission denied` errors during execution
```
Error: pods is forbidden: User "system:serviceaccount:tekton-pipelines:tekton-gpu-executor" cannot create resource "pods"
```

**Solutions**:
- Check ClusterRoleBinding: `kubectl get clusterrolebinding tekton-gpu-executor-binding`
- Verify role permissions: `kubectl describe clusterrole tekton-gpu-executor-role`
- Re-apply RBAC configuration: `kubectl apply -f .tekton/configs/tekton-gpu-serviceaccount.yaml`

### 3. Storage and Workspace Issues

#### **Problem**: `PVC provisioning failed`
```
Warning  ProvisioningFailed  persistentvolumeclaim/pvc-xxx  Failed to provision volume
```

**Solutions**:
- Check available storage classes: `kubectl get storageclass`
- Update storageClassName in pipelinerun configuration
- Verify cluster has sufficient storage capacity
- Check PVC events: `kubectl describe pvc <pvc-name> -n tekton-pipelines`

#### **Problem**: `No space left on device`
```
ERROR: [Errno 28] No space left on device
```

**Solutions**:
- Increase PVC size in pipeline configuration
- Clean up old pipeline runs: `kubectl delete pipelinerun --all -n tekton-pipelines`
- Check node disk usage: `kubectl top nodes`

### 4. Notebook Execution Issues

#### **Problem**: `Papermill execution timeout`
```
TimeoutError: Notebook execution exceeded 7200 seconds
```

**Solutions**:
- Increase execution timeout in task parameters
- Check if dataset download is taking longer than expected
- Monitor GPU utilization during execution
- Consider running on more powerful hardware

#### **Problem**: `RAPIDS library import errors`
```
ModuleNotFoundError: No module named 'rapids_singlecell'
```

**Solutions**:
- Verify RAPIDS container image version: `nvcr.io/nvidia/rapidsai/notebooks:25.04-cuda12.8-py3.12`
- Check pip installation logs for errors
- Manually install missing dependencies in pipeline setup

#### **Problem**: `CUDA out of memory`
```
RuntimeError: CUDA out of memory. Tried to allocate 2.00 GiB
```

**Solutions**:
- Restart pipeline with memory cleanup between tasks
- Reduce dataset size for testing
- Use notebooks with lower memory requirements first
- Check for memory leaks in previous tasks

### 5. Data Download Issues

#### **Problem**: `Git clone authentication failure`
```
fatal: Authentication failed for 'https://github.com/...'
```

**Solutions**:
- Repository is public, should not require authentication
- Check network connectivity: `kubectl run test-pod --image=alpine/git --rm -it -- git clone <repo-url>`
- Verify firewall/proxy settings in cluster

#### **Problem**: `Dataset download failures`
```
URLError: <urlopen error [Errno -2] Name or service not known>
```

**Solutions**:
- Check cluster internet connectivity
- Verify DNS resolution in pods
- Use alternative dataset sources if available
- Pre-download datasets to persistent storage

### 6. Pipeline Orchestration Issues

#### **Problem**: `Task dependencies not satisfied`
```
ERROR: Dependency not satisfied: 01_scRNA_analysis_preprocessing
Expected file: outputs/01_scRNA_analysis_preprocessing.executed.ipynb
```

**Solutions**:
- Check if previous task completed successfully
- Verify output file paths are correct
- Review task execution order in pipeline
- Check workspace mounting between tasks

#### **Problem**: `Pipeline stuck in Running state`
```
NAME                           SUCCEEDED   REASON    STARTTIME   COMPLETIONTIME
complete-analysis-20240115     Unknown     Running   5m          
```

**Solutions**:
- Check individual task statuses: `kubectl get taskruns -n tekton-pipelines`
- Look for stuck or failed tasks: `kubectl get pods -n tekton-pipelines`
- Review resource constraints and node availability
- Cancel and restart if necessary: `kubectl delete pipelinerun <name> -n tekton-pipelines`

## 🛠️ Advanced Debugging

### Enable Debug Mode

Add debug flags to pipeline runs:
```yaml
spec:
  params:
  - name: debug-mode
    value: "true"
  - name: verbose-logging
    value: "true"
```

### Manual Task Execution

Test individual notebooks manually:
```bash
# Create a test TaskRun
kubectl create -f - <<EOF
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: debug-notebook01-
  namespace: tekton-pipelines
spec:
  taskRef:
    name: gpu-notebook-executor-task
  params:
  - name: notebook-name
    value: "01_scRNA_analysis_preprocessing"
  - name: execution-timeout
    value: "3600"
  workspaces:
  - name: shared-storage
    volumeClaimTemplate:
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 10Gi
EOF
```

### Container Access for Debugging

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n tekton-pipelines -l tekton.dev/task=gpu-notebook-executor-task --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

# Execute into container
kubectl exec -it $POD_NAME -n tekton-pipelines -c step-execute-notebook -- bash

# Check GPU access
nvidia-smi

# Check Python environment
python -c "import rapids_singlecell; print('RAPIDS OK')"

# Check file system
ls -la /workspace/shared/
```

## 📊 Monitoring and Performance

### Resource Monitoring

```bash
# Watch resource usage during execution
watch kubectl top pods -n tekton-pipelines

# Monitor GPU utilization
kubectl exec -it <pod-name> -n tekton-pipelines -- nvidia-smi -l 5

# Check storage usage
kubectl exec -it <pod-name> -n tekton-pipelines -- df -h
```

### Log Analysis

```bash
# Extract execution time from logs
kubectl logs <pod-name> -n tekton-pipelines | grep "Execution time"

# Find error patterns
kubectl logs <pod-name> -n tekton-pipelines | grep -i "error\|exception\|failed"

# Export full logs for analysis
kubectl logs <pod-name> -n tekton-pipelines > debug-logs.txt
```

## 🔄 Recovery Procedures

### Pipeline Recovery

1. **Identify failed task**:
   ```bash
   kubectl get taskruns -n tekton-pipelines --field-selector=status.conditions[0].status=False
   ```

2. **Clean up failed resources**:
   ```bash
   kubectl delete pipelinerun <failed-run-name> -n tekton-pipelines
   kubectl delete pvc -l tekton.dev/pipelineRun=<failed-run-name> -n tekton-pipelines
   ```

3. **Restart from specific notebook**:
   - Modify pipeline to skip completed notebooks
   - Use dependency outputs from previous successful run

### Data Recovery

1. **Backup workspace data**:
   ```bash
   kubectl cp <pod-name>:/workspace/shared/outputs ./backup-outputs -n tekton-pipelines
   ```

2. **Restore to new pipeline run**:
   - Mount backup data as init container
   - Copy outputs to new workspace

## 📞 Getting Help

### Collecting Debug Information

Before reporting issues, collect:

```bash
# System information
kubectl version
kubectl get nodes -o wide

# GPU information
kubectl describe nodes | grep -A 10 nvidia.com/gpu

# Pipeline state
kubectl get pipelineruns,taskruns -n tekton-pipelines -o wide

# Recent events
kubectl get events -n tekton-pipelines --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -n tekton-pipelines
```

### Log Package Creation

```bash
# Create comprehensive log package
mkdir debug-package-$(date +%Y%m%d-%H%M%S)
cd debug-package-*/

# Export all relevant information
kubectl get pipelineruns -n tekton-pipelines -o yaml > pipelineruns.yaml
kubectl get taskruns -n tekton-pipelines -o yaml > taskruns.yaml
kubectl get pods -n tekton-pipelines -o yaml > pods.yaml
kubectl get events -n tekton-pipelines -o yaml > events.yaml
kubectl logs -n tekton-pipelines -l app.kubernetes.io/name=rapids-singlecell-analysis > pipeline-logs.txt

# Package for sharing
cd ..
tar czf debug-package.tar.gz debug-package-*/
```

---

## 📚 Additional Resources

- [Tekton Documentation](https://tekton.dev/docs/)
- [RAPIDS SingleCell Documentation](https://rapids-singlecell.readthedocs.io/)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [Kubernetes GPU Scheduling](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)

---

**Note**: Keep this document updated as new issues are discovered and resolved during pipeline execution.