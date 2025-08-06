#!/usr/bin/env python3
"""
Startup Compatibility Script
============================
Simple script to apply compatibility patches based on environment
"""

import os
import sys

# Add compatibility patches to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

# Get notebook name from environment or argument
notebook_name = os.environ.get('NOTEBOOK_NAME', 
                              sys.argv[1] if len(sys.argv) > 1 else None)

if notebook_name:
    print(f"🎯 Setting up compatibility for: {notebook_name}")
    from unified_compat import setup_compatibility
    setup_compatibility(notebook_name)
else:
    print("🔧 Setting up general compatibility patches")
    from unified_compat import setup_compatibility
    setup_compatibility()

print("✅ Compatibility system ready!")
