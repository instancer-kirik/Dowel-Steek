const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Create a static library for mobile integration
    const lib = b.addStaticLibrary(.{
        .name = "dowel-steek-core",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a minimal API library for testing/development
    const minimal_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-minimal",
        .root_source_file = b.path("src/minimal_api.zig"),
        .target = target,
        .optimize = optimize,
    });
    minimal_lib.linkLibC();

    // Create C header files for interoperability
    const c_headers = b.addInstallDirectory(.{
        .source_dir = b.path("c_headers"),
        .install_dir = .prefix,
        .install_subdir = "include",
    });

    // Mobile-specific targets
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

    const ios_aarch64_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
    });

    const ios_x86_64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .ios,
    });

    // Android builds
    const android_aarch64_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-core-android-aarch64",
        .root_source_file = b.path("src/lib.zig"),
        .target = android_aarch64_target,
        .optimize = optimize,
    });

    const android_x86_64_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-core-android-x86_64",
        .root_source_file = b.path("src/lib.zig"),
        .target = android_x86_64_target,
        .optimize = optimize,
    });

    // iOS builds
    const ios_aarch64_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-core-ios-aarch64",
        .root_source_file = b.path("src/lib.zig"),
        .target = ios_aarch64_target,
        .optimize = optimize,
    });

    const ios_x86_64_lib = b.addStaticLibrary(.{
        .name = "dowel-steek-core-ios-x86_64",
        .root_source_file = b.path("src/lib.zig"),
        .target = ios_x86_64_target,
        .optimize = optimize,
    });

    // Enable link-time optimization for release builds
    if (optimize != .Debug) {
        lib.want_lto = true;
        android_aarch64_lib.want_lto = true;
        android_x86_64_lib.want_lto = true;
        ios_aarch64_lib.want_lto = true;
        ios_x86_64_lib.want_lto = true;
    }

    // Install artifacts
    b.installArtifact(lib);
    b.installArtifact(minimal_lib);
    b.installArtifact(android_aarch64_lib);
    b.installArtifact(android_x86_64_lib);
    b.installArtifact(ios_aarch64_lib);
    b.installArtifact(ios_x86_64_lib);
    b.getInstallStep().dependOn(&c_headers.step);

    // Create a run step for testing
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Benchmark step
    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const run_benchmark = b.addRunArtifact(benchmark);

    const benchmark_step = b.step("bench", "Run performance benchmarks");
    benchmark_step.dependOn(&run_benchmark.step);

    // Test minimal API build step
    const minimal_step = b.step("minimal", "Build minimal API library");
    minimal_step.dependOn(&b.addInstallArtifact(minimal_lib, .{}).step);

    // Mobile-specific build steps
    const android_step = b.step("android", "Build for Android targets");
    android_step.dependOn(&b.addInstallArtifact(android_aarch64_lib, .{}).step);
    android_step.dependOn(&b.addInstallArtifact(android_x86_64_lib, .{}).step);

    const ios_step = b.step("ios", "Build for iOS targets");
    ios_step.dependOn(&b.addInstallArtifact(ios_aarch64_lib, .{}).step);
    ios_step.dependOn(&b.addInstallArtifact(ios_x86_64_lib, .{}).step);

    const mobile_step = b.step("mobile", "Build for all mobile targets");
    mobile_step.dependOn(android_step);
    mobile_step.dependOn(ios_step);

    // Documentation generation
    const docs = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);

    // Clean step for generated files
    const clean_step = b.step("clean", "Clean build artifacts");
    const rm_zig_cache = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", "zig-cache" });
    const rm_zig_out = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", "zig-out" });
    clean_step.dependOn(&rm_zig_cache.step);
    clean_step.dependOn(&rm_zig_out.step);
}
