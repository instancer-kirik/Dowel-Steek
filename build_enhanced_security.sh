#!/bin/bash

# Enhanced Security Suite Build Script
# Dowel-Steek Enhanced Password Manager & Authenticator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TARGET_NAME="dowel-steek-enhanced-security"
CONFIG_NAME="enhanced_security_app"
BUILD_DIR="build"
INSTALL_PREFIX="/usr/local"

# Helper functions
print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}\n"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_dependencies() {
    print_info "Checking dependencies..."

    # Check for D compiler
    if ! command -v dmd >/dev/null 2>&1 && ! command -v ldc2 >/dev/null 2>&1; then
        print_error "No D compiler found (dmd or ldc2 required)"
        exit 1
    fi

    # Check for dub
    if ! command -v dub >/dev/null 2>&1; then
        print_error "dub package manager not found"
        exit 1
    fi

    # Check for SDL2 development libraries
    if ! pkg-config --exists sdl2 2>/dev/null; then
        print_warning "SDL2 development libraries not found via pkg-config"
        print_info "You may need to install SDL2 development packages:"
        print_info "  Ubuntu/Debian: sudo apt install libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev"
        print_info "  Fedora/RHEL: sudo dnf install SDL2-devel SDL2_image-devel SDL2_ttf-devel"
        print_info "  Arch: sudo pacman -S sdl2 sdl2_image sdl2_ttf"
        print_info "  macOS: brew install sdl2 sdl2_image sdl2_ttf"
    fi

    print_success "Dependencies check completed"
}

show_help() {
    echo -e "${CYAN}Enhanced Security Suite Build Script${NC}"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build         Build the application (default)"
    echo "  run           Build and run the application"
    echo "  release       Build optimized release version"
    echo "  debug         Build debug version with verbose output"
    echo "  test          Run tests"
    echo "  clean         Clean build artifacts"
    echo "  install       Install to system (requires sudo)"
    echo "  uninstall     Remove from system (requires sudo)"
    echo "  package       Create distribution package"
    echo "  deps          Check and install dependencies"
    echo "  info          Show application information"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build application"
    echo "  $0 run               # Build and run"
    echo "  $0 release           # Build optimized version"
    echo "  $0 clean build       # Clean and build"
}

build_app() {
    local build_type="${1:-debug}"

    print_header "Building Enhanced Security Suite ($build_type)"

    # Create build directory
    mkdir -p "$BUILD_DIR"

    # Set build flags based on type
    local dub_flags=""
    case "$build_type" in
        "release")
            dub_flags="--build=release-nobounds --compiler=ldc2"
            print_info "Building optimized release version..."
            ;;
        "debug")
            dub_flags="--build=debug"
            print_info "Building debug version..."
            ;;
        "profile")
            dub_flags="--build=profile"
            print_info "Building with profiling enabled..."
            ;;
    esac

    # Build with dub
    print_info "Running: dub build --config=$CONFIG_NAME $dub_flags"

    if dub build --config="$CONFIG_NAME" $dub_flags; then
        local binary_size=$(stat -c%s "$TARGET_NAME" 2>/dev/null || stat -f%z "$TARGET_NAME" 2>/dev/null || echo "unknown")
        if [ "$binary_size" != "unknown" ]; then
            binary_size=$(echo "$binary_size" | awk '{printf "%.1f MB", $1/1024/1024}')
        fi

        print_success "Build completed successfully!"
        print_info "Binary: $TARGET_NAME ($binary_size)"

        # Check if binary exists and is executable
        if [ -f "$TARGET_NAME" ] && [ -x "$TARGET_NAME" ]; then
            print_success "Binary is ready to run: ./$TARGET_NAME"
        else
            print_error "Binary was not created or is not executable"
            return 1
        fi
    else
        print_error "Build failed!"
        return 1
    fi
}

run_app() {
    print_header "Building and Running Enhanced Security Suite"

    if build_app "debug"; then
        print_info "Starting application..."
        echo ""
        ./"$TARGET_NAME"
    else
        print_error "Cannot run - build failed"
        return 1
    fi
}

