#!/bin/bash

# Dowel Mobile OS - Quick Demo Script
# This script builds and runs your custom mobile OS demo

set -e

echo "🚀 Dowel Mobile OS Demo Launcher"
echo "=================================="

# Check if we're in the right directory
if [[ ! -f "mobile-rewrite/simple-demo.zig" ]] && [[ ! -d "dowel-mobile-ux" ]]; then
    echo "❌ Please run this script from the Dowel-Steek root directory"
    exit 1
fi

# Function to check if Android emulator is running
check_emulator() {
    if adb devices | grep -q "emulator.*device"; then
        echo "✅ Android emulator is running"
        return 0
    else
        echo "⚠️  No Android emulator detected"
        return 1
    fi
}

# Function to start emulator
start_emulator() {
    echo "🔧 Starting Android emulator..."
    if [[ -f "$HOME/.local/android-sdk/emulator/emulator" ]]; then
        $HOME/.local/android-sdk/emulator/emulator -avd DowelOS_Demo -no-snapshot &
        echo "⏳ Waiting for emulator to boot (this may take 30-60 seconds)..."

        # Wait for emulator to be ready
        timeout=60
        while [[ $timeout -gt 0 ]]; do
            if adb devices | grep -q "emulator.*device"; then
                echo "✅ Emulator is ready!"
                return 0
            fi
            sleep 2
            timeout=$((timeout - 2))
        done

        echo "❌ Emulator failed to start within 60 seconds"
        return 1
    else
        echo "❌ Android emulator not found. Please install Android SDK first."
        return 1
    fi
}

# Main demo selection
echo
echo "Select demo to run:"
echo "1) 📱 Android Mobile OS Demo (full UI)"
echo "2) 💻 Zig Terminal Demo (concept)"
echo "3) 🔧 Build Android APK only"
echo "4) 🎯 Install existing APK to device"
echo

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "🚀 Running Android Mobile OS Demo..."
        echo

        # Check if emulator is running, start if needed
        if ! check_emulator; then
            if ! start_emulator; then
                echo "❌ Failed to start emulator. Please start it manually and try again."
                exit 1
            fi
            sleep 5  # Extra wait after starting
        fi

        echo "📦 Building and installing Dowel Mobile OS..."
        cd dowel-mobile-ux

        # Build and install
        if ./gradlew :androidApp:installDebug; then
            echo "✅ Build and install successful!"
            echo
            echo "🚀 Launching Dowel Mobile OS..."
            adb shell am start -n com.dowelsteek.mobile.android/.MainActivity
            echo
            echo "🎉 Your Dowel Mobile OS is now running!"
            echo "📱 Check the emulator window to see your custom mobile OS interface"
            echo "💡 Features available:"
            echo "   • Beautiful launcher with app grid"
            echo "   • Animated search bar"
            echo "   • Custom widgets and status bar"
            echo "   • 12 demo apps (Files, Settings, ChatGPT, etc.)"
            echo "   • Smooth animations and transitions"
        else
            echo "❌ Build failed. Check the error messages above."
            exit 1
        fi
        ;;

    2)
        echo "💻 Running Zig Terminal Demo..."
        echo
        cd mobile-rewrite
        echo "🔧 Compiling with Zig 0.15..."
        if zig run simple-demo.zig; then
            echo "✅ Demo completed!"
        else
            echo "❌ Demo failed. Check Zig installation."
        fi
        ;;

    3)
        echo "📦 Building Android APK..."
        cd dowel-mobile-ux
        if ./gradlew :androidApp:assembleDebug; then
            echo "✅ APK built successfully!"
            echo "📱 Location: androidApp/build/outputs/apk/debug/androidApp-debug.apk"
        else
            echo "❌ Build failed."
            exit 1
        fi
        ;;

    4)
        echo "🎯 Installing existing APK..."
        if check_emulator || adb devices | grep -q "device"; then
            APK_PATH="dowel-mobile-ux/androidApp/build/outputs/apk/debug/androidApp-debug.apk"
            if [[ -f "$APK_PATH" ]]; then
                adb install -r "$APK_PATH"
                adb shell am start -n com.dowelsteek.mobile.android/.MainActivity
                echo "✅ Installed and launched!"
            else
                echo "❌ APK not found. Run option 3 first to build it."
                exit 1
            fi
        else
            echo "❌ No Android device or emulator connected."
            exit 1
        fi
        ;;

    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo
echo "🎯 Next Steps:"
echo "• Test all the apps in your mobile OS interface"
echo "• Customize the UI in dowel-mobile-ux/shared/src/commonMain/kotlin/App.kt"
echo "• Add more apps and features"
echo "• For custom OS development, work on fixing Zig errors in mobile-rewrite/"
echo
echo "📚 Project Status:"
echo "• ✅ Android Demo: Fully functional mobile OS interface"
echo "• ✅ Zig Demo: Working concept demonstration"
echo "• ⚠️  Zig Core: 15 compilation errors need fixing for mobile targets"
echo
echo "Happy coding! 🚀"
