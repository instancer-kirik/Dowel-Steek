#!/bin/bash

# Dowel-Steek Mobile OS - Development Environment Setup
# This script sets up the development environment for building our custom mobile OS

set -e  # Exit on any error

echo "🚀 Setting up Dowel-Steek Mobile OS Development Environment..."
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    print_error "This setup script is designed for Linux. Other platforms are not supported yet."
    exit 1
fi

# Check if running with sudo for system packages
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root. Some operations may not work correctly."
fi

print_status "Checking system requirements..."

# Check for required commands
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# System requirements check
MISSING_DEPS=0

# Essential build tools
if ! check_command gcc; then MISSING_DEPS=$((MISSING_DEPS + 1)); fi
if ! check_command g++; then MISSING_DEPS=$((MISSING_DEPS + 1)); fi
if ! check_command make; then MISSING_DEPS=$((MISSING_DEPS + 1)); fi
if ! check_command git; then MISSING_DEPS=$((MISSING_DEPS + 1)); fi
if ! check_command curl; then MISSING_DEPS=$((MISSING_DEPS + 1)); fi
if ! check_command unzip; then MISSING_DEPS=$((MISSING_DEPS + 1)); fi

# Check for SDL2 development libraries
if ! pkg-config --exists sdl2; then
    print_error "SDL2 development libraries not found"
    MISSING_DEPS=$((MISSING_DEPS + 1))
else
    print_success "SDL2 development libraries found"
fi

# Install missing system dependencies
if [[ $MISSING_DEPS -gt 0 ]]; then
    print_status "Installing missing system dependencies..."

    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        print_status "Using apt package manager"
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            git \
            curl \
            unzip \
            libsdl2-dev \
            libsdl2-image-dev \
            pkg-config \
            cmake \
            ninja-build \
            clang \
            llvm
    elif command -v dnf >/dev/null 2>&1; then
        print_status "Using dnf package manager"
        sudo dnf install -y \
            gcc \
            gcc-c++ \
            make \
            git \
            curl \
            unzip \
            SDL2-devel \
            pkg-config \
            cmake \
            ninja-build \
            clang \
            llvm
    elif command -v pacman >/dev/null 2>&1; then
        print_status "Using pacman package manager"
        sudo pacman -S --needed \
            base-devel \
            git \
            curl \
            unzip \
            sdl2 \
            pkg-config \
            cmake \
            ninja \
            clang \
            llvm
    else
        print_error "Unsupported package manager. Please install dependencies manually:"
        echo "  - build-essential (gcc, g++, make)"
        echo "  - git, curl, unzip"
        echo "  - SDL2 development libraries"
        echo "  - pkg-config, cmake, ninja"
        echo "  - clang, llvm"
        exit 1
    fi
else
    print_success "All system dependencies are installed"
fi

# Install Zig
print_status "Checking Zig installation..."
ZIG_VERSION="0.11.0"
ZIG_DIR="$HOME/.local/zig"

if command -v zig >/dev/null 2>&1; then
    CURRENT_ZIG_VERSION=$(zig version)
    if [[ "$CURRENT_ZIG_VERSION" == "$ZIG_VERSION" ]]; then
        print_success "Zig $ZIG_VERSION is already installed"
    else
        print_warning "Different Zig version found: $CURRENT_ZIG_VERSION"
        print_status "Installing Zig $ZIG_VERSION..."
        INSTALL_ZIG=1
    fi
else
    print_status "Installing Zig $ZIG_VERSION..."
    INSTALL_ZIG=1
fi

if [[ "${INSTALL_ZIG:-0}" == "1" ]]; then
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ZIG_ARCH="x86_64"
            ;;
        aarch64|arm64)
            ZIG_ARCH="aarch64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    ZIG_TARBALL="zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz"
    ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARBALL}"

    print_status "Downloading Zig from $ZIG_URL"

    mkdir -p "$HOME/.local"
    cd "$HOME/.local"

    # Remove old installation
    if [[ -d "$ZIG_DIR" ]]; then
        rm -rf "$ZIG_DIR"
    fi

    # Download and extract
    curl -L -o "$ZIG_TARBALL" "$ZIG_URL"
    tar -xf "$ZIG_TARBALL"
    mv "zig-linux-${ZIG_ARCH}-${ZIG_VERSION}" zig
    rm "$ZIG_TARBALL"

    # Add to PATH
    if ! grep -q "$ZIG_DIR" "$HOME/.bashrc"; then
        echo "export PATH=\"$ZIG_DIR:\$PATH\"" >> "$HOME/.bashrc"
        print_status "Added Zig to PATH in ~/.bashrc"
    fi

    if ! grep -q "$ZIG_DIR" "$HOME/.zshrc" 2>/dev/null; then
        echo "export PATH=\"$ZIG_DIR:\$PATH\"" >> "$HOME/.zshrc" 2>/dev/null || true
        print_status "Added Zig to PATH in ~/.zshrc"
    fi

    # Export for current session
    export PATH="$ZIG_DIR:$PATH"

    print_success "Zig $ZIG_VERSION installed successfully"
