# Error Classification Guide

## 🟢 IGNORABLE ERRORS (Handled by Compatibility Patches)

### PCA Visualization Errors
- **Error Pattern**: `KeyError: 'pca'`
- **Location**: scanpy plotting functions
- **Impact**: Only affects PCA variance plots, not PCA computation itself
- **Action**: ✅ IGNORE - Core analysis data is complete

### AnnData Compatibility Errors  
- **Error Pattern**: `ImportError: cannot import name 'read_elem_as_dask'`
- **Location**: anndata.experimental imports
- **Impact**: Function name changed in newer versions
- **Action**: ✅ IGNORE - Automatically aliased to read_elem_lazy

### Visualization/Plotting Errors
- **Error Pattern**: KeyError in plotting functions
- **Location**: matplotlib, scanpy.pl.* functions
- **Impact**: Missing plots, but data analysis complete
- **Action**: ✅ IGNORE - Scientific results are valid

## 🔴 CRITICAL ERRORS (Require Attention)

### Data Loading Errors
- **Error Pattern**: `FileNotFoundError`, `OSError` for data files
- **Location**: File I/O operations  
- **Impact**: Cannot load required datasets
- **Action**: ❌ INVESTIGATE - Fix data availability

### Module Import Errors
- **Error Pattern**: `ModuleNotFoundError` for core packages
- **Location**: Core scientific libraries (rapids, scanpy, etc.)
- **Impact**: Cannot perform analysis
- **Action**: ❌ INVESTIGATE - Fix environment

### Memory/Resource Errors
- **Error Pattern**: `MemoryError`, `CUDA out of memory`
- **Location**: GPU operations
- **Impact**: Cannot complete computation
- **Action**: ❌ INVESTIGATE - Adjust resources

### Syntax/Logic Errors
- **Error Pattern**: `SyntaxError`, `IndentationError`, `NameError`
- **Location**: Code execution
- **Impact**: Code cannot run
- **Action**: ❌ INVESTIGATE - Fix code issues
