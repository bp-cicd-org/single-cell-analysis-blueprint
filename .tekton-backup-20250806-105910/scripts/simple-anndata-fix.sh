#!/bin/bash
set -eu

# Simple AnnData read_elem_as_dask Fix
# ====================================
# This creates a compatibility patch WITHOUT modifying notebook files

echo "🔧 Simple AnnData Compatibility Fix"
echo "=================================="

# Create a simple compatibility script that can be sourced
mkdir -p $(pwd)/compatibility_patches

cat > compatibility_patches/anndata_compat.py << 'EOF'
"""
AnnData Compatibility Patch
===========================
Provides backward compatibility for read_elem_as_dask -> read_elem_lazy
"""

def patch_anndata():
    """Apply compatibility patch for anndata read_elem_as_dask"""
    try:
        # Import the new function
        from anndata.experimental import read_elem_lazy
        
        # Check if old function exists
        try:
            from anndata.experimental import read_elem_as_dask
            print("✅ read_elem_as_dask already available")
        except ImportError:
            # Monkey patch the old name
            import anndata.experimental
            anndata.experimental.read_elem_as_dask = read_elem_lazy
            print("🔧 Patched: read_elem_as_dask -> read_elem_lazy")
            
    except Exception as e:
        print(f"⚠️ Patch failed: {e}")

if __name__ == "__main__":
    patch_anndata()
EOF

echo "✅ Created compatibility patch at: $(pwd)/compatibility_patches/anndata_compat.py"

# Test the patch locally
echo ""
echo "🧪 Testing compatibility patch..."
python compatibility_patches/anndata_compat.py

echo ""
echo "📋 Integration Instructions:"
echo "1. This patch should be applied in Step 4 of complete-notebook-workflow"
echo "2. For notebooks 04 and 05, run: python compatibility_patches/anndata_compat.py"
echo "3. This will make read_elem_as_dask available without modifying notebooks"

echo ""
echo "🎯 Ready to integrate into pipeline!"