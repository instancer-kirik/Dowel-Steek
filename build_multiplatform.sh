#!/bin/bash

# Multi-Platform Build System for Dowel-Steek Enhanced Security Suite
# Supports: Linux, Windows, macOS, Custom Mobile OS, Android, iOS

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
PROJECT_NAME="dowel-steek-security"
VERSION="1.0.0"
BUILD_DIR="build"
DIST_DIR="dist"

# Platform configurations
declare -A PLATFORMS=(
    ["linux-x64"]="--arch=x86_64 --os=linux"
    ["linux-arm64"]="--arch=aarch64 --os=linux"
    ["linux-armhf"]="--arch=arm --os=linux"
    ["windows-x64"]="--arch=x86_64 --os=windows"
    ["windows-x86"]="--arch=x86 --os=windows"
    ["macos-x64"]="--arch=x86_64 --os=osx"
    ["macos-arm64"]="--arch=aarch64 --os=osx"
    ["android-arm64"]="--arch=aarch64 --os=android"
    ["android-armv7"]="--arch=arm --os=android"
    ["ios-arm64"]="--arch=aarch64 --os=ios"
    ["custom-mobile-os"]="--arch=aarch64 --os=linux"
    ["freebsd-x64"]="--arch=x86_64 --os=freebsd"
    ["openbsd-x64"]="--arch=x86_64 --os=openbsd"
    ["netbsd-x64"]="--arch=x86_64 --os=netbsd"
)

# Target-specific configurations
declare -A TARGET_CONFIGS=(
    ["linux-x64"]="enhanced_security_app"
    ["linux-arm64"]="enhanced_security_app"
    ["linux-armhf"]="enhanced_security_app"
    ["windows-x64"]="enhanced_security_app"
    ["windows-x86"]="enhanced_security_app"
    ["macos-x64"]="enhanced_security_app"
    ["macos-arm64"]="enhanced_security_app"
    ["android-arm64"]="mobile_security_app"
    ["android-armv7"]="mobile_security_app"
    ["ios-arm64"]="mobile_security_app"
    ["custom-mobile-os"]="custom_mobile_app"
    ["freebsd-x64"]="enhanced_security_app"
    ["openbsd-x64"]="enhanced_security_app"
    ["netbsd-x64"]="enhanced_security_app"
)

# Compiler preferences by platform
declare -A COMPILERS=(
    ["linux-x64"]="ldc2"
    ["linux-arm64"]="ldc2"
    ["linux-armhf"]="ldc2"
    ["windows-x64"]="ldc2"
    ["windows-x86"]="dmd"
    ["macos-x64"]="ldc2"
    ["macos-arm64"]="ldc2"
    ["android-arm64"]="ldc2"
    ["android-armv7"]="ldc2"
    ["ios-arm64"]="ldc2"
    ["custom-mobile-os"]="ldc2"
    ["freebsd-x64"]="ldc2"
    ["openbsd-x64"]="ldc2"
    ["netbsd-x64"]="ldc2"
)

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

show_help() {
    echo -e "${CYAN}Multi-Platform Build System for Dowel-Steek Security Suite${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [TARGET] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build         Build for specific target"
    echo "  build-all     Build for all supported targets"
    echo "  clean         Clean build artifacts"
    echo "  list          List all supported targets"
    echo "  setup         Setup build environment for target"
    echo "  package       Create distribution packages"
    echo "  test          Run tests on target"
    echo "  deploy        Deploy to device/emulator"
    echo "  help          Show this help message"
    echo ""
    echo "Targets:"
    echo "  linux-x64     Linux 64-bit (Intel/AMD)"
    echo "  linux-arm64   Linux ARM64 (Raspberry Pi 4, Apple Silicon)"
    echo "  linux-armhf   Linux ARM (Raspberry Pi 3 and older)"
    echo "  windows-x64   Windows 64-bit"
    echo "  windows-x86   Windows 32-bit"
    echo "  macos-x64     macOS Intel"
    echo "  macos-arm64   macOS Apple Silicon"
    echo "  android-arm64 Android ARM64"
    echo "  android-armv7 Android ARMv7"
    echo "  ios-arm64     iOS ARM64"
    echo "  custom-mobile-os  Custom Mobile OS"
    echo "  freebsd-x64   FreeBSD 64-bit"
    echo "  openbsd-x64   OpenBSD 64-bit"
    echo "  netbsd-x64    NetBSD 64-bit"
    echo ""
    echo "Options:"
    echo "  --release     Build optimized release version"
    echo "  --debug       Build debug version with symbols"
    echo "  --profile     Build with profiling enabled"
    echo "  --static      Build statically linked binary"
    echo "  --cross       Enable cross-compilation mode"
    echo "  --verbose     Verbose output"
    echo "  --clean       Clean before build"
    echo ""
    echo "Examples:"
    echo "  $0 build linux-x64 --release"
    echo "  $0 build-all --release"
    echo "  $0 setup android-arm64"
    echo "  $0 package linux-x64"
    echo "  $0 deploy custom-mobile-os"
}

