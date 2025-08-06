#!/bin/bash
set -eu

# RAPIDS SingleCell Analysis - Artifact Web Server Launcher
# ========================================================
# This script deploys and starts the artifact web server to serve
# all notebook execution results through a simple web interface

echo "🌐 RAPIDS Artifact Web Server Launcher"
echo "======================================"

# Configuration
NAMESPACE="tekton-pipelines"
TASK_NAME="artifact-web-server-task"
SERVICE_NAME="rapids-artifacts-web"
WEB_PORT="8080"
INGRESS_HOST="artifacts.tekton.10.34.2.129.nip.io"

# Get current batch ID from the latest pipeline run
LATEST_BATCH=$(kubectl get pipelineruns -n $NAMESPACE -l dashboard.tekton.dev/workflow=9-step-complete --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.labels.execution\.rapids\.ai/batch-id}' 2>/dev/null || echo "rapids-$(date +%Y%m%d-%H%M%S)")

echo "📋 Configuration:"
echo "   Namespace: $NAMESPACE"
echo "   Task: $TASK_NAME"
echo "   Current Batch: $LATEST_BATCH"
echo "   Web Port: $WEB_PORT"
echo "   Access URL: http://$INGRESS_HOST"

# Apply the artifact web server task
echo ""
echo "🚀 Step 1: Deploying Artifact Web Server Task"
echo "============================================="

if kubectl apply -f .tekton/tasks/artifact-web-server-task.yaml -n $NAMESPACE; then
    echo "✅ Artifact web server task deployed successfully"
else
    echo "❌ Failed to deploy artifact web server task"
    exit 1
fi

# Create TaskRun to start the web server
echo ""
echo "🏃 Step 2: Starting Web Server TaskRun"
echo "====================================="

TASKRUN_NAME="rapids-artifacts-web-$(date +%Y%m%d-%H%M%S)"

cat << EOF | kubectl apply -f -
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: $TASKRUN_NAME
  namespace: $NAMESPACE
  labels:
    app: rapids-artifacts-web
    tekton.dev/task: artifact-web-server-task
spec:
  taskRef:
    name: artifact-web-server-task
  params:
  - name: batch-id
    value: "$LATEST_BATCH"
  - name: web-port
    value: "$WEB_PORT"
  workspaces:
  - name: shared-storage
    persistentVolumeClaim:
      claimName: shared-workspace-pvc
EOF

if [ $? -eq 0 ]; then
    echo "✅ Web server TaskRun created: $TASKRUN_NAME"
else
    echo "❌ Failed to create web server TaskRun"
    exit 1
fi

# Wait for TaskRun to start
echo ""
echo "⏳ Step 3: Waiting for Web Server to Start"
echo "=========================================="

echo "🔍 Monitoring TaskRun: $TASKRUN_NAME"

for i in {1..30}; do
    STATUS=$(kubectl get taskrun $TASKRUN_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
    REASON=$(kubectl get taskrun $TASKRUN_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "Unknown")
    
    echo "   🔄 Attempt $i/30: Status=$STATUS, Reason=$REASON"
    
    if [ "$STATUS" = "True" ] && [ "$REASON" = "Succeeded" ]; then
        echo "✅ Web server started successfully!"
        break
    elif [ "$STATUS" = "False" ]; then
        echo "❌ Web server failed to start"
        echo "📋 TaskRun details:"
        kubectl describe taskrun $TASKRUN_NAME -n $NAMESPACE
        exit 1
    fi
    
    sleep 10
done

# Create Service to expose the web server
echo ""
echo "🌐 Step 4: Creating Kubernetes Service"
echo "====================================="

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
  labels:
    app: rapids-artifacts-web
spec:
  selector:
    tekton.dev/taskRun: $TASKRUN_NAME
  ports:
  - name: web
    port: 80
    targetPort: $WEB_PORT
    protocol: TCP
  type: ClusterIP
EOF

if [ $? -eq 0 ]; then
    echo "✅ Service created: $SERVICE_NAME"
else
    echo "❌ Failed to create service"
    exit 1
fi

# Create Ingress for external access
echo ""
echo "🚪 Step 5: Creating Ingress for External Access"
echo "=============================================="

cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rapids-artifacts-ingress
  namespace: $NAMESPACE
  labels:
    app: rapids-artifacts-web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: $INGRESS_HOST
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $SERVICE_NAME
            port:
              number: 80
EOF

if [ $? -eq 0 ]; then
    echo "✅ Ingress created for host: $INGRESS_HOST"
else
    echo "❌ Failed to create ingress"
    exit 1
fi

# Display access information
echo ""
echo "🎉 Artifact Web Server Successfully Deployed!"
echo "============================================"
echo ""
echo "📋 Access Information:"
echo "   🌐 External URL: http://$INGRESS_HOST"
echo "   🔍 TaskRun: $TASKRUN_NAME"
echo "   📱 Service: $SERVICE_NAME"
echo "   📊 Current Batch: $LATEST_BATCH"
echo ""
echo "🎯 Web Interface Features:"
echo "   📓 Browse by Notebook Type (01-05)"
echo "   📦 Browse by Execution Batch"
echo "   ⭐ Quick access to Latest Results"
echo "   ⬇️  Direct file downloads"
echo "   📊 Execution status tracking"
echo ""
echo "🔧 Management Commands:"
echo "   Monitor TaskRun: kubectl logs -n $NAMESPACE -f taskrun/$TASKRUN_NAME"
echo "   Check Service: kubectl get svc $SERVICE_NAME -n $NAMESPACE"
echo "   View Ingress: kubectl get ingress rapids-artifacts-ingress -n $NAMESPACE"
echo ""
echo "🚀 Access your artifacts at: http://$INGRESS_HOST"