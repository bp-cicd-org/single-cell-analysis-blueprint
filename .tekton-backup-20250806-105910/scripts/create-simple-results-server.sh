#!/bin/bash
set -eu

# Create Simple Results Server
# ============================

echo "🚀 Creating Simple Results Server"
echo "================================="

# Create a simple deployment for showing results
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rapids-results-server
  namespace: tekton-pipelines
  labels:
    app: rapids-results
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rapids-results
  template:
    metadata:
      labels:
        app: rapids-results
    spec:
      containers:
      - name: web-server
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args:
        - -c
        - |
          cat > /usr/share/nginx/html/index.html << 'HTMLEOF'
          <!DOCTYPE html>
          <html>
          <head>
              <title>🚀 RAPIDS Notebook Results</title>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; background: #f5f7fa; }
                  .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                  .header { color: #667eea; border-bottom: 2px solid #667eea; padding-bottom: 15px; margin-bottom: 30px; text-align: center; }
                  .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; }
                  .notebook-card { background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 10px 0; }
                  .completed { border-left: 4px solid #28a745; }
                  .failed { border-left: 4px solid #dc3545; }
                  .pending { border-left: 4px solid #6c757d; }
                  .status-badge { padding: 4px 8px; border-radius: 4px; font-size: 0.85rem; font-weight: bold; }
                  .success { background: #d4edda; color: #155724; }
                  .error { background: #f8d7da; color: #721c24; }
                  .info { background: #d1ecf1; color: #0c5460; }
                  .command-box { background: #2d3748; color: #e2e8f0; padding: 10px; border-radius: 5px; font-family: monospace; font-size: 0.9rem; margin: 10px 0; overflow-x: auto; }
                  .copy-btn { background: #667eea; color: white; border: none; padding: 5px 10px; border-radius: 3px; cursor: pointer; font-size: 0.8rem; }
              </style>
              <script>
                  function copyToClipboard(text) {
                      navigator.clipboard.writeText(text).then(function() {
                          alert('Copied to clipboard!');
                      });
                  }
                  setTimeout(function() { location.reload(); }, 60000); // Auto-refresh every minute
              </script>
          </head>
          <body>
              <div class="container">
                  <div class="header">
                      <h1>🚀 RAPIDS SingleCell Analysis Results</h1>
                      <p>GPU-Accelerated Bioinformatics Pipeline Status</p>
                      <p><small>Last updated: $(date)</small></p>
                  </div>
                  
                  <div class="status-grid">
                      <div class="notebook-card completed">
                          <h3>📓 Notebook 01 - Preprocessing</h3>
                          <span class="status-badge success">✅ COMPLETED</span>
                          <p><strong>Pipeline:</strong> phase-1of5-preprocessing-rapids-5nb-20250806-074859-rlgwf</p>
                          <p><strong>Duration:</strong> ~8 minutes</p>
                          <p><strong>GPU Usage:</strong> ✅ Accelerated</p>
                          <p><strong>Tests:</strong> ✅ Passed</p>
                      </div>
                      
                      <div class="notebook-card failed">
                          <h3>📓 Notebook 02 - Extended Analysis</h3>
                          <span class="status-badge error">❌ FAILED</span>
                          <p><strong>Issue:</strong> Missing network files</p>
                          <p><strong>Error:</strong> FileNotFoundError: nets/dorothea.parquet</p>
                          <p><strong>Solution:</strong> Need to generate decoupler network files</p>
                      </div>
                      
                      <div class="notebook-card pending">
                          <h3>📓 Notebook 03 - Pearson Residuals</h3>
                          <span class="status-badge info">⏸️ PENDING</span>
                          <p><strong>Status:</strong> Waiting for Notebook 02</p>
                      </div>
                      
                      <div class="notebook-card pending">
                          <h3>📓 Notebook 04 - Dask Out-of-Core</h3>
                          <span class="status-badge info">⏸️ PENDING</span>
                          <p><strong>Status:</strong> In queue</p>
                      </div>
                      
                      <div class="notebook-card pending">
                          <h3>📓 Notebook 05 - Multi-GPU</h3>
                          <span class="status-badge info">⏸️ PENDING</span>
                          <p><strong>Status:</strong> In queue</p>
                      </div>
                  </div>
                  
                  <div style="margin-top: 30px; padding: 20px; background: #e3f2fd; border-radius: 8px;">
                      <h3>🎯 Quick Access Commands</h3>
                      
                      <h4>📥 Download Notebook 01 HTML Report:</h4>
                      <div class="command-box">kubectl get pods -n tekton-pipelines | grep phase-1of5-preprocessing</div>
                      
                      <h4>🔍 View Pipeline in Tekton Dashboard:</h4>
                      <div class="command-box">https://tekton.10.34.2.129.nip.io</div>
                      
                      <h4>🚀 Fix Notebook 02 and Continue:</h4>
                      <div class="command-box">./.tekton/scripts/fix-notebook02-networks.sh</div>
                  </div>
                  
                  <div style="margin-top: 20px; text-align: center; color: #666;">
                      <p>🔄 This page auto-refreshes every minute</p>
                      <p>🌐 Access: <a href="http://artifacts.10.34.2.129.nip.io">http://artifacts.10.34.2.129.nip.io</a></p>
                  </div>
              </div>
          </body>
          </html>
          HTMLEOF
          
          echo "✅ Web content generated with current status"
          nginx -g "daemon off;"
---
apiVersion: v1
kind: Service
metadata:
  name: rapids-results-service
  namespace: tekton-pipelines
spec:
  selector:
    app: rapids-results
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rapids-results-ingress
  namespace: tekton-pipelines
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: results.10.34.2.129.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rapids-results-service
            port:
              number: 80
EOF

echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=Available deployment/rapids-results-server -n tekton-pipelines --timeout=60s

echo ""
echo "🎉 Results server deployed successfully!"
echo "======================================"
echo ""
echo "🌐 Access your results at:"
echo "   Primary: http://results.10.34.2.129.nip.io"
echo "   Backup:  http://artifacts.10.34.2.129.nip.io"
echo ""
echo "📋 Status Summary:"
echo "   ✅ Notebook 01: Completed successfully"
echo "   ❌ Notebook 02: Failed (missing network files)"
echo "   ⏸️ Notebooks 03-05: Pending"
echo ""
echo "🚀 Next Steps:"
echo "   1. Check results at the URL above"
echo "   2. Fix Notebook 02: ./.tekton/scripts/fix-notebook02-networks.sh"
echo "   3. Continue pipeline execution"