list_targets() {
    print_header "Supported Build Targets"

    echo -e "${CYAN}Desktop Platforms:${NC}"
    echo "  linux-x64      - Linux 64-bit (Intel/AMD)"
    echo "  linux-arm64    - Linux ARM64 (Raspberry Pi 4+, Apple Silicon)"
    echo "  linux-armhf    - Linux ARM (Raspberry Pi 3 and older)"
    echo "  windows-x64    - Windows 64-bit"
    echo "  windows-x86    - Windows 32-bit"
    echo "  macos-x64      - macOS Intel"
    echo "  macos-arm64    - macOS Apple Silicon"
    echo ""

    echo -e "${CYAN}Mobile Platforms:${NC}"
    echo "  android-arm64  - Android ARM64 (64-bit devices)"
    echo "  android-armv7  - Android ARMv7 (32-bit devices)"
    echo "  ios-arm64      - iOS ARM64 (iPhone/iPad)"
    echo "  custom-mobile-os - Custom Mobile OS (Dowel-Steek OS)"
    echo ""

    echo -e "${CYAN}Unix-like Systems:${NC}"
    echo "  freebsd-x64    - FreeBSD 64-bit"
    echo "  openbsd-x64    - OpenBSD 64-bit"
    echo "  netbsd-x64     - NetBSD 64-bit"
    echo ""

    echo -e "${CYAN}Build Status:${NC}"
    for target in "${!PLATFORMS[@]}"; do
        if check_target_support "$target"; then
            echo -e "  ${GREEN}✓${NC} $target"
        else
            echo -e "  ${RED}✗${NC} $target (missing dependencies)"
        fi
    done
}

check_dependencies() {
    local target="$1"
    local missing=()

    print_info "Checking dependencies for $target..."

    # Check D compiler
    local compiler="${COMPILERS[$target]}"
    if ! command -v "$compiler" >/dev/null 2>&1; then
        if ! command -v dmd >/dev/null 2>&1; then
            missing+=("D compiler ($compiler or dmd)")
        fi
    fi

    # Check dub
    if ! command -v dub >/dev/null 2>&1; then
        missing+=("dub (D package manager)")
    fi

    # Target-specific dependencies
    case "$target" in
        linux-*)
            if ! pkg-config --exists sdl2 2>/dev/null; then
                missing+=("SDL2 development libraries")
            fi
            ;;
        windows-*)
            print_info "Windows builds require SDL2 libraries in PATH or lib directory"
            ;;
        macos-*)
            if ! command -v brew >/dev/null 2>&1; then
                print_warning "Homebrew recommended for dependency management on macOS"
            fi
            ;;
        android-*)
            if [ -z "$ANDROID_NDK_ROOT" ]; then
                missing+=("Android NDK (set ANDROID_NDK_ROOT)")
            fi
            if [ -z "$ANDROID_SDK_ROOT" ]; then
                missing+=("Android SDK (set ANDROID_SDK_ROOT)")
            fi
            ;;
        ios-*)
            if [ "$(uname)" != "Darwin" ]; then
                missing+=("macOS (required for iOS builds)")
            fi
            if ! command -v xcrun >/dev/null 2>&1; then
                missing+=("Xcode command line tools")
            fi
            ;;
        custom-mobile-os)
            if [ -z "$CUSTOM_MOBILE_TOOLCHAIN" ]; then
                missing+=("Custom mobile OS toolchain (set CUSTOM_MOBILE_TOOLCHAIN)")
            fi
            ;;
    esac

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing dependencies for $target:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi

    return 0
}