fi

# Install Kotlin/Native
print_status "Checking Kotlin/Native installation..."
KOTLIN_VERSION="1.9.20"
KOTLIN_DIR="$HOME/.local/kotlin"

if [[ -d "$KOTLIN_DIR/bin" ]] && command -v "$KOTLIN_DIR/bin/kotlin" >/dev/null 2>&1; then
    print_success "Kotlin is already installed"
else
    print_status "Installing Kotlin $KOTLIN_VERSION..."

    KOTLIN_ZIP="kotlin-compiler-${KOTLIN_VERSION}.zip"
    KOTLIN_URL="https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/${KOTLIN_ZIP}"

    mkdir -p "$HOME/.local"
    cd "$HOME/.local"

    # Remove old installation
    if [[ -d "$KOTLIN_DIR" ]]; then
        rm -rf "$KOTLIN_DIR"
    fi

    # Download and extract
    curl -L -o "$KOTLIN_ZIP" "$KOTLIN_URL"
    unzip -q "$KOTLIN_ZIP"
    mv kotlinc kotlin
    rm "$KOTLIN_ZIP"

    # Add to PATH
    if ! grep -q "$KOTLIN_DIR/bin" "$HOME/.bashrc"; then
        echo "export PATH=\"$KOTLIN_DIR/bin:\$PATH\"" >> "$HOME/.bashrc"
        print_status "Added Kotlin to PATH in ~/.bashrc"
    fi

    if ! grep -q "$KOTLIN_DIR/bin" "$HOME/.zshrc" 2>/dev/null; then
        echo "export PATH=\"$KOTLIN_DIR/bin:\$PATH\"" >> "$HOME/.zshrc" 2>/dev/null || true
        print_status "Added Kotlin to PATH in ~/.zshrc"
    fi

    # Export for current session
    export PATH="$KOTLIN_DIR/bin:$PATH"

    print_success "Kotlin $KOTLIN_VERSION installed successfully"
fi

# Set up cross-compilation for ARM64
print_status "Setting up cross-compilation environment..."

# Install ARM64 cross-compilation tools
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        libc6-dev-arm64-cross
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y \
        gcc-aarch64-linux-gnu \
        gcc-c++-aarch64-linux-gnu
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed \
        aarch64-linux-gnu-gcc
fi

# Create development directories
print_status "Setting up project directories..."
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Create build output directories
mkdir -p build/{debug,release}/{zig,kotlin,display}
mkdir -p dist/{emulator,mobile}
mkdir -p logs
mkdir -p tools

print_success "Project directories created"

# Build the display system
print_status "Building display system..."
cd display-system

if [[ -f "build.zig" ]]; then
    # Build for emulator (x86_64 with SDL2)
    print_status "Building display system for emulator..."
    zig build emulator

    # Build for mobile (ARM64)
    print_status "Building display system for mobile..."
    zig build mobile

    print_success "Display system built successfully"
else
    print_warning "Display system build.zig not found, skipping build"
fi

cd "$PROJECT_ROOT"

# Build Zig core
print_status "Building Zig core system..."
cd zig-core

if [[ -f "build.zig" ]]; then
    # Build for emulator
    zig build

    # Build for mobile targets
    zig build mobile

    print_success "Zig core system built successfully"
else
    print_warning "Zig core build.zig not found, skipping build"
fi

cd "$PROJECT_ROOT"

# Build Kotlin multiplatform
print_status "Building Kotlin multiplatform framework..."
cd kotlin-multiplatform

if [[ -f "gradlew" ]]; then
    ./gradlew buildDowelOS
    print_success "Kotlin multiplatform framework built successfully"
elif [[ -f "build.gradle.kts" ]]; then
    if command -v gradle >/dev/null 2>&1; then
        gradle buildDowelOS
        print_success "Kotlin multiplatform framework built successfully"
    else
        print_warning "Gradle not found, skipping Kotlin build"
    fi
else
    print_warning "Kotlin build files not found, skipping build"
fi

cd "$PROJECT_ROOT"

# Create development scripts
print_status "Creating development scripts..."

