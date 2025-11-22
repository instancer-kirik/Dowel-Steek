const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Test the correct API syntax for Zig 0.15
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test system library linking
    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the test");
    run_step.dependOn(&run_cmd.step);
}