check_target_support() {
    local target="$1"

    # Check if target is defined
    if [[ ! ${PLATFORMS[$target]+_} ]]; then
        return 1
    fi

    # Check basic dependencies silently
    local compiler="${COMPILERS[$target]}"
    if ! command -v "$compiler" >/dev/null 2>&1; then
        if ! command -v dmd >/dev/null 2>&1; then
            return 1
        fi
    fi

    return 0
}

setup_target() {
    local target="$1"

    print_header "Setting up build environment for $target"

    case "$target" in
        linux-*)
            print_info "Installing Linux dependencies..."
            if command -v apt >/dev/null 2>&1; then
                sudo apt update
                sudo apt install -y build-essential libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libssl-dev
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y gcc-c++ SDL2-devel SDL2_image-devel SDL2_ttf-devel openssl-devel
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --needed base-devel sdl2 sdl2_image sdl2_ttf openssl
            fi
            ;;

        windows-*)
            print_info "Windows setup requires manual SDL2 library installation"
            print_info "Download SDL2 development libraries from https://www.libsdl.org/"
            print_info "Extract to lib/ directory or ensure libraries are in PATH"
            ;;

        macos-*)
            print_info "Installing macOS dependencies..."
            if command -v brew >/dev/null 2>&1; then
                brew install sdl2 sdl2_image sdl2_ttf openssl
            else
                print_error "Homebrew not found. Please install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                return 1
            fi
            ;;

        android-*)
            setup_android_environment "$target"
            ;;

        ios-*)
            setup_ios_environment "$target"
            ;;

        custom-mobile-os)
            setup_custom_mobile_environment
            ;;
    esac

    print_success "Environment setup completed for $target"
}

setup_android_environment() {
    local target="$1"

    print_info "Setting up Android build environment..."

    # Check for Android SDK/NDK
    if [ -z "$ANDROID_SDK_ROOT" ]; then
        print_error "ANDROID_SDK_ROOT not set"
        print_info "Please install Android SDK and set ANDROID_SDK_ROOT environment variable"
        return 1
    fi

    if [ -z "$ANDROID_NDK_ROOT" ]; then
        print_error "ANDROID_NDK_ROOT not set"
        print_info "Please install Android NDK and set ANDROID_NDK_ROOT environment variable"
        return 1
    fi

    # Setup cross-compilation toolchain
    export CC="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
    export CXX="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"

    case "$target" in
        android-arm64)
            export CC="$CC --target=aarch64-linux-android21"
            export CXX="$CXX --target=aarch64-linux-android21"
            ;;
        android-armv7)
            export CC="$CC --target=armv7a-linux-androideabi21"
            export CXX="$CXX --target=armv7a-linux-androideabi21"
            ;;
    esac

    print_success "Android environment configured"
}

setup_ios_environment() {
    local target="$1"

    print_info "Setting up iOS build environment..."

    if [ "$(uname)" != "Darwin" ]; then
        print_error "iOS builds require macOS"
        return 1
    fi

    # Check Xcode
    if ! command -v xcrun >/dev/null 2>&1; then
        print_error "Xcode command line tools not found"
        print_info "Install with: xcode-select --install"
        return 1
    fi

    # Setup iOS SDK paths
    export IOS_SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
    export IOS_SIMULATOR_SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"

    print_success "iOS environment configured"
}