# Create emulator launch script
cat > run-emulator.sh << 'EOF'
#!/bin/bash
set -e

echo "🖥️  Launching Dowel-Steek Mobile OS Emulator..."

# Set up environment
export DOWEL_MODE=emulator
export DOWEL_LOG_LEVEL=debug

# Launch display demo
if [[ -f "display-system/zig-out/bin/display-demo" ]]; then
    echo "Starting display system demo..."
    ./display-system/zig-out/bin/display-demo
else
    echo "Display demo not found. Run ./setup-dev.sh to build."
    exit 1
fi
EOF

chmod +x run-emulator.sh

# Create test runner script
cat > run-tests.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running Dowel-Steek Mobile OS Tests..."

# Test Zig components
echo "Testing Zig core..."
cd zig-core && zig build test && cd ..

echo "Testing display system..."
cd display-system && zig build test && cd ..

# Test Kotlin components
echo "Testing Kotlin components..."
cd kotlin-multiplatform && ./gradlew test && cd ..

echo "✅ All tests passed!"
EOF

chmod +x run-tests.sh

# Create build script
cat > build-all.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building Dowel-Steek Mobile OS..."

# Build for emulator
echo "Building for emulator..."
cd zig-core && zig build && cd ..
cd display-system && zig build emulator && cd ..
cd kotlin-multiplatform && ./gradlew buildDowelOS && cd ..

# Build for mobile hardware
echo "Building for mobile hardware..."
cd zig-core && zig build mobile && cd ..
cd display-system && zig build mobile && cd ..

echo "✅ Build complete!"
echo "   Emulator: ./run-emulator.sh"
echo "   Tests: ./run-tests.sh"
EOF

chmod +x build-all.sh

print_success "Development scripts created"

# Create VS Code configuration
print_status "Setting up VS Code configuration..."
mkdir -p .vscode

cat > .vscode/settings.json << 'EOF'
{
    "zig.path": "~/.local/zig/zig",
    "zig.zls.path": "~/.local/bin/zls",
    "kotlin.compiler.jvm.target": "1.8",
    "files.associations": {
        "*.zig": "zig",
        "*.kt": "kotlin"
    },
    "C_Cpp.default.includePath": [
        "${workspaceFolder}/zig-core/c_headers",
        "${workspaceFolder}/display-system/c_headers",
        "/usr/include/SDL2"
    ],
    "search.exclude": {
        "**/zig-cache": true,
        "**/zig-out": true,
        "**/build": true,
        "**/.gradle": true
    }
}
EOF

cat > .vscode/tasks.json << 'EOF'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build All",
            "type": "shell",
            "command": "./build-all.sh",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": []
        },
        {
            "label": "Run Emulator",
            "type": "shell",
            "command": "./run-emulator.sh",
            "group": "build",
            "problemMatcher": []
        },
        {
            "label": "Run Tests",
            "type": "shell",
            "command": "./run-tests.sh",
            "group": "test",
            "problemMatcher": []
        },
        {
            "label": "Build Zig Core",
            "type": "shell",
            "command": "zig build",
            "options": {
                "cwd": "${workspaceFolder}/zig-core"
            },
            "group": "build",
            "problemMatcher": []
        },
        {
            "label": "Build Display System",
            "type": "shell",
            "command": "zig build",
            "options": {
                "cwd": "${workspaceFolder}/display-system"
            },
            "group": "build",
            "problemMatcher": []
        }
    ]
}
EOF

print_success "VS Code configuration created"

# Final setup message
echo
echo "🎉 Dowel-Steek Mobile OS Development Environment Setup Complete!"
echo
print_success "Next steps:"
echo "  1. Restart your terminal or run: source ~/.bashrc"
echo "  2. Test the setup: ./run-tests.sh"
echo "  3. Launch emulator: ./run-emulator.sh"
echo "  4. Open in VS Code: code ."
echo
print_status "Development commands:"
echo "  ./build-all.sh       - Build entire OS"
echo "  ./run-emulator.sh    - Launch emulator"
echo "  ./run-tests.sh       - Run all tests"
echo
print_status "Architecture overview:"
echo "  zig-core/            - System services (Zig)"
echo "  display-system/      - Graphics and display (Zig)"
echo "  kotlin-multiplatform/ - Application framework (Kotlin)"
echo
print_warning "If you encounter issues:"
echo "  1. Make sure you restart your terminal"
echo "  2. Check that PATH includes Zig and Kotlin"
echo "  3. Verify SDL2 development libraries are installed"
echo
echo "Happy hacking! 🚀"
