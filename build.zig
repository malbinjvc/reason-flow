const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "reason-flow",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the reason-flow CLI");
    run_step.dependOn(&run_cmd.step);

    const test_modules = [_][]const u8{
        "src/main.zig",
        "src/models.zig",
        "src/parser.zig",
        "src/validator.zig",
        "src/scorer.zig",
        "src/analyzer.zig",
        "src/claude_client.zig",
        "src/json_writer.zig",
    };

    const test_step = b.step("test", "Run all unit tests");

    for (test_modules) |test_file| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });

        const unit_tests = b.addTest(.{
            .root_module = test_mod,
        });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
