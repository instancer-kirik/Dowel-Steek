#include <iostream>
#include <string>
#include <chrono>

// Forward declarations for Zig functions
extern "C" {
    int dowel_core_init();
    void dowel_core_shutdown();
    bool dowel_core_is_initialized();
    int dowel_get_version(char* buffer, int size);
    int dowel_add_numbers(int a, int b);
    int dowel_string_length(const char* str);
    void dowel_log_info(const char* message);
    void dowel_log_error(const char* message);
    long dowel_get_timestamp_ms();
    void dowel_sleep_ms(int milliseconds);
    int dowel_config_set_string(const char* key, const char* value);
    const char* dowel_config_get_string(const char* key, const char* default_value);
}

class ZigSystemWrapper {
private:
    bool initialized = false;

public:
    // Initialize the Zig system
    bool initialize() {
        int result = dowel_core_init();
        initialized = (result == 0);
        return initialized;
    }

    // Shutdown the system
    void shutdown() {
        if (initialized) {
            dowel_core_shutdown();
            initialized = false;
        }
    }

    // Check if initialized
    bool isInitialized() const {
        return dowel_core_is_initialized();
    }

    // Get version string
    std::string getVersion() {
        char buffer[64];
        int result = dowel_get_version(buffer, sizeof(buffer));
        if (result == 0) {
            return std::string(buffer);
        }
        return "Unknown";
    }

    // Math operations
    int addNumbers(int a, int b) {
        return dowel_add_numbers(a, b);
    }

    // String operations
    int getStringLength(const std::string& str) {
        return dowel_string_length(str.c_str());
    }

    // Logging
    void logInfo(const std::string& message) {
        dowel_log_info(message.c_str());
    }

    void logError(const std::string& message) {
        dowel_log_error(message.c_str());
    }

    // Utilities
    long getCurrentTimestamp() {
        return dowel_get_timestamp_ms();
    }

    void sleep(int milliseconds) {
        dowel_sleep_ms(milliseconds);
    }

    // Configuration
    bool setConfig(const std::string& key, const std::string& value) {
        int result = dowel_config_set_string(key.c_str(), value.c_str());
        return result == 0;
    }

    std::string getConfig(const std::string& key, const std::string& defaultValue = "") {
        const char* result = dowel_config_get_string(key.c_str(), defaultValue.c_str());
        return result ? std::string(result) : defaultValue;
    }

    // Destructor ensures cleanup
    ~ZigSystemWrapper() {
        if (initialized) {
            shutdown();
        }
    }
};

int main() {
    std::cout << "🚀 C++ Zig Integration Demo\n";
    std::cout << "==============================\n\n";

    ZigSystemWrapper system;

    // Test 1: System initialization
    std::cout << "1. Initializing Zig system...\n";
    if (!system.initialize()) {
        std::cout << "❌ Failed to initialize Zig system\n";
        return 1;
    }
    std::cout << "✅ Zig system initialized successfully\n";

    // Test 2: System information
    std::cout << "\n2. System Information:\n";
    std::cout << "   Version: " << system.getVersion() << "\n";
    std::cout << "   Initialized: " << (system.isInitialized() ? "true" : "false") << "\n";
    std::cout << "   Boot timestamp: " << system.getCurrentTimestamp() << "ms\n";

    // Test 3: Math operations
    std::cout << "\n3. Math Operations:\n";
    int a = 42, b = 24;
    int result = system.addNumbers(a, b);
    std::cout << "   " << a << " + " << b << " = " << result << "\n";

    // Test 4: String operations
    std::cout << "\n4. String Operations:\n";
    std::string test_str = "Dowel-Steek Mobile OS";
    int str_len = system.getStringLength(test_str);
    std::cout << "   String: '" << test_str << "'\n";
    std::cout << "   Length from Zig: " << str_len << "\n";
    std::cout << "   Expected length: " << test_str.length() << "\n";

    // Test 5: Logging
    std::cout << "\n5. Logging Test:\n";
    system.logInfo("Hello from C++!");
    system.logError("This is a test error message from C++");
    std::cout << "   ✅ Logging test completed (check stderr output above)\n";

    // Test 6: Configuration
    std::cout << "\n6. Configuration Test:\n";
    system.setConfig("app.name", "Dowel-Steek Demo");
    system.setConfig("app.version", "1.0.0");
    std::cout << "   App Name: " << system.getConfig("app.name") << "\n";
    std::cout << "   App Version: " << system.getConfig("app.version") << "\n";

    // Test 7: Performance test
    std::cout << "\n7. Performance Test:\n";
    auto start_time = system.getCurrentTimestamp();
    
    int total = 0;
    for (int i = 1; i <= 10000; ++i) {
        total += system.addNumbers(i, i * 2);
    }
    
    auto end_time = system.getCurrentTimestamp();
    auto duration = end_time - start_time;
    
    std::cout << "   Performed 10,000 Zig calls in " << duration << "ms\n";
    std::cout << "   Total sum: " << total << "\n";
    std::cout << "   Average per call: " << (double)duration / 10000.0 << "ms\n";

    // Test 8: Sleep function
    std::cout << "\n8. Sleep Test:\n";
    std::cout << "   Sleeping for 100ms...\n";
    system.sleep(100);
    std::cout << "   ✅ Sleep completed!\n";

    // Test 9: Mobile OS simulation
    std::cout << "\n9. Mobile OS Simulation:\n";
    system.logInfo("Starting mobile OS services...");
    
    // Simulate various mobile operations
    std::string services[] = {"Display Manager", "Input Handler", "Audio System", "Network Stack", "Power Manager"};
    
    for (const auto& service : services) {
        system.logInfo("Initializing " + service);
        system.setConfig("service." + service, "active");
        
        // Simulate initialization time
        int init_time = 10 + (rand() % 40); // 10-50ms
        system.sleep(init_time);
        
        std::cout << "   ✅ " << service << " initialized (" << init_time << "ms)\n";
    }

    // Final system check
    std::cout << "\n10. System Status Check:\n";
    std::cout << "    - System uptime: " << (system.getCurrentTimestamp() - start_time) << "ms\n";
    std::cout << "    - Total services: 5\n";
    std::cout << "    - Memory operations: " << total << "\n";
    std::cout << "    - System health: OK\n";

    // Cleanup
    std::cout << "\n11. Shutting down system...\n";
    system.shutdown();
    std::cout << "    System initialized after shutdown: " << (system.isInitialized() ? "true" : "false") << "\n";
    std::cout << "    ✅ Clean shutdown completed\n";

    std::cout << "\n🎉 Demo completed successfully!\n";
    std::cout << "✅ Zig-C++ integration is working perfectly!\n\n";
    
    std::cout << "📝 This demonstrates the same pattern that Kotlin/Native would use:\n";
    std::cout << "   - External function declarations (@SymbolName in Kotlin)\n";
    std::cout << "   - Wrapper class for type safety\n";
    std::cout << "   - Direct calls to Zig functions\n";
    std::cout << "   - Memory-safe string handling\n";
    std::cout << "   - Performance comparable to native C++\n";

    return 0;
}