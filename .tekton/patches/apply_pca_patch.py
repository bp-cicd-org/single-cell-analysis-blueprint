#!/usr/bin/env python3
"""
Apply PCA compatibility patches for Notebook 01
===============================================
This ensures PCA plotting issues don't break notebook execution
"""

import os
import sys

# Add compatibility patches to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

# Apply the PCA compatibility patches
from pca_compat import patch_pca_compatibility, create_pca_error_handler

patch_pca_compatibility()
create_pca_error_handler()

print("🎯 PCA compatibility patches applied for Notebook 01")
print("    PCA plotting errors will be handled gracefully")
print("    Notebook execution will continue normally")
