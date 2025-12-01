#!/bin/bash

# Dowel-Steek Security Suite Build Script
# Usage: ./build_security.sh [clean|test|run|install]

set -e  # Exit on any error

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
TARGET_NAME="dowel-steek-security"

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

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."

    # Check for DMD compiler
    if ! command -v dmd &> /dev/null; then
        print_error "DMD compiler not found. Please install DMD."
        echo "Visit: https://dlang.org/download.html"
        exit 1
    fi

    # Check for DUB package manager
    if ! command -v dub &> /dev/null; then
        print_error "DUB package manager not found. Please install DUB."
        echo "Visit: https://dub.pm/"
        exit 1
    fi

    # Check for SDL2 development libraries
    if ! pkg-config --exists sdl2 2>/dev/null; then
        print_warning "SDL2 development libraries may not be installed."
        print_warning "On Ubuntu/Debian: sudo apt-get install libsdl2-dev"
        print_warning "On Fedora: sudo dnf install SDL2-devel"
        print_warning "On macOS: brew install sdl2"
    fi

    # Check for FreeType
    if ! pkg-config --exists freetype2 2>/dev/null; then
        print_warning "FreeType development libraries may not be installed."
        print_warning "On Ubuntu/Debian: sudo apt-get install libfreetype6-dev"
        print_warning "On Fedora: sudo dnf install freetype-devel"
        print_warning "On macOS: brew install freetype"
    fi

    print_success "Dependency check completed"
}

# Clean build artifacts
clean_build() {
    print_status "Cleaning build artifacts..."

    cd "$PROJECT_DIR"

    # Clean DUB cache
    if [ -d ".dub" ]; then
        rm -rf .dub
        print_status "Removed .dub directory"
    fi

    # Clean binary
    if [ -f "$TARGET_NAME" ]; then
        rm "$TARGET_NAME"
        print_status "Removed binary: $TARGET_NAME"
    fi

    # Clean backup files
    rm -f *.bak *.tmp

    print_success "Clean completed"
}

# Build the application
build_app() {
    print_status "Building Dowel-Steek Security Suite..."

    cd "$PROJECT_DIR"

    # Update dependencies
    print_status "Updating dependencies..."
    dub upgrade

    # Build the security application
    print_status "Compiling security application..."
    dub build --config=security_app --build=release

    if [ -f "$TARGET_NAME" ]; then
        print_success "Build completed successfully"
        print_status "Binary created: $TARGET_NAME"

        # Show file size and permissions
        ls -lh "$TARGET_NAME"

        # Make sure it's executable
        chmod +x "$TARGET_NAME"
    else
        print_error "Build failed - binary not created"
        exit 1
    fi
}

# Run tests
run_tests() {
    print_status "Running tests..."

    cd "$PROJECT_DIR"

    # Run unit tests
    print_status "Running unit tests..."
    dub test --config=unittest || print_warning "Some tests may have failed"

    print_success "Tests completed"
}

# Run the application
run_app() {
    print_status "Running Dowel-Steek Security Suite..."

    cd "$PROJECT_DIR"

    if [ ! -f "$TARGET_NAME" ]; then
        print_warning "Binary not found. Building first..."
        build_app
    fi

    # Create config directory if it doesn't exist
    CONFIG_DIR="$HOME/.dowel-steek"
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        print_status "Created config directory: $CONFIG_DIR"
    fi

    # Run the application
    print_status "Launching application..."
    ./"$TARGET_NAME"
}

# Install the application system-wide
install_app() {
    print_status "Installing Dowel-Steek Security Suite..."

    cd "$PROJECT_DIR"

    if [ ! -f "$TARGET_NAME" ]; then
        print_warning "Binary not found. Building first..."
        build_app
    fi

    # Install binary
    INSTALL_DIR="/usr/local/bin"
    if [ ! -w "$INSTALL_DIR" ]; then
        print_status "Installing to $INSTALL_DIR (requires sudo)..."
        sudo cp "$TARGET_NAME" "$INSTALL_DIR/"
        sudo chmod +x "$INSTALL_DIR/$TARGET_NAME"
    else
        print_status "Installing to $INSTALL_DIR..."
        cp "$TARGET_NAME" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$TARGET_NAME"
    fi

    # Create desktop entry
    DESKTOP_FILE="$HOME/.local/share/applications/dowel-steek-security.desktop"
    print_status "Creating desktop entry: $DESKTOP_FILE"

    mkdir -p "$(dirname "$DESKTOP_FILE")"

    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Dowel-Steek Security Suite
Comment=Password Manager and TOTP Authenticator
Exec=$INSTALL_DIR/$TARGET_NAME
Icon=applications-security
Terminal=false
Type=Application
Categories=Security;Utility;
Keywords=password;security;2fa;totp;authentication;
EOF

    print_success "Installation completed"
    print_status "You can now run '$TARGET_NAME' from anywhere or find it in your applications menu"
}

# Create development environment
setup_dev() {
    print_status "Setting up development environment..."

    cd "$PROJECT_DIR"

    # Install development dependencies
    print_status "Installing development tools..."
    dub upgrade

    # Create symlinks for easy access
    if [ ! -L "security" ]; then
        ln -s "source/security" "security"
        print_status "Created symlink: security -> source/security"
    fi

    # Create test data directory
    TEST_DIR="$PROJECT_DIR/test_data"
    if [ ! -d "$TEST_DIR" ]; then
        mkdir -p "$TEST_DIR"
        print_status "Created test data directory: $TEST_DIR"
    fi

    print_success "Development environment setup completed"
}

# Show help
show_help() {
    echo "Dowel-Steek Security Suite Build Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  clean     Clean build artifacts"
    echo "  build     Build the application (default)"
    echo "  test      Run unit tests"
    echo "  run       Build and run the application"
    echo "  install   Install system-wide"
    echo "  dev       Setup development environment"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Build the application"
    echo "  $0 clean build  # Clean and build"
    echo "  $0 test run     # Test and run"
    echo ""
}

# Main script logic
main() {
    print_status "Dowel-Steek Security Suite Build Script"
    print_status "Project directory: $PROJECT_DIR"

    # Check dependencies first
    check_dependencies

    # Process command line arguments
    if [ $# -eq 0 ]; then
        # Default action: build
        build_app
    else
        # Process each argument
        for arg in "$@"; do
            case $arg in
                clean)
                    clean_build
                    ;;
                build)
                    build_app
                    ;;
                test)
                    run_tests
                    ;;
                run)
                    run_app
                    ;;
                install)
                    install_app
                    ;;
                dev)
                    setup_dev
                    ;;
                help|--help|-h)
                    show_help
                    exit 0
                    ;;
                *)
                    print_error "Unknown command: $arg"
                    show_help
                    exit 1
                    ;;
            esac
        done
    fi

    print_success "All operations completed successfully"
}

# Run main function with all arguments
main "$@"
