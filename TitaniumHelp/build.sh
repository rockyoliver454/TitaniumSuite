#!/bin/bash

# Exit on error
set -e

# Create directories if they don't exist
mkdir -p obj
mkdir -p bin

# Compile Command — same flags as the rest of the suite
echo "Building TitaniumHelp..."
gnatmake -D obj -Isrc -gnat2012 -gnatwa -gnatQ src/main.adb -o bin/titaniumhelp -largs -lX11

echo "Build Successful. Binary is in bin/titaniumhelp"
