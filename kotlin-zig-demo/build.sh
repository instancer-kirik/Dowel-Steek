#!/bin/bash

# Build script for Kotlin-Zig Integration Demo
set -e

echo "🔨 Building Kotlin-Zig Integration Demo..."

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIG_LIB_PATH="$SCRIPT_DIR/../mobile-rewrite/zig-core/zig-out/lib"
ZIG_HEADER_PATH="$SCRIPT_DIR/../mobile-rewrite/zig-core/c_headers"

# Check if Zig library exists
if [ ! -f "$ZIG_LIB_PATH/libdowel-steek-minimal.a" ]; then
    echo "❌ Zig library not found. Building it first..."
    cd "$SCRIPT_DIR/../mobile-rewrite/zig-core"
    zig build minimal -Doptimize=ReleaseFast
    cd "$SCRIPT_DIR"
fi

echo "✅ Zig library found: $ZIG_LIB_PATH/libdowel-steek-minimal.a"

# Check if kotlinc-native is available
if ! command -v kotlinc-native &> /dev/null; then
    echo "❌ kotlinc-native not found. Please install Kotlin/Native compiler."
    echo "   You can download it from: https://github.com/JetBrains/kotlin/releases"
    exit 1
fi

echo "✅ Kotlin/Native compiler found"

# Build the demo
echo "🔨 Compiling Kotlin/Native application..."

kotlinc-native \
    -include-binary "$ZIG_LIB_PATH/libdowel-steek-minimal.a" \
    -o kotlin-zig-demo \
    demo.kt

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "📱 Running the demo..."
    echo "================================"
    ./kotlin-zig-demo.kexe
else
    echo "❌ Build failed!"
    exit 1
fi