setup_custom_mobile_environment() {
    print_info "Setting up custom mobile OS build environment..."

    if [ -z "$CUSTOM_MOBILE_TOOLCHAIN" ]; then
        print_error "CUSTOM_MOBILE_TOOLCHAIN not set"
        print_info "Please set CUSTOM_MOBILE_TOOLCHAIN to the path of your custom toolchain"
        return 1
    fi

    if [ ! -d "$CUSTOM_MOBILE_TOOLCHAIN" ]; then
        print_error "Custom mobile toolchain not found: $CUSTOM_MOBILE_TOOLCHAIN"
        return 1
    fi

    export PATH="$CUSTOM_MOBILE_TOOLCHAIN/bin:$PATH"
    export CC="$CUSTOM_MOBILE_TOOLCHAIN/bin/dowel-gcc"
    export CXX="$CUSTOM_MOBILE_TOOLCHAIN/bin/dowel-g++"

    print_success "Custom mobile OS environment configured"
}

build_target() {
    local target="$1"
    local build_type="${2:-debug}"
    local options="$3"

    print_header "Building $PROJECT_NAME for $target ($build_type)"

    if ! check_target_support "$target"; then
        print_error "Target $target is not supported or missing dependencies"
        return 1
    fi

    # Check dependencies
    if ! check_dependencies "$target"; then
        print_error "Dependencies check failed for $target"
        return 1
    fi

    # Create build directories
    local target_build_dir="$BUILD_DIR/$target"
    mkdir -p "$target_build_dir"

    # Get configuration
    local config="${TARGET_CONFIGS[$target]}"
    local compiler="${COMPILERS[$target]}"
    local platform_flags="${PLATFORMS[$target]}"

    # Build flags
    local dub_flags="--config=$config"

    if [[ "$options" == *"--static"* ]]; then
        dub_flags="$dub_flags --build-mode=singleFile"
    fi

    case "$build_type" in
        "release")
            dub_flags="$dub_flags --build=release-nobounds --compiler=$compiler"
            ;;
        "debug")
            dub_flags="$dub_flags --build=debug --compiler=$compiler"
            ;;
        "profile")
            dub_flags="$dub_flags --build=profile --compiler=$compiler"
            ;;
    esac

    # Add platform-specific flags
    if [[ "$platform_flags" != "" ]]; then
        dub_flags="$dub_flags $platform_flags"
    fi

    # Cross-compilation setup
    if [[ "$options" == *"--cross"* ]] || [[ "$target" != "$(detect_host_platform)" ]]; then
        setup_cross_compilation "$target"
    fi

    print_info "Build command: dub build $dub_flags"

    # Build
    if [[ "$options" == *"--verbose"* ]]; then
        dub build $dub_flags --verbose
    else
        dub build $dub_flags
    fi

    # Move binary to target directory
    local binary_name="$PROJECT_NAME"
    case "$target" in
        windows-*)
            binary_name="$binary_name.exe"
            ;;
        android-*)
            binary_name="lib$binary_name.so"
            ;;
        ios-*)
            binary_name="$binary_name.app"
            ;;
    esac

    if [ -f "$binary_name" ]; then
        mv "$binary_name" "$target_build_dir/"

        local binary_size=$(stat -c%s "$target_build_dir/$binary_name" 2>/dev/null || stat -f%z "$target_build_dir/$binary_name" 2>/dev/null || echo "unknown")
        if [ "$binary_size" != "unknown" ]; then
            binary_size=$(echo "$binary_size" | awk '{printf "%.1f MB", $1/1024/1024}')
        fi

        print_success "Build completed: $target_build_dir/$binary_name ($binary_size)"

        # Post-build processing
        post_process_binary "$target" "$target_build_dir/$binary_name" "$options"
    else
        print_error "Binary not found after build"
        return 1
    fi

    return 0
}

setup_cross_compilation() {
    local target="$1"

    print_info "Setting up cross-compilation for $target..."

    case "$target" in
        linux-arm64|linux-armhf)
            if command -v apt >/dev/null 2>&1; then
                sudo apt install -y gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf
            fi
            ;;
        windows-*)
            if command -v apt >/dev/null 2>&1; then
                sudo apt install -y mingw-w64
            fi
            ;;
    esac
}

post_process_binary() {
    local target="$1"
    local binary_path="$2"
    local options="$3"

    case "$target" in
        linux-*)
            # Strip binary if release build
            if [[ "$options" == *"--release"* ]]; then
                strip "$binary_path" 2>/dev/null || true
            fi
            ;;
        windows-*)
            # Could add signing here
            ;;
        android-*)
            # Package as APK
            package_android_apk "$target" "$binary_path"
            ;;
        ios-*)
            # Code signing would go here
            ;;
        custom-mobile-os)
            # Custom packaging
            package_custom_mobile "$binary_path"
            ;;
    esac
}

