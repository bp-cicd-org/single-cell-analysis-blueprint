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
