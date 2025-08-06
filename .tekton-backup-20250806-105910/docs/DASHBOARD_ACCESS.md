# Tekton Dashboard Access Guide - RAPIDS SingleCell Analysis
===========================================================

## 🌐 Production Dashboard Access

Your Tekton dashboard is running at:
**https://tekton.10.34.2.129.nip.io**

### 👤 User Accounts

#### Administrator Access
- **Username**: `admin`
- **Password**: `admin123`
- **Permissions**: Full administrative access to all Tekton resources

#### User Access (Read-Only)
- **Username**: `user`
- **Password**: `user123`
- **Permissions**: Read-only access to:
  - Pipelines
  - Pipeline Runs
  - Tasks
  - Task Runs
  - Event Listeners

## 📊 Current Pipeline Status

### ✅ Successfully Deployed Pipelines

1. **Master Controller Pipeline**
   - Name: `master-scrna-analysis-controller`
   - Purpose: Orchestrates all notebook executions
   - Status: Deployed ✅

2. **Notebook 01 Individual Pipeline**
   - Name: `notebook01-preprocessing-pipeline`
   - Purpose: Execute scRNA preprocessing notebook
   - Status: Deployed ✅

3. **Complete Analysis Workflow**
   - Name: `complete-scrna-analysis-workflow`
   - Purpose: All 7 notebooks in sequence
   - Status: Deployed ✅

### 🏃 Current Active Runs

Check active pipeline runs at:
https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelineruns

**Latest Test Run**:
- **Name**: `test-notebook01-standalone-5gj4c`
- **Type**: Notebook 01 Individual Pipeline Test
- **Status**: Running
- **Direct Link**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelineruns/test-notebook01-standalone-5gj4c

## 🛠️ Monitoring and Troubleshooting

### Real-time Monitoring Commands

```bash
# Monitor specific pipeline run
kubectl get pipelinerun test-notebook01-standalone-5gj4c -n tekton-pipelines -w

# Follow logs in real-time
kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=test-notebook01-standalone-5gj4c -f

# Check task status
kubectl get taskruns -n tekton-pipelines -l tekton.dev/pipelineRun=test-notebook01-standalone-5gj4c
```

### Dashboard Monitoring Script

Use our custom monitoring script:
```bash
# Show overall status
./.tekton/scripts/dashboard-monitor.sh status

# Monitor specific pipeline run
./.tekton/scripts/dashboard-monitor.sh monitor <pipeline-run-name>

# Open dashboard in browser
./.tekton/scripts/dashboard-monitor.sh open

# Troubleshooting information
./.tekton/scripts/dashboard-monitor.sh troubleshoot
```

## 🎯 Pipeline Architecture

### Current Implementation Status

```
🎯 Master Controller (Ready)
├── 📋 Environment Setup (Ready)
├── 🔗 Repository Clone (Ready)
├── 📊 Notebook 01 Pipeline (✅ Implemented & Testing)
├── 📊 Notebook 02 Pipeline (⏳ Pending)
├── 📊 Notebook 03 Pipeline (⏳ Pending)
├── 📊 Notebook 06 Pipeline (⏳ Pending)
├── 📊 Notebook 04 Pipeline (⏳ Pending)
├── 📊 Notebook 07 Pipeline (⏳ Pending)
├── 📊 Notebook 05 Pipeline (⏳ Pending)
└── 📋 Final Report Generation (Ready)
```

### Testing Strategy

1. **Phase 1** (Current): Test Notebook 01 individual pipeline
2. **Phase 2**: Test master controller with Notebook 01
3. **Phase 3**: Implement remaining notebook pipelines
4. **Phase 4**: Full end-to-end testing

## 📋 Quick Navigation Links

### Dashboard Sections
- **Pipeline Runs**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelineruns
- **Pipelines**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelines
- **Tasks**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/tasks
- **Task Runs**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/taskruns

### RAPIDS Specific Pipelines
- **Master Controller**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelines/master-scrna-analysis-controller
- **Notebook 01**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelines/notebook01-preprocessing-pipeline
- **Complete Workflow**: https://tekton.10.34.2.129.nip.io/#/namespaces/tekton-pipelines/pipelines/complete-scrna-analysis-workflow

## 💡 Best Practices

### For Monitoring
1. Always use the dashboard for visual monitoring
2. Use command line tools for detailed debugging
3. Check both pipeline and task levels for issues
4. Monitor GPU resource utilization

### For Development
1. Test individual notebook pipelines first
2. Use the master controller for orchestration
3. Always check storage class compatibility
4. Ensure proper service account permissions

## 🔧 Common Issues and Solutions

### Storage Issues
- **Problem**: PVC stuck in Pending state
- **Solution**: Use `immediate-local` storage class instead of `local-path`

### Permission Issues
- **Problem**: Tasks use `default` service account
- **Solution**: Ensure `tekton-gpu-executor` service account is properly configured

### GPU Issues
- **Problem**: GPU not available to containers
- **Solution**: Verify GPU resource requests and node selector

---

## 📞 Support

For troubleshooting, check:
- `.tekton/docs/TROUBLESHOOTING.md`
- Pipeline logs in the dashboard
- Kubernetes events for the namespace

**Dashboard**: https://tekton.10.34.2.129.nip.io (admin/admin123 or user/user123)