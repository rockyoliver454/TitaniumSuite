#!/bin/bash

# Exit on error
set -e

# Create directories if they don't exist
mkdir -p obj
mkdir -p bin

# Compile Command
# -D obj      : Put intermediate files (.ali, .o) in 'obj'
# -Isrc       : Look for source files in 'src'
# -gnat2012   : Enforce Ada 2012 standard
# -gnatwa     : Enable All Warnings (NASA Rule)
# -gnatQ      : Generate ALI files even if there are errors (helps diagnostics)
# -o ...      : Output binary name
# -largs      : Pass the following arguments to the linker
# -lX11       : Link the X11 library

echo "Building TitaniumRun..."
gnatmake -D obj -Isrc -gnat2012 -gnatwa -gnatQ src/main.adb -o bin/titaniumrun -largs -lX11

echo "Build Successful. Binary is in bin/titaniumrun"