run_tests() {
    print_header "Running Tests"

    print_info "Running unit tests..."
    if dub test --config="$CONFIG_NAME"; then
        print_success "All tests passed!"
    else
        print_error "Tests failed!"
        return 1
    fi

    # Run security-specific tests if they exist
    if [ -f "test_security_suite.d" ]; then
        print_info "Running security suite tests..."
        if dub run --single test_security_suite.d; then
            print_success "Security tests passed!"
        else
            print_warning "Some security tests failed"
        fi
    fi
}

clean_build() {
    print_header "Cleaning Build Artifacts"

    print_info "Cleaning dub cache..."
    dub clean --config="$CONFIG_NAME" >/dev/null 2>&1 || true

    print_info "Removing build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -f "$TARGET_NAME"
    rm -f "$TARGET_NAME.exe"
    rm -f *.o
    rm -f *.obj
    rm -f .dub/

    print_success "Clean completed"
}

install_app() {
    print_header "Installing Enhanced Security Suite"

    if [ ! -f "$TARGET_NAME" ]; then
        print_info "Binary not found, building first..."
        if ! build_app "release"; then
            print_error "Build failed, cannot install"
            return 1
        fi
    fi

    print_info "Installing to $INSTALL_PREFIX/bin/"

    if [ "$EUID" -ne 0 ]; then
        print_info "Root privileges required for installation"
        sudo cp "$TARGET_NAME" "$INSTALL_PREFIX/bin/"
        sudo chmod +x "$INSTALL_PREFIX/bin/$TARGET_NAME"
    else
        cp "$TARGET_NAME" "$INSTALL_PREFIX/bin/"
        chmod +x "$INSTALL_PREFIX/bin/$TARGET_NAME"
    fi

    # Create desktop entry
    local desktop_file="/usr/share/applications/dowel-steek-security.desktop"
    print_info "Creating desktop entry: $desktop_file"

    local desktop_content="[Desktop Entry]
Name=Dowel-Steek Security Suite
Comment=Password Manager and Authenticator
Exec=$INSTALL_PREFIX/bin/$TARGET_NAME
Icon=security
Terminal=false
Type=Application
Categories=Utility;Security;
Keywords=password;security;2fa;totp;vault;"

    if [ "$EUID" -ne 0 ]; then
        echo "$desktop_content" | sudo tee "$desktop_file" >/dev/null
        sudo chmod 644 "$desktop_file"
    else
        echo "$desktop_content" > "$desktop_file"
        chmod 644 "$desktop_file"
    fi

    print_success "Installation completed!"
    print_info "You can now run: $TARGET_NAME"
    print_info "Or find it in your applications menu"
}

uninstall_app() {
    print_header "Uninstalling Enhanced Security Suite"

    print_info "Removing binary..."
    if [ "$EUID" -ne 0 ]; then
        sudo rm -f "$INSTALL_PREFIX/bin/$TARGET_NAME"
        sudo rm -f "/usr/share/applications/dowel-steek-security.desktop"
    else
        rm -f "$INSTALL_PREFIX/bin/$TARGET_NAME"
        rm -f "/usr/share/applications/dowel-steek-security.desktop"
    fi

    print_success "Uninstallation completed!"
}

create_package() {
    print_header "Creating Distribution Package"

    local version="1.0.0"
    local package_name="dowel-steek-security-$version"
    local package_dir="packages/$package_name"

    print_info "Building release version..."
    if ! build_app "release"; then
        print_error "Build failed, cannot create package"
        return 1
    fi

    print_info "Creating package structure..."
    mkdir -p "packages"
    rm -rf "$package_dir"
    mkdir -p "$package_dir/bin"
    mkdir -p "$package_dir/doc"
    mkdir -p "$package_dir/examples"

    # Copy binary
    cp "$TARGET_NAME" "$package_dir/bin/"
    chmod +x "$package_dir/bin/$TARGET_NAME"

    # Copy documentation
    cp -r SECURITY_README.md "$package_dir/doc/" 2>/dev/null || true
    cp -r SECURITY_USAGE.md "$package_dir/doc/" 2>/dev/null || true

    # Create install script
    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
echo "Installing Dowel-Steek Security Suite..."
sudo cp bin/dowel-steek-enhanced-security /usr/local/bin/
sudo chmod +x /usr/local/bin/dowel-steek-enhanced-security
echo "Installation complete! Run: dowel-steek-enhanced-security"
EOF
    chmod +x "$package_dir/install.sh"

    # Create archive
    print_info "Creating archive..."
    cd packages
    tar -czf "$package_name.tar.gz" "$package_name"
    cd ..

    local package_size=$(stat -c%s "packages/$package_name.tar.gz" 2>/dev/null || stat -f%z "packages/$package_name.tar.gz" 2>/dev/null || echo "unknown")
    if [ "$package_size" != "unknown" ]; then
        package_size=$(echo "$package_size" | awk '{printf "%.1f MB", $1/1024/1024}')
    fi

    print_success "Package created: packages/$package_name.tar.gz ($package_size)"
}

