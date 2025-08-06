#!/bin/bash
set -eu

echo "🧹 Final Cleanup: Removing Redundant Scripts and Files"
echo "======================================================"

# Create backup first
BACKUP_DIR=".tekton-final-cleanup-backup-$(date +%Y%m%d-%H%M%S)"
echo "📁 Creating backup at: $BACKUP_DIR"
cp -r .tekton "$BACKUP_DIR"

cd .tekton

echo ""
echo "🗑️ Step 1: Cleaning Scripts Directory"
echo "====================================="

# Keep only essential scripts
KEEP_SCRIPTS=(
    "run-4-notebooks-skip-2.sh"           # Main execution script for 4 notebooks
    "dashboard-monitor.sh"                 # Useful monitoring tool
)

echo "📋 Scripts to keep:"
for script in "${KEEP_SCRIPTS[@]}"; do
    if [ -f "scripts/$script" ]; then
        echo "   ✅ $script"
    else
        echo "   ❌ $script (not found)"
    fi
done

echo ""
echo "🗑️ Removing temporary and redundant scripts..."

# Remove temporary fix and test scripts
rm -f scripts/test-pytest-fix.sh
rm -f scripts/test-compatibility-fix.sh
rm -f scripts/verify-compatibility-patches.sh
rm -f scripts/fix-pipeline-issues.sh
rm -f scripts/fix-cleanup-issues.sh
rm -f scripts/cleanup-and-organize.sh
rm -f scripts/create-simple-step9.sh
rm -f scripts/run-final-validation.sh

# Remove web server scripts (replaced by simplified approach)
rm -f scripts/create-simple-results-server.sh
rm -f scripts/access-notebook01-results.sh
rm -f scripts/start-artifact-web-server.sh

echo "✅ Scripts cleanup completed"

echo ""
echo "🗑️ Step 2: Cleaning Pipelines Directory" 
echo "========================================"

# Keep only the latest working pipeline
if [ -f "pipelines/complete-notebook-workflow-latest.yaml" ]; then
    echo "📋 Keeping: complete-notebook-workflow-latest.yaml (most recent)"
    
    # Remove the older version
    if [ -f "pipelines/complete-notebook-workflow.yaml" ]; then
        echo "🗑️ Removing: complete-notebook-workflow.yaml (older version)"
        rm -f pipelines/complete-notebook-workflow.yaml
    fi
    
    # Rename latest to standard name
    echo "📝 Renaming latest to standard name..."
    mv pipelines/complete-notebook-workflow-latest.yaml pipelines/complete-notebook-workflow.yaml
else
    echo "✅ Only one pipeline file found, keeping as is"
fi

echo "✅ Pipelines cleanup completed"

echo ""
echo "🗑️ Step 3: Cleaning Tasks Directory"
echo "==================================="

# Keep only essential tasks
KEEP_TASKS=(
    "pytest-execution-enhanced.yaml"      # Enhanced pytest (latest version)
    "results-collection-simple.yaml"     # Simplified results collection
    "results-validation-cleanup-task.yaml" # Core cleanup task
    "jupyter-nbconvert-complete.yaml"    # Notebook conversion
    "large-dataset-download-task.yaml"   # Dataset download
    "safe-git-clone-task.yaml"           # Git operations
)

echo "📋 Tasks to keep:"
for task in "${KEEP_TASKS[@]}"; do
    if [ -f "tasks/$task" ]; then
        echo "   ✅ $task"
    else
        echo "   ❌ $task (not found)"
    fi
done

echo ""
echo "🗑️ Removing redundant tasks..."

# Remove old pytest version
rm -f tasks/pytest-execution.yaml

# Remove complex web server task (replaced by simple approach)
rm -f tasks/artifact-web-server-task.yaml

echo "✅ Tasks cleanup completed"

echo ""
echo "🗑️ Step 4: Cleaning Root Directory Files"
echo "========================================"

cd ..  # Back to project root

# Handle error_classification_guide.md
if [ -f "error_classification_guide.md" ]; then
    echo "📋 Found error_classification_guide.md"
    echo "🔄 Moving to .tekton/patches/ (useful for troubleshooting)"
    mv error_classification_guide.md .tekton/patches/
    echo "✅ Moved to .tekton/patches/error_classification_guide.md"
else
    echo "ℹ️ error_classification_guide.md not found"
fi

# Handle step9_simplified_script.sh
if [ -f "step9_simplified_script.sh" ]; then
    echo "📋 Found step9_simplified_script.sh"
    echo "🗑️ Removing (temporary file, functionality integrated into results-collection-simple.yaml)"
    rm -f step9_simplified_script.sh
    echo "✅ Removed step9_simplified_script.sh"
else
    echo "ℹ️ step9_simplified_script.sh not found"
fi

cd .tekton  # Back to .tekton directory

echo ""
echo "🗑️ Step 5: Other Cleanup"
echo "========================"

# Clean up any temporary files
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.bak" -delete 2>/dev/null || true

# Remove any empty directories
find . -type d -empty -delete 2>/dev/null || true

echo "✅ Other cleanup completed"

echo ""
echo "📊 Final Directory Structure:"
echo "============================="
tree -I '__pycache__' . || ls -la

echo ""
echo "📋 Summary of Kept Files:"
echo "========================"
echo ""
echo "📂 Scripts (Essential):"
echo "   • run-4-notebooks-skip-2.sh - Main 4-notebook execution"
echo "   • dashboard-monitor.sh - Monitoring utilities"
echo ""
echo "📂 Pipelines (Core):"
echo "   • complete-notebook-workflow.yaml - Main pipeline definition"
echo ""
echo "📂 Tasks (Essential):"
echo "   • pytest-execution-enhanced.yaml - Enhanced testing environment"
echo "   • results-collection-simple.yaml - Simplified results handling"
echo "   • jupyter-nbconvert-complete.yaml - Notebook conversion"
echo "   • large-dataset-download-task.yaml - Dataset handling"
echo "   • safe-git-clone-task.yaml - Git operations"
echo "   • results-validation-cleanup-task.yaml - Cleanup operations"
echo ""
echo "📂 Other (Preserved):"
echo "   • patches/ - Compatibility patches + error classification guide"
echo "   • configs/ - Configuration files"
echo "   • pipelineruns/ - Pipeline run templates"
echo "   • README.md - Documentation"
echo ""
echo "📂 Root Directory Files Processed:"
echo "   • error_classification_guide.md → moved to patches/"
echo "   • step9_simplified_script.sh → removed (integrated into task)"

echo ""
echo "🎉 Final cleanup completed!"
echo "📁 Backup available at: $BACKUP_DIR"
echo "✅ .tekton directory is now clean and organized"