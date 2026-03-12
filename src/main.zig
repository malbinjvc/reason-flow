const std = @import("std");
const parser = @import("parser.zig");
const validator = @import("validator.zig");
const scorer = @import("scorer.zig");
const analyzer = @import("analyzer.zig");
const json_writer = @import("json_writer.zig");

fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: reason-flow <command> [text]
        \\
        \\Commands:
        \\  parse    <text>  - Parse text into a reasoning chain (JSON output)
        \\  validate <text>  - Validate logic and detect fallacies (JSON output)
        \\  score    <text>  - Score argument strength 0.0-1.0 (JSON output)
        \\  analyze  <text>  - Full analysis: parse + validate + score (JSON output)
        \\  health           - Health check
        \\
        \\Examples:
        \\  reason-flow parse "Because it rains therefore I take an umbrella"
        \\  reason-flow analyze "Research data shows X therefore Y is supported"
        \\  reason-flow health
        \\
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    const stderr_file = std.fs.File{ .handle = std.posix.STDERR_FILENO };
    const stdout = stdout_file.deprecatedWriter();
    const stderr = stderr_file.deprecatedWriter();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage(stderr);
        std.process.exit(1);
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "health")) {
        try stdout.writeAll("{\"status\":\"healthy\"}\n");
        return;
    }

    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printUsage(stdout);
        return;
    }

    if (args.len < 3) {
        try stderr.writeAll("Error: missing text argument\n\n");
        try printUsage(stderr);
        std.process.exit(1);
    }

    const text = args[2];

    if (std.mem.eql(u8, command, "parse")) {
        const chain = try parser.parseChain(allocator, text);
        defer allocator.free(chain.steps);
        try json_writer.writeChainJson(stdout, chain);
        try stdout.writeByte('\n');
    } else if (std.mem.eql(u8, command, "validate")) {
        const chain = try parser.parseChain(allocator, text);
        defer allocator.free(chain.steps);
        const result = try validator.validate(allocator, chain);
        defer allocator.free(result.fallacies);
        defer allocator.free(result.issues);
        try json_writer.writeValidationJson(stdout, result);
        try stdout.writeByte('\n');
    } else if (std.mem.eql(u8, command, "score")) {
        const chain = try parser.parseChain(allocator, text);
        defer allocator.free(chain.steps);
        const score = scorer.scoreChain(chain);
        try json_writer.writeScoreJson(stdout, score);
        try stdout.writeByte('\n');
    } else if (std.mem.eql(u8, command, "analyze")) {
        const report = try analyzer.analyzeText(allocator, text);
        defer analyzer.freeReport(allocator, report);
        try json_writer.writeAnalysisJson(stdout, report);
        try stdout.writeByte('\n');
    } else {
        try stderr.print("Error: unknown command '{s}'\n\n", .{command});
        try printUsage(stderr);
        std.process.exit(1);
    }
}

test "main module imports" {
    _ = parser;
    _ = validator;
    _ = scorer;
    _ = analyzer;
    _ = json_writer;
    _ = @import("claude_client.zig");
    _ = @import("models.zig");
}
