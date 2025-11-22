const std = @import("std");
const print = std.debug.print;

// Simple Dowel Mobile OS Demo - Modern Zig 0.15
// This demonstrates the core concepts running on host

const DowelOS = struct {
    allocator: std.mem.Allocator,
    is_running: bool,
    apps: std.ArrayList(App),
    display: Display,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .is_running = false,
            .apps = std.ArrayList(App).init(allocator),
            .display = Display.init(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.apps.deinit();
    }

    pub fn boot(self: *Self) !void {
        print("🚀 Dowel Mobile OS - Booting...\n", .{});
        print("   Kernel: Zig 0.15 Native\n", .{});
        print("   Target: Custom Mobile OS\n", .{});
        print("   Architecture: ARM64 (emulated on host)\n\n", .{});

        // Initialize core services
        try self.initializeServices();

        // Load default apps
        try self.loadDefaultApps();

        // Start display system
        self.display.start();

        self.is_running = true;
        print("✅ Dowel Mobile OS Ready!\n\n", .{});
    }

    pub fn run(self: *Self) !void {
        if (!self.is_running) {
            return error.NotBooted;
        }

        print("📱 Dowel Mobile OS - Home Screen\n", .{});
        print("═════════════════════════════════\n", .{});

        // Display apps grid
        for (self.apps.items, 0..) |app, i| {
            print("  [{d}] {s} - {s}\n", .{ i + 1, app.icon, app.name });
        }

        print("\nEnter app number (1-{d}) or 'q' to quit: ", .{self.apps.items.len});

        // Simple input handling
        var buffer: [10]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buffer[0..], '\n')) |input| {
            const trimmed = std.mem.trim(u8, input, " \n\r\t");

            if (std.mem.eql(u8, trimmed, "q")) {
                try self.shutdown();
                return;
            }

            if (std.fmt.parseInt(usize, trimmed, 10)) |app_num| {
                if (app_num > 0 and app_num <= self.apps.items.len) {
                    try self.launchApp(app_num - 1);
                } else {
                    print("❌ Invalid app number\n\n", .{});
                }
            } else |_| {
                print("❌ Please enter a number or 'q'\n\n", .{});
            }
        }
    }

    fn initializeServices(self: *Self) !void {
        _ = self;
        print("   ⚙️  Initializing core services...\n", .{});
        print("      • Memory Manager: OK\n", .{});
        print("      • Process Scheduler: OK\n", .{});
        print("      • Security Manager: OK\n", .{});
        print("      • Network Stack: OK\n", .{});
        print("      • Power Management: OK\n", .{});
    }

    fn loadDefaultApps(self: *Self) !void {
        print("   📱 Loading default applications...\n", .{});

        const default_apps = [_]App{
            App{ .name = "Settings", .icon = "⚙️", .type = .System },
            App{ .name = "Files", .icon = "📁", .type = .Utility },
            App{ .name = "Terminal", .icon = "💻", .type = .Developer },
            App{ .name = "Browser", .icon = "🌐", .type = .Internet },
            App{ .name = "Notes", .icon = "📝", .type = .Productivity },
            App{ .name = "Camera", .icon = "📷", .type = .Media },
            App{ .name = "Music", .icon = "🎵", .type = .Media },
            App{ .name = "Maps", .icon = "🗺️", .type = .Navigation },
            App{ .name = "Calculator", .icon = "🔢", .type = .Utility },
            App{ .name = "ChatGPT", .icon = "🤖", .type = .AI },
        };

        for (default_apps) |app| {
            try self.apps.append(app);
            print("      • {s}: Loaded\n", .{app.name});
        }
    }

    fn launchApp(self: *Self, index: usize) !void {
        const app = self.apps.items[index];
        print("\n🚀 Launching {s} {s}...\n", .{ app.icon, app.name });
        print("═══════════════════════════════════\n", .{});

        switch (app.type) {
            .System => try self.runSettings(),
            .Utility => try self.runUtility(app.name),
            .Developer => try self.runTerminal(),
            .Internet => try self.runBrowser(),
            .Productivity => try self.runNotes(),
            .Media => try self.runMedia(app.name),
            .Navigation => try self.runMaps(),
            .AI => try self.runChatGPT(),
        }

        print("\n⬅️  Returning to home screen...\n\n", .{});
    }

    fn runSettings(self: *Self) !void {
        _ = self;
        print("⚙️ Dowel OS Settings\n", .{});
        print("  • Display: 1920x1080 @ 60Hz\n", .{});
        print("  • Battery: 85% (6.2V)\n", .{});
        print("  • Storage: 234GB free\n", .{});
        print("  • Memory: 6.1GB available\n", .{});
        print("  • Network: WiFi Connected\n", .{});
        print("  • OS Version: Dowel 1.0.0\n", .{});
        print("  • Kernel: Zig Native ARM64\n", .{});
    }

    fn runUtility(self: *Self, name: []const u8) !void {
        _ = self;
        if (std.mem.eql(u8, name, "Files")) {
            print("📁 Dowel File Manager\n", .{});
            print("  📂 /home/user/\n", .{});
            print("  📂 /documents/\n", .{});
            print("  📂 /downloads/\n", .{});
            print("  📂 /pictures/\n", .{});
            print("  📄 README.md\n", .{});
            print("  📄 mobile-os-notes.txt\n", .{});
        } else if (std.mem.eql(u8, name, "Calculator")) {
            print("🔢 Dowel Calculator\n", .{});
            print("  Result: 42\n", .{});
            print("  [Advanced scientific calculator ready]\n", .{});
        }
    }

    fn runTerminal(self: *Self) !void {
        _ = self;
        print("💻 Dowel Terminal v1.0\n", .{});
        print("user@dowel-mobile:~$ uname -a\n", .{});
        print("Dowel-OS 1.0.0 dowel-mobile aarch64 Zig-Native\n", .{});
        print("user@dowel-mobile:~$ ps aux\n", .{});
        print("  PID  CMD\n", .{});
        print("    1  /kernel/init\n", .{});
        print("   42  /system/window-manager\n", .{});
        print("  123  /apps/terminal\n", .{});
        print("user@dowel-mobile:~$ free -h\n", .{});
        print("Memory: 6.1G available, 1.9G used\n", .{});
    }

    fn runBrowser(self: *Self) !void {
        _ = self;
        print("🌐 Dowel Browser\n", .{});
        print("  📍 https://dowel-os.com\n", .{});
        print("  🏠 Welcome to Dowel Mobile OS!\n", .{});
        print("      The future of mobile computing.\n", .{});
        print("  🔐 Privacy-first, fast, secure.\n", .{});
        print("  📱 Built for mobile, optimized for battery.\n", .{});
    }

    fn runNotes(self: *Self) !void {
        _ = self;
        print("📝 Dowel Notes\n", .{});
        print("  📄 Mobile OS Development Ideas\n", .{});
        print("  📄 Hardware Requirements\n", .{});
        print("  📄 App Architecture Notes\n", .{});
        print("  ➕ [Create new note...]\n", .{});
    }

    fn runMedia(self: *Self, name: []const u8) !void {
        _ = self;
        if (std.mem.eql(u8, name, "Camera")) {
            print("📷 Dowel Camera\n", .{});
            print("  📸 [Viewfinder active]\n", .{});
            print("  🎥 Video mode available\n", .{});
            print("  ⚙️ 12MP, f/1.8, OIS\n", .{});
        } else if (std.mem.eql(u8, name, "Music")) {
            print("🎵 Dowel Music\n", .{});
            print("  ♪ Now Playing: Zig Compilation Success\n", .{});
            print("  🎶 Artist: System Sounds\n", .{});
            print("  ⏯️  [Play] [Pause] [Next]\n", .{});
        }
    }

    fn runMaps(self: *Self) !void {
        _ = self;
        print("🗺️ Dowel Maps\n", .{});
        print("  📍 Current Location: Development Lab\n", .{});
        print("  🧭 Heading: North\n", .{});
        print("  🛰️ GPS: 8 satellites\n", .{});
        print("  🗺️ [Offline maps available]\n", .{});
    }

    fn runChatGPT(self: *Self) !void {
        _ = self;
        print("🤖 ChatGPT for Dowel OS\n", .{});
        print("  💬 AI: Hello! I'm running natively on your\n", .{});
        print("      custom mobile OS. How can I help you\n", .{});
        print("      optimize your Dowel system today?\n", .{});
        print("  ⚡ Powered by efficient Zig backend\n", .{});
    }

    pub fn shutdown(self: *Self) !void {
        print("\n🔌 Shutting down Dowel Mobile OS...\n", .{});
        print("   📱 Saving app states...\n", .{});
        print("   💾 Syncing file systems...\n", .{});
        print("   🔋 Optimizing for next boot...\n", .{});
        print("   ⚡ Powering down...\n\n", .{});
        print("✅ Goodbye! Your custom mobile OS rocks! 🚀\n", .{});
        self.is_running = false;
    }
};

const App = struct {
    name: []const u8,
    icon: []const u8,
    type: AppType,
};

const AppType = enum {
    System,
    Utility,
    Developer,
    Internet,
    Productivity,
    Media,
    Navigation,
    AI,
};

const Display = struct {
    width: u32,
    height: u32,
    refresh_rate: u32,

    pub fn init() Display {
        return Display{
            .width = 1920,
            .height = 1080,
            .refresh_rate = 60,
        };
    }

    pub fn start(self: *Display) void {
        print("   📺 Display system initialized\n", .{});
        print("      Resolution: {}x{} @ {}Hz\n", .{ self.width, self.height, self.refresh_rate });
    }
};

// Main entry point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var os = try DowelOS.init(allocator);
    defer os.deinit();

    try os.boot();

    // Main OS loop
    while (os.is_running) {
        try os.run();
    }
}
