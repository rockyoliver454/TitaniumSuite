#!/bin/bash
# build-all.sh — Build TitaniumBG, TitaniumRun, TitaniumWM, TitaniumLogin
set -euo pipefail

SUITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SUITE_ROOT"

echo "========================================"
echo " Titanium Suite — build all"
echo "========================================"

echo ""
echo "[1/4] TitaniumBG..."
( cd "$SUITE_ROOT/TitaniumBG" && ulimit -s unlimited; ./build.sh )

echo ""
echo "[2/4] TitaniumRun..."
( cd "$SUITE_ROOT/TitaniumRun" && ./build.sh )
mkdir -p "$SUITE_ROOT/TitaniumRun/release/bin"
cp -f "$SUITE_ROOT/TitaniumRun/bin/titaniumrun" "$SUITE_ROOT/TitaniumRun/release/bin/titaniumrun"

echo ""
echo "[3/4] TitaniumWM..."
( cd "$SUITE_ROOT/TitaniumWM" && ./build.sh )
mkdir -p "$SUITE_ROOT/TitaniumWM/release/bin"
cp -f "$SUITE_ROOT/TitaniumWM/bin/titanium" "$SUITE_ROOT/TitaniumWM/release/bin/titanium"

echo ""
echo "[4/4] TitaniumLogin..."
( cd "$SUITE_ROOT/TitaniumLogin" && ./build.sh )

echo ""
echo "========================================"
echo " Build complete."
echo "  TitaniumBG    -> TitaniumBG/bin/titaniumbg"
echo "  TitaniumRun   -> TitaniumRun/bin/titaniumrun"
echo "  TitaniumWM    -> TitaniumWM/bin/titanium"
echo "  TitaniumLogin -> TitaniumLogin/bin/titaniumlogin"
echo "========================================"
