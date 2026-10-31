#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Clean previous build artifacts (Optional, but recommended for avoiding stale ALI files)
# You can comment this out if you want faster incremental builds
rm -rf obj bin

# 2. Create directories
mkdir -p obj
mkdir -p bin

# 3. Compilation
# -----------------------------------------------------------------------------
# Flags Explanation:
# -D obj          : Place intermediate files (.ali, .o) in 'obj' directory
# -Isrc           : Source files are in 'src'
# -gnat2012       : Enforce Ada 2012 standard
# -gnatwa         : Enable all standard warnings
# -gnatQ          : Generate ALI files even on error (helps IDE/diagnostics)
# -O3             : Maximum optimization level (Critical for pixel loop speed)
# -gnatn          : Enable inlining of subprograms (Critical for removing function call overhead)
# -funroll-loops  : Unroll loops to reduce branch prediction overhead
# -o ...          : Output binary path
# -largs -lX11    : Link against the X11 library
# -----------------------------------------------------------------------------

echo "Building TitaniumBG with High Performance optimizations..."

gnatmake -D obj -Isrc \
    -gnat2012 \
    -O3 \
    -gnatn \
    -funroll-loops \
    -gnatwa \
    -gnatQ \
    src/main.adb \
    -o bin/titaniumbg \
    -largs -lX11

echo "-----------------------------------------------------"
echo "Build Successful."
echo "Binary location: bin/titaniumbg"
echo "Note: If you encounter a 'Stack Overflow', run: ulimit -s unlimited"
echo "-----------------------------------------------------"
