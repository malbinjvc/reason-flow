const std = @import("std");
const models = @import("models.zig");

pub fn writeJsonString(writer: anytype, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

pub fn writeJsonFloat(writer: anytype, value: f64) !void {
    // Write float with 4 decimal places
    const int_part = @as(i64, @intFromFloat(value));
    const frac = @abs(value - @as(f64, @floatFromInt(int_part)));
    const frac_int = @as(u64, @intFromFloat(frac * 10000.0 + 0.5));
    try writer.print("{d}.{d:0>4}", .{ int_part, frac_int });
}

pub fn writeChainJson(writer: anytype, chain: models.ReasoningChain) !void {
    try writer.writeAll("{\"step_count\":");
    try writer.print("{d}", .{chain.step_count});
    try writer.writeAll(",\"original_text\":");
    try writeJsonString(writer, chain.original_text);
    try writer.writeAll(",\"steps\":[");
    for (chain.steps, 0..) |step, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.writeAll("{\"index\":");
        try writer.print("{d}", .{step.index});
        try writer.writeAll(",\"content\":");
        try writeJsonString(writer, step.content);
        try writer.writeAll(",\"type\":");
        try writeJsonString(writer, step.step_type.toString());
        try writer.writeByte('}');
    }
    try writer.writeAll("]}");
}

pub fn writeValidationJson(writer: anytype, result: models.ValidationResult) !void {
    try writer.writeAll("{\"is_valid\":");
    if (result.is_valid) {
        try writer.writeAll("true");
    } else {
        try writer.writeAll("false");
    }
    try writer.writeAll(",\"fallacy_count\":");
    try writer.print("{d}", .{result.fallacy_count});
    try writer.writeAll(",\"fallacies\":[");
    for (result.fallacies, 0..) |fallacy, i| {
        if (i > 0) try writer.writeByte(',');
        try writeJsonString(writer, fallacy.toString());
    }
    try writer.writeAll("],\"issue_count\":");
    try writer.print("{d}", .{result.issue_count});
    try writer.writeAll(",\"issues\":[");
    for (result.issues, 0..) |issue, i| {
        if (i > 0) try writer.writeByte(',');
        try writeJsonString(writer, issue);
    }
    try writer.writeAll("]}");
}

pub fn writeScoreJson(writer: anytype, score: models.ScoreResult) !void {
    try writer.writeAll("{\"overall_score\":");
    try writeJsonFloat(writer, score.overall_score);
    try writer.writeAll(",\"evidence_strength\":");
    try writeJsonFloat(writer, score.evidence_strength);
    try writer.writeAll(",\"logical_coherence\":");
    try writeJsonFloat(writer, score.logical_coherence);
    try writer.writeAll(",\"completeness\":");
    try writeJsonFloat(writer, score.completeness);
    try writer.writeByte('}');
}

pub fn writeAnalysisJson(writer: anytype, report: models.AnalysisReport) !void {
    try writer.writeAll("{\"chain\":");
    try writeChainJson(writer, report.chain);
    try writer.writeAll(",\"validation\":");
    try writeValidationJson(writer, report.validation);
    try writer.writeAll(",\"score\":");
    try writeScoreJson(writer, report.score);
    try writer.writeAll(",\"ai_summary\":");
    try writeJsonString(writer, report.ai_summary);
    try writer.writeByte('}');
}

test "writeJsonString escaping" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writeJsonString(writer, "hello \"world\"");
    const result = fbs.getWritten();
    try std.testing.expectEqualStrings("\"hello \\\"world\\\"\"", result);
}

test "writeJsonFloat" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writeJsonFloat(writer, 0.75);
    const result = fbs.getWritten();
    try std.testing.expectEqualStrings("0.7500", result);
}

test "writeScoreJson" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    const score = models.ScoreResult{
        .overall_score = 0.85,
        .evidence_strength = 0.9,
        .logical_coherence = 0.8,
        .completeness = 0.7,
    };
    try writeScoreJson(writer, score);
    const result = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "overall_score") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "evidence_strength") != null);
}
