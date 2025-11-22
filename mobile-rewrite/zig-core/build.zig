const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dowel-Steek Convergent Mobile OS - Minimal API
    const minimal_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-minimal",
        .root_source_file = b.path("src/minimal_api.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link C library for C ABI compatibility
    minimal_lib.linkLibC();

    // Enable link-time optimization for release builds
    if (optimize != .Debug) {
        minimal_lib.want_lto = true;
    }

    // Install the library
    b.installArtifact(minimal_lib);

    // Mobile targets for cross-compilation
    const android_aarch64_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .android,
    });

    const android_x86_64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .android,
    });

    // Android ARM64 build (primary mobile target)
    const android_aarch64_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-minimal-android-aarch64",
        .root_source_file = b.path("src/minimal_api.zig"),
        .target = android_aarch64_target,
        .optimize = .ReleaseFast,
    });
    android_aarch64_lib.linkLibC();
    android_aarch64_lib.want_lto = true;

    // Android x86_64 build (emulator/testing)
    const android_x86_64_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-minimal-android-x86_64",
        .root_source_file = b.path("src/minimal_api.zig"),
        .target = android_x86_64_target,
        .optimize = .ReleaseFast,
    });
    android_x86_64_lib.linkLibC();
    android_x86_64_lib.want_lto = true;

    // Install mobile targets
    b.installArtifact(android_aarch64_lib);
    b.installArtifact(android_x86_64_lib);

    // Build steps
    const minimal_step = b.step("minimal", "Build minimal API library (default)");
    minimal_step.dependOn(&b.addInstallArtifact(minimal_lib, .{}).step);

    const android_step = b.step("android", "Build for Android targets");
    android_step.dependOn(&b.addInstallArtifact(android_aarch64_lib, .{}).step);
    android_step.dependOn(&b.addInstallArtifact(android_x86_64_lib, .{}).step);

    const mobile_step = b.step("mobile", "Build for all mobile targets");
    mobile_step.dependOn(android_step);

    // Tests for the minimal API
    const minimal_tests = b.addTest(.{
        .root_source_file = b.path("src/minimal_api.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(minimal_tests);
    const test_step = b.step("test", "Run minimal API tests");
    test_step.dependOn(&run_tests.step);

    // Clean step
    const clean_step = b.step("clean", "Clean build artifacts");
    const rm_zig_cache = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", "zig-cache" });
    const rm_zig_out = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", "zig-out" });
    clean_step.dependOn(&rm_zig_cache.step);
    clean_step.dependOn(&rm_zig_out.step);

    // Make minimal the default build
    b.default_step = minimal_step;

    // Help step
    const help_step = b.step("help", "Show available build options");
    const help_cmd = b.addSystemCommand(&[_][]const u8{ "echo", "Dowel-Steek Convergent Mobile OS Build System\n" ++
        "Available targets:\n" ++
        "  zig build           - Build minimal API (default)\n" ++
        "  zig build minimal   - Build minimal API library\n" ++
        "  zig build android   - Build for Android (ARM64 + x86_64)\n" ++
        "  zig build mobile    - Build for all mobile targets\n" ++
        "  zig build test      - Run tests\n" ++
        "  zig build clean     - Clean build artifacts\n" ++
        "  zig build help      - Show this help\n" });
    help_step.dependOn(&help_cmd.step);
}
