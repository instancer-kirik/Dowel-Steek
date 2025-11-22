const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Display system static library
    const display_lib = b.addStaticLibrary(.{
        .name = "dowel-display",
        .root_source_file = b.path("src/display.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link SDL2 for graphics
    display_lib.linkSystemLibrary("SDL2");
    display_lib.linkLibC();

    // Enable link-time optimization for release builds
    if (optimize != .Debug) {
        display_lib.want_lto = true;
    }

    // Install the library
    b.installArtifact(display_lib);

    // Demo executable for testing
    const display_demo = b.addExecutable(.{
        .name = "display-demo",
        .root_source_file = b.path("src/demo.zig"),
        .target = target,
        .optimize = optimize,
    });

    display_demo.linkLibrary(display_lib);
    display_demo.linkLibC();

    const run_demo = b.addRunArtifact(display_demo);
    run_demo.step.dependOn(b.getInstallStep());

    const demo_step = b.step("demo", "Run display system demo");
    demo_step.dependOn(&run_demo.step);

    // Unit tests
    const display_tests = b.addTest(.{
        .root_source_file = b.path("src/display.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(display_tests);

    const test_step = b.step("test", "Run display system tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark executable
    const display_bench = b.addExecutable(.{
        .name = "display-bench",
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    display_bench.linkLibrary(display_lib);
    display_bench.linkLibC();

    const run_bench = b.addRunArtifact(display_bench);
    run_bench.step.dependOn(b.getInstallStep());

    const bench_step = b.step("bench", "Run display system benchmarks");
    bench_step.dependOn(&run_bench.step);

    // C header generation for Kotlin interop
    const c_headers = b.addInstallDirectory(.{
        .source_dir = b.path("c_headers"),
        .install_dir = .prefix,
        .install_subdir = "include/dowel-display",
    });

    b.getInstallStep().dependOn(&c_headers.step);

    // Integration with main OS build
    const mobile_step = b.step("mobile", "Build for mobile targets");

    // ARM64 mobile build
    const mobile_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
    });

    const mobile_lib = b.addStaticLibrary(.{
        .name = "dowel-display-mobile",
        .root_source_file = b.path("src/display.zig"),
        .target = mobile_target,
        .optimize = .ReleaseFast,
    });

    // For mobile builds, we might use direct framebuffer instead of SDL
    // This would be configured via compile-time flags
    const mobile_options = b.addOptions();
    mobile_options.addOption(bool, "use_framebuffer", true);
    mobile_options.addOption(bool, "use_sdl", false);
    mobile_lib.root_module.addOptions("build_options", mobile_options);

    mobile_lib.linkLibC();
    mobile_lib.want_lto = true;

    mobile_step.dependOn(&b.addInstallArtifact(mobile_lib, .{}).step);

    // Emulator build (x86_64 with SDL2)
    const emulator_step = b.step("emulator", "Build for emulator");
    const emulator_options = b.addOptions();
    emulator_options.addOption(bool, "use_framebuffer", false);
    emulator_options.addOption(bool, "use_sdl", true);
    display_lib.root_module.addOptions("build_options", emulator_options);

    emulator_step.dependOn(&b.addInstallArtifact(display_lib, .{}).step);

    // Clean step
    const clean_step = b.step("clean", "Clean build artifacts");
    const rm_zig_cache = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", "zig-cache" });
    const rm_zig_out = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", "zig-out" });
    clean_step.dependOn(&rm_zig_cache.step);
    clean_step.dependOn(&rm_zig_out.step);

    // Documentation generation
    const docs_step = b.step("docs", "Generate documentation");
    const docs = b.addTest(.{
        .root_source_file = b.path("src/display.zig"),
        .target = target,
        .optimize = optimize,
    });

    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/display",
    }).step);
}
