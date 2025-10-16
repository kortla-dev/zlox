const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlox_common_mod = b.addModule("zlox/common", .{
        .root_source_file = b.path("src/core/common.zig"),
        .target = target,
    });

    // const zlox_debug_mod = b.addModule("zlox/debug", .{
    //     .root_source_file = b.path("src/debug/debug.zig"),
    //     .target = target,
    // });

    const exe = b.addExecutable(.{
        .name = "zlox",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zlox/common", .module = zlox_common_mod },
                // .{ .name = "zlox/debug", .module = zlox_debug_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // ============ Commands ============
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .name = "Stack unit tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core/stack.zig"),
            .target = target,
        }),
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
