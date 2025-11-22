# Dowel-Steek Mobile - Architecture Overview

## Vision: iPhone/Android Competitor OS

Transform the Dowel-Steek desktop environment into a modern mobile operating system using Zig for performance-critical components and Kotlin Multiplatform for UI and application logic.

## Technology Stack

### Core System (Zig)
- **Performance**: Low-level system operations, memory management
- **Portability**: Cross-platform compilation for ARM64, x86_64
- **Safety**: Memory-safe alternatives to C/C++ components
- **Efficiency**: Zero-cost abstractions, compile-time optimizations

### Application Layer (Kotlin Multiplatform)
- **Cross-platform**: Single codebase for iOS and Android
- **Modern UI**: Compose Multiplatform for native performance
- **Integration**: Seamless interop with Zig core via C ABI
- **Ecosystem**: Access to vast Kotlin/Java libraries

## Architecture Layers

```
┌─────────────────────────────────────────┐
│           Applications                  │
│  Notes • ChatGPT • Files • Terminal     │
├─────────────────────────────────────────┤
│         Kotlin Multiplatform           │
│    UI Framework • App Logic            │
├─────────────────────────────────────────┤
│           Native Bridge                 │
│      C ABI • JNI/FFI Bindings          │
├─────────────────────────────────────────┤
│            Zig Core                     │
│   System • Storage • Network           │
├─────────────────────────────────────────┤
│        Platform Layer                   │
│     iOS/Android Native APIs            │
└─────────────────────────────────────────┘
```

## Core Components Migration

### 1. System Core (Zig → `zig-core/`)

**From D Desktop Components:**
- `core/config.d` → `config.zig` - Configuration management
- `core/session.d` → `session.zig` - App lifecycle management
- `utils/logger.d` → `logging.zig` - Structured logging system
- File system operations → `storage.zig` - Mobile-appropriate file handling

**New Mobile-Specific:**
- `power.zig` - Battery management and power optimization
- `sensors.zig` - Accelerometer, gyroscope, proximity sensors
- `notifications.zig` - Push notification handling
- `security.zig` - Biometric authentication, keychain access

### 2. Application Framework (Kotlin → `kotlin-multiplatform/`)

**Core Applications:**
- `Notes App` - Rich markdown editor with mobile gestures
- `ChatGPT Viewer` - Conversation management with touch optimization
- `File Manager` - Mobile-friendly file operations with cloud sync
- `Terminal` - Touch-optimized terminal with gesture support
- `Settings` - Modern mobile settings with search and organization

**UI Components:**
- `compose-ui/` - Shared Compose Multiplatform components
- `navigation/` - Mobile navigation patterns (tabs, stack, drawer)
- `theming/` - Adaptive themes for light/dark modes
- `gestures/` - Touch gesture recognition and handling

### 3. Platform Integration

**iOS Integration:**
- SwiftUI interop for native iOS components
- Core Data integration for local storage
- HomeKit/HealthKit integrations
- Siri Shortcuts support

**Android Integration:**
- Jetpack Compose integration
- Android Jetpack libraries
- Material Design 3 components
- Android system integrations (widgets, shortcuts)

## Development Phases

### Phase 1: Foundation (Zig Core)
- [x] Project structure setup
- [ ] Basic Zig core modules (config, logging, storage)
- [ ] C ABI definitions for Kotlin interop
- [ ] Cross-compilation setup for mobile targets
- [ ] Basic memory management and allocation strategies

### Phase 2: Native Bridge
- [ ] JNI bindings for Android (Kotlin ↔ Zig)
- [ ] C interop for iOS (Swift ↔ Zig)
- [ ] Type-safe serialization between layers
- [ ] Error handling across language boundaries
- [ ] Performance profiling and optimization

### Phase 3: Kotlin Multiplatform Framework
- [ ] Shared business logic modules
- [ ] Compose Multiplatform UI foundation
- [ ] Navigation architecture
- [ ] State management (ViewModel pattern)
- [ ] Local database abstraction (SQLDelight)

### Phase 4: Core Applications
- [ ] Notes app with markdown support
- [ ] File manager with cloud integration
- [ ] ChatGPT conversation viewer
- [ ] Settings and configuration UI
- [ ] Terminal emulator with touch support

### Phase 5: Mobile OS Features
- [ ] Home screen launcher
- [ ] Notification management
- [ ] Quick settings panel
- [ ] App switching/multitasking
- [ ] Lock screen and security

