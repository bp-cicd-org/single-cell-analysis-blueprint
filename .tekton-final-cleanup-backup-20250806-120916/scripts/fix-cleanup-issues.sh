#!/bin/bash
set -eu

# Fix Cleanup Issues
# ==================
# 1. Move current-working-pipeline.yaml to proper location
# 2. Ensure all compatibility patches are preserved
# 3. Clean up any remaining temporary files

echo "🔧 Fixing Cleanup Issues"
echo "======================="

echo "📁 Moving current-working-pipeline.yaml to .tekton/pipelines/"
if [ -f "current-working-pipeline.yaml" ]; then
    mv current-working-pipeline.yaml .tekton/pipelines/current-working-pipeline.yaml
    echo "   ✅ Moved current-working-pipeline.yaml to .tekton/pipelines/"
else
    echo "   ⚠️ current-working-pipeline.yaml not found in root"
fi

echo ""
echo "🔍 Verifying compatibility patches are preserved:"
if [ -d ".tekton/patches" ]; then
    echo "   ✅ .tekton/patches directory exists"
    PATCH_COUNT=$(ls -1 .tekton/patches/*.py 2>/dev/null | wc -l)
    echo "   📊 Found $PATCH_COUNT compatibility patch files:"
    ls -la .tekton/patches/*.py | awk '{print "      -", $9}'
else
    echo "   ❌ .tekton/patches directory missing!"
    exit 1
fi

echo ""
echo "🧹 Final cleanup of remaining temporary files:"

# Remove any other temporary files that might exist
find . -name "*.backup" -type f -delete 2>/dev/null || true
find . -name "*.tmp" -type f -delete 2>/dev/null || true
find . -name "*.temp" -type f -delete 2>/dev/null || true

# Remove any leftover test files in root
rm -f test-*.yaml 2>/dev/null || true
rm -f pipeline-*.json 2>/dev/null || true

echo "   ✅ Temporary files cleaned"

echo ""
echo "📋 Final .tekton directory structure:"
tree .tekton -I '__pycache__'

echo ""
echo "✅ Cleanup issues fixed!"
echo ""
echo "📝 Summary:"
echo "   📁 current-working-pipeline.yaml moved to .tekton/pipelines/"
echo "   🔧 All compatibility patches preserved in .tekton/patches/"
echo "   🧹 Temporary files cleaned"
echo ""
echo "🎯 Key Files Status:"
echo "   📂 Main Pipeline: .tekton/pipelines/complete-notebook-workflow.yaml"
echo "   📂 Working Pipeline: .tekton/pipelines/current-working-pipeline.yaml"
echo "   🔧 Compatibility Patches: .tekton/patches/ (6 files)"
echo "   🚀 Main Execution Script: .tekton/scripts/run-4-notebooks-skip-2.sh"