package_android_apk() {
    local target="$1"
    local binary_path="$2"

    print_info "Packaging Android APK for $target..."

    # This would create a proper APK with Android manifest, resources, etc.
    local apk_dir="$BUILD_DIR/android-package"
    mkdir -p "$apk_dir"

    # Copy binary to APK structure
    mkdir -p "$apk_dir/lib/arm64-v8a" "$apk_dir/lib/armeabi-v7a"

    case "$target" in
        android-arm64)
            cp "$binary_path" "$apk_dir/lib/arm64-v8a/"
            ;;
        android-armv7)
            cp "$binary_path" "$apk_dir/lib/armeabi-v7a/"
            ;;
    esac

    print_success "Android package prepared in $apk_dir"
}

package_custom_mobile() {
    local binary_path="$1"

    print_info "Packaging for custom mobile OS..."

    local package_dir="$BUILD_DIR/custom-mobile-package"
    mkdir -p "$package_dir"

    # Copy binary
    cp "$binary_path" "$package_dir/"

    # Create custom mobile OS package manifest
    cat > "$package_dir/manifest.json" << EOF
{
    "name": "Dowel-Steek Security Suite",
    "version": "$VERSION",
    "type": "security-app",
    "permissions": [
        "keyring.read",
        "keyring.write",
        "biometric.authenticate",
        "network.restricted"
    ],
    "capabilities": [
        "password-manager",
        "totp-generator",
        "secure-storage"
    ],
    "binary": "$(basename "$binary_path")",
    "icon": "icon.png",
    "category": "Security"
}
EOF

    print_success "Custom mobile OS package prepared in $package_dir"
}