### Phase 6: Advanced Features
- [ ] Voice assistant integration
- [ ] AR/camera features
- [ ] Health and fitness tracking
- [ ] AI-powered suggestions
- [ ] Cloud sync and backup

## Key Design Principles

### 1. Performance First
- Zig handles all performance-critical operations
- Zero-copy data transfer between layers where possible
- Efficient memory pooling and recycling
- Background processing for heavy operations

### 2. Mobile-Native UX
- Touch-first interface design
- Gesture-based navigation
- Adaptive layouts for different screen sizes
- Dark mode and accessibility support

### 3. Privacy & Security
- Local-first data storage
- End-to-end encryption for sync
- Biometric authentication
- Minimal data collection

### 4. Developer Experience
- Hot reload for rapid development
- Comprehensive testing framework
- Clear separation of concerns
- Excellent debugging tools

## Build System

### Zig Build (`build.zig`)
```zig
// Cross-compilation for mobile targets
// Static library generation for native integration
// Automated testing and benchmarking
```

### Kotlin Multiplatform (`build.gradle.kts`)
```kotlin
// Shared modules compilation
// Platform-specific implementations
// Resource bundling and optimization
```

### Platform Projects
- `ios/` - Xcode project with Swift wrapper
- `android/` - Android Studio project with Kotlin/Java

## File Structure

```
mobile-rewrite/
├── zig-core/                   # Zig system components
│   ├── src/
│   │   ├── config.zig         # Configuration management
│   │   ├── storage.zig        # File and data storage
│   │   ├── logging.zig        # Structured logging
│   │   ├── networking.zig     # Network operations
│   │   ├── crypto.zig         # Cryptographic operations
│   │   └── mobile/            # Mobile-specific modules
│   │       ├── sensors.zig    # Device sensors
│   │       ├── power.zig      # Power management
│   │       └── notifications.zig
│   ├── build.zig             # Build configuration
│   ├── c_headers/             # C header files for interop
│   └── tests/                 # Unit and integration tests
│
├── kotlin-multiplatform/      # Kotlin shared code
│   ├── shared/
│   │   ├── src/
│   │   │   ├── commonMain/kotlin/
│   │   │   │   ├── core/       # Core business logic
│   │   │   │   ├── ui/         # Shared UI components
│   │   │   │   ├── data/       # Data models and repositories
│   │   │   │   └── bridge/     # Native bridge interfaces
│   │   │   ├── androidMain/kotlin/
│   │   │   └── iosMain/kotlin/
│   │   └── build.gradle.kts
│   ├── apps/                  # Individual applications
│   │   ├── notes/
│   │   ├── files/
│   │   ├── chatgpt/
│   │   └── terminal/
│   └── compose-ui/            # Shared Compose components
│
├── ios/                       # iOS-specific project
│   ├── DowelSteek.xcodeproj
│   ├── Sources/
│   │   ├── Swift/             # Swift wrapper code
│   │   └── C/                 # C bridge implementation
│   └── Resources/
│
├── android/                   # Android-specific project
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── java/kotlin/   # Android-specific code
│   │   │   └── cpp/           # JNI bridge implementation
│   │   └── build.gradle.kts
│   └── gradle/
│
├── docs/                      # Documentation
│   ├── API.md                 # API documentation
│   ├── BUILD.md               # Build instructions
│   └── CONTRIBUTING.md        # Development guidelines
│
└── tools/                     # Development tools
    ├── codegen/               # Code generation scripts
    ├── testing/               # Testing utilities
    └── deployment/            # Deployment scripts
```

## Migration Strategy

### 1. Incremental Migration
- Start with core Zig modules (config, logging, storage)
- Build basic Kotlin multiplatform structure
- Implement one application at a time
- Maintain parallel development with desktop version

### 2. Feature Parity
- Identify essential features from desktop version
- Adapt UI patterns for mobile interaction
- Enhance with mobile-specific capabilities
- Ensure cross-platform consistency

### 3. Testing Strategy
- Unit tests for Zig components
- UI tests for Kotlin components
- Integration tests for cross-language communication
- Performance benchmarking throughout development

### 4. Deployment Pipeline
- Automated builds for both platforms
- Continuous integration testing
- Beta testing program
- Gradual rollout strategy

## Next Steps

1. **Initialize Zig core project** with basic modules
2. **Set up Kotlin Multiplatform** structure
3. **Implement native bridge** for communication
4. **Port configuration system** as proof of concept
5. **Build first mobile application** (Notes app)

This architecture provides a solid foundation for transforming Dowel-Steek into a competitive mobile operating system while leveraging the strengths of both Zig and Kotlin Multiplatform.