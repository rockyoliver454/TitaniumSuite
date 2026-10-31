#!/bin/bash
# Build TitaniumLogin (console display manager).
# Links libpam. Optionally -lutil (BSD); harmless if unused on Linux.
# If libpam0g-dev is missing, falls back to linking libpam.so.0 by soname.

set -e

mkdir -p obj
mkdir -p bin

echo "Building TitaniumLogin..."

GNAT_FLAGS=(-D obj -Isrc -gnat2012 -gnatwa -gnatQ src/main.adb -o bin/titaniumlogin)

try_link() {
  local desc="$1"
  shift
  echo "  link attempt: $desc"
  if gnatmake "${GNAT_FLAGS[@]}" -largs "$@"; then
    echo "Build Successful. Binary is in bin/titaniumlogin"
    return 0
  fi
  return 1
}

if try_link "-lpam -lutil" -lpam -lutil; then
  exit 0
fi

if try_link "-lpam" -lpam; then
  exit 0
fi

# Runtime library present without -dev symlink (common on minimal hosts)
if try_link "-l:libpam.so.0" -l:libpam.so.0; then
  echo "Note: linked against libpam.so.0 (install libpam development package for -lpam)."
  exit 0
fi

echo "ERROR: PAM link failed. Sources are complete; install libpam (e.g. libpam0g-dev) and rebuild."
exit 1