install_deps() {
    print_header "Installing Dependencies"

    print_info "Detecting system..."

    if command -v apt >/dev/null 2>&1; then
        print_info "Ubuntu/Debian detected"
        print_info "Installing SDL2 development packages..."
        sudo apt update
        sudo apt install -y libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libssl-dev

    elif command -v dnf >/dev/null 2>&1; then
        print_info "Fedora/RHEL detected"
        print_info "Installing SDL2 development packages..."
        sudo dnf install -y SDL2-devel SDL2_image-devel SDL2_ttf-devel openssl-devel

    elif command -v pacman >/dev/null 2>&1; then
        print_info "Arch Linux detected"
        print_info "Installing SDL2 development packages..."
        sudo pacman -S --noconfirm sdl2 sdl2_image sdl2_ttf openssl

    elif command -v brew >/dev/null 2>&1; then
        print_info "macOS with Homebrew detected"
        print_info "Installing SDL2 development packages..."
        brew install sdl2 sdl2_image sdl2_ttf openssl

    else
        print_warning "Unknown system - please install SDL2 development packages manually"
        return 1
    fi

    print_success "Dependencies installed successfully!"
}

show_info() {
    print_header "Enhanced Security Suite Information"

    echo -e "${CYAN}Application:${NC} Dowel-Steek Enhanced Security Suite"
    echo -e "${CYAN}Version:${NC} 1.0.0"
    echo -e "${CYAN}Description:${NC} Modern password manager and TOTP authenticator"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "  • AES-256 encryption with PBKDF2 key derivation"
    echo "  • Multiple entry types (Login, Card, Identity, Secure Note)"
    echo "  • TOTP/2FA code generation"
    echo "  • Password strength analysis"
    echo "  • Security dashboard and reporting"
    echo "  • Modern dark/light theme"
    echo "  • Import/Export (Bitwarden compatible)"
    echo "  • Auto-lock and clipboard security"
    echo ""
    echo -e "${CYAN}Build Configuration:${NC}"
    echo "  • Target: $TARGET_NAME"
    echo "  • Config: $CONFIG_NAME"
    echo "  • Source: source/security/enhanced_security_app.d"
    echo ""
    echo -e "${CYAN}System Requirements:${NC}"
    echo "  • D compiler (DMD or LDC)"
    echo "  • SDL2 development libraries"
    echo "  • OpenSSL libraries"

    if [ -f "$TARGET_NAME" ]; then
        local binary_size=$(stat -c%s "$TARGET_NAME" 2>/dev/null || stat -f%z "$TARGET_NAME" 2>/dev/null || echo "unknown")
        if [ "$binary_size" != "unknown" ]; then
            binary_size=$(echo "$binary_size" | awk '{printf "%.1f MB", $1/1024/1024}')
            echo ""
            echo -e "${CYAN}Current Binary:${NC} $binary_size"
        fi
    fi
}

# Main script logic
case "${1:-build}" in
    "build")
        check_dependencies
        build_app "${2:-debug}"
        ;;
    "run")
        check_dependencies
        run_app
        ;;
    "release")
        check_dependencies
        build_app "release"
        ;;
    "debug")
        check_dependencies
        build_app "debug"
        ;;
    "profile")
        check_dependencies
        build_app "profile"
        ;;
    "test")
        check_dependencies
        run_tests
        ;;
    "clean")
        clean_build
        if [ "$2" = "build" ]; then
            check_dependencies
            build_app
        fi
        ;;
    "install")
        install_app
        ;;
    "uninstall")
        uninstall_app
        ;;
    "package")
        check_dependencies
        create_package
        ;;
    "deps")
        install_deps
        ;;
    "info")
        show_info
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
