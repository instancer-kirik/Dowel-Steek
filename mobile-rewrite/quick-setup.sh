#!/bin/bash

# Dowel-Steek Mobile OS - Quick Setup (Modern)
# Uses your existing modern tools instead of downloading old versions

set -e

echo "🚀 Quick Setup: Dowel-Steek Mobile OS Development"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check existing tools
print_info "Checking your existing development environment..."

# Check Zig
if command -v zig >/dev/null 2>&1; then
    ZIG_VERSION=$(zig version)
    print_success "Zig found: $ZIG_VERSION"
else
    print_error "Zig not found. Please install Zig first."
    exit 1
fi

# Check SDL2
if pkg-config --exists sdl2; then
    SDL_VERSION=$(pkg-config --modversion sdl2)
    print_success "SDL2 found: $SDL_VERSION"
else
    print_warning "SDL2 development libraries not found"
    print_info "Install with: sudo pacman -S sdl2 (or your package manager)"
fi

# Check build tools
for tool in gcc g++ make git; do
    if command -v "$tool" >/dev/null 2>&1; then
        print_success "$tool available"
    else
        print_error "$tool not found"
        exit 1
    fi
done

echo
print_info "Setting up project structure..."

# Create build directories
mkdir -p build/{debug,release}/{zig,display,examples}
mkdir -p dist/{host,mobile,emulator}
mkdir -p logs

print_success "Build directories created"

# Build Zig core system
print_info "Building Zig core system..."
cd zig-core

if [[ -f "build.zig" ]]; then
    # Build for host development
    zig build -Doptimize=Debug
    print_success "Zig core built for host"
else
    print_warning "zig-core/build.zig not found, skipping core build"
fi

cd ..

# Build display system
print_info "Building display system..."
cd display-system

if [[ -f "build.zig" ]]; then
    # Build for host with SDL2
    zig build -Doptimize=Debug -Dtarget=native
    print_success "Display system built for host"
else
    print_warning "display-system/build.zig not found, skipping display build"
fi

cd ..

# Build examples
print_info "Building examples..."
cd examples

if [[ -f "build.zig" ]]; then
    zig build -Doptimize=Debug
    print_success "Examples built"
else
    print_warning "examples/build.zig not found, skipping examples"
fi

cd ..

# Create development scripts
print_info "Creating development scripts..."

cat > run-host.sh << 'EOF'
#!/bin/bash
echo "🖥️  Running Dowel-Steek Mobile OS on Host..."

# Run the host display demo
if [[ -f "display-system/zig-out/bin/host-demo" ]]; then
    echo "Starting display system..."
    ./display-system/zig-out/bin/host-demo
elif [[ -f "examples/zig-out/bin/mobile-demo" ]]; then
    echo "Starting example demo..."
    ./examples/zig-out/bin/mobile-demo
else
    echo "No demo found. Build with: zig build"
    exit 1
fi
EOF

cat > build-all.sh << 'EOF'
#!/bin/bash
echo "🔨 Building Dowel-Steek Mobile OS..."

set -e

# Build core system
if [[ -d "zig-core" ]]; then
    echo "Building Zig core..."
    cd zig-core && zig build && cd ..
fi

# Build display system
if [[ -d "display-system" ]]; then
    echo "Building display system..."
    cd display-system && zig build && cd ..
fi

# Build examples
if [[ -d "examples" ]]; then
    echo "Building examples..."
    cd examples && zig build && cd ..
fi

echo "✅ Build complete!"
echo "Run: ./run-host.sh"
EOF

cat > test-all.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing Dowel-Steek Mobile OS..."

set -e

# Test core system
if [[ -d "zig-core" ]]; then
    echo "Testing Zig core..."
    cd zig-core && zig build test && cd ..
fi

# Test display system
if [[ -d "display-system" ]]; then
    echo "Testing display system..."
    cd display-system && zig build test && cd ..
fi

echo "✅ All tests passed!"
EOF

chmod +x run-host.sh build-all.sh test-all.sh

print_success "Development scripts created"

# Create VS Code configuration
print_info "Setting up VS Code..."
mkdir -p .vscode

cat > .vscode/settings.json << EOF
{
    "zig.path": "$(which zig)",
    "files.associations": {
        "*.zig": "zig"
    },
    "C_Cpp.default.includePath": [
        "\${workspaceFolder}/zig-core/src",
        "\${workspaceFolder}/display-system/src",
        "/usr/include/SDL2"
    ],
    "search.exclude": {
        "**/zig-cache": true,
        "**/zig-out": true,
        "**/build": true
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
            }
        },
        {
            "label": "Run Host Demo",
            "type": "shell",
            "command": "./run-host.sh",
            "group": "build"
        },
        {
            "label": "Test All",
            "type": "shell",
            "command": "./test-all.sh",
            "group": "test"
        }
    ]
}
EOF

print_success "VS Code configuration created"

echo
print_success "🎉 Quick setup complete!"
echo
print_info "Next steps:"
echo "  1. Build everything: ./build-all.sh"
echo "  2. Run host demo: ./run-host.sh"
echo "  3. Run tests: ./test-all.sh"
echo "  4. Open in VS Code: code ."
echo
print_info "Your modern Zig version ($ZIG_VERSION) is perfect for this project!"
echo "No downgrades needed - you're all set! 🚀"