build_all_targets() {
    local build_type="${1:-debug}"
    local options="$2"

    print_header "Building all supported targets ($build_type)"

    local success_count=0
    local total_count=0
    local failed_targets=()

    for target in "${!PLATFORMS[@]}"; do
        if check_target_support "$target"; then
            total_count=$((total_count + 1))

            print_info "Building target: $target"

            if build_target "$target" "$build_type" "$options"; then
                success_count=$((success_count + 1))
                print_success "✓ $target"
            else
                failed_targets+=("$target")
                print_error "✗ $target"
            fi

            echo ""
        fi
    done

    print_header "Build Summary"
    print_success "Successfully built: $success_count/$total_count targets"

    if [ ${#failed_targets[@]} -gt 0 ]; then
        print_error "Failed targets:"
        for target in "${failed_targets[@]}"; do
            echo "  - $target"
        done
    fi

    return $([ $success_count -eq $total_count ])
}

clean_build() {
    local target="$1"

    print_header "Cleaning build artifacts"

    if [ -n "$target" ]; then
        print_info "Cleaning target: $target"
        rm -rf "$BUILD_DIR/$target"
        print_success "Cleaned $target"
    else
        print_info "Cleaning all build artifacts..."
        rm -rf "$BUILD_DIR"
        rm -rf "$DIST_DIR"
        rm -f *.exe *.so *.app
        dub clean >/dev/null 2>&1 || true
        print_success "All build artifacts cleaned"
    fi
}

create_packages() {
    local target="$1"
    local build_type="${2:-release}"

    print_header "Creating distribution packages"

    if [ -n "$target" ]; then
        create_package_for_target "$target" "$build_type"
    else
        print_info "Creating packages for all built targets..."

        for target in "${!PLATFORMS[@]}"; do
            local target_build_dir="$BUILD_DIR/$target"
            if [ -d "$target_build_dir" ]; then
                create_package_for_target "$target" "$build_type"
            fi
        done
    fi
}

create_package_for_target() {
    local target="$1"
    local build_type="$2"

    print_info "Creating package for $target..."

    local target_build_dir="$BUILD_DIR/$target"
    local package_dir="$DIST_DIR/$target"

    mkdir -p "$package_dir"

    # Copy binary
    cp -r "$target_build_dir"/* "$package_dir/"

    # Copy documentation
    cp ENHANCED_SECURITY_README.md "$package_dir/" 2>/dev/null || true
    cp ENHANCED_SECURITY_IMPLEMENTATION.md "$package_dir/" 2>/dev/null || true

    # Create install script
    case "$target" in
        linux-*|freebsd-*|openbsd-*|netbsd-*)
            create_unix_install_script "$package_dir" "$target"
            ;;
        windows-*)
            create_windows_install_script "$package_dir" "$target"
            ;;
        macos-*)
            create_macos_install_script "$package_dir" "$target"
            ;;
        android-*)
            # APK already created
            ;;
        ios-*)
            # iOS package already created
            ;;
        custom-mobile-os)
            # Custom package already created
            ;;
    esac

    # Create archive
    cd "$DIST_DIR"
    case "$target" in
        windows-*)
            zip -r "$target-$VERSION.zip" "$target"
            ;;
        *)
            tar -czf "$target-$VERSION.tar.gz" "$target"
            ;;
    esac
    cd - >/dev/null

    print_success "Package created: $DIST_DIR/$target-$VERSION.*"
}

create_unix_install_script() {
    local package_dir="$1"
    local target="$2"

    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="dowel-steek-security"

echo "Installing Dowel-Steek Security Suite..."

# Check for sudo
if [ "$EUID" -ne 0 ]; then
    echo "Installing to $INSTALL_DIR (requires sudo)..."
    sudo cp "$BINARY_NAME" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
else
    cp "$BINARY_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
fi

# Create desktop entry
DESKTOP_FILE="/usr/share/applications/dowel-steek-security.desktop"
cat > /tmp/dowel-steek-security.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Name=Dowel-Steek Security Suite
Comment=Password Manager and TOTP Authenticator
Exec=dowel-steek-security
Icon=security
Terminal=false
Type=Application
Categories=Utility;Security;
Keywords=password;security;2fa;totp;vault;
DESKTOP_EOF

if [ "$EUID" -ne 0 ]; then
    sudo mv /tmp/dowel-steek-security.desktop "$DESKTOP_FILE"
    sudo chmod 644 "$DESKTOP_FILE"
else
    mv /tmp/dowel-steek-security.desktop "$DESKTOP_FILE"
    chmod 644 "$DESKTOP_FILE"
fi

echo "Installation completed successfully!"
echo "You can now run: $BINARY_NAME"
echo "Or find it in your applications menu."
EOF

    chmod +x "$package_dir/install.sh"
}

create_windows_install_script() {
    local package_dir="$1"
    local target="$2"

    cat > "$package_dir/install.bat" << 'EOF'
@echo off
setlocal

set INSTALL_DIR=%ProgramFiles%\Dowel-Steek Security Suite
set BINARY_NAME=dowel-steek-security.exe

echo Installing Dowel-Steek Security Suite...

REM Create installation directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Copy binary
copy "%BINARY_NAME%" "%INSTALL_DIR%\"

REM Add to PATH (optional)
echo.
echo Installation completed successfully!
echo Binary installed to: %INSTALL_DIR%\%BINARY_NAME%
echo.
echo You can run it from: "%INSTALL_DIR%\%BINARY_NAME%"
pause
EOF
}

create_macos_install_script() {
    local package_dir="$1"
    local target="$2"

    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
set -e

INSTALL_DIR="/usr/local/bin"
APP_DIR="/Applications"
BINARY_NAME="dowel-steek-security"

echo "Installing Dowel-Steek Security Suite for macOS..."

# Install binary
sudo cp "$BINARY_NAME" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Installation completed successfully!"
echo "You can now run: $BINARY_NAME"
EOF

    chmod +x "$package_dir/install.sh"
}

detect_host_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$arch" in
        x86_64|amd64)
            arch="x64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l|armhf)
            arch="armhf"
            ;;
        i386|i686)
            arch="x86"
            ;;
    esac

    echo "$os-$arch"
}

test_target() {
    local target="$1"

    print_header "Testing $target"

    local target_
