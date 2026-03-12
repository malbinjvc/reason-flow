const std = @import("std");
const models = @import("models.zig");

const ReasoningStep = models.ReasoningStep;
const ReasoningChain = models.ReasoningChain;

const delimiters = [_][]const u8{
    "therefore",
    "because",
    " so ",
    "thus",
    "hence",
};

fn toLowerBuf(input: []const u8, buf: []u8) []const u8 {
    const len = @min(input.len, buf.len);
    for (0..len) |i| {
        buf[i] = std.ascii.toLower(input[i]);
    }
    return buf[0..len];
}

fn containsDelimiter(text: []const u8) ?struct { pos: usize, len: usize } {
    var lower_buf: [4096]u8 = undefined;
    const lower = toLowerBuf(text, &lower_buf);

    var best_pos: ?usize = null;
    var best_len: usize = 0;

    for (delimiters) |delim| {
        if (std.mem.indexOf(u8, lower, delim)) |pos| {
            if (best_pos == null or pos < best_pos.?) {
                best_pos = pos;
                best_len = delim.len;
            }
        }
    }

    if (best_pos) |pos| {
        return .{ .pos = pos, .len = best_len };
    }
    return null;
}

fn isNumberedStep(text: []const u8) bool {
    if (text.len < 2) return false;
    var i: usize = 0;
    // Skip leading whitespace
    while (i < text.len and (text[i] == ' ' or text[i] == '\t')) : (i += 1) {}
    if (i >= text.len) return false;
    // Check for digit
    if (!std.ascii.isDigit(text[i])) return false;
    i += 1;
    // Skip more digits
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    // Check for '.' or ')'
    if (i < text.len and (text[i] == '.' or text[i] == ')')) return true;
    return false;
}

fn stripNumberPrefix(text: []const u8) []const u8 {
    var i: usize = 0;
    // Skip leading whitespace
    while (i < text.len and (text[i] == ' ' or text[i] == '\t')) : (i += 1) {}
    // Skip digits
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    // Skip '.' or ')'
    if (i < text.len and (text[i] == '.' or text[i] == ')')) i += 1;
    // Skip space after
    if (i < text.len and text[i] == ' ') i += 1;
    return text[i..];
}

pub fn trimWhitespace(text: []const u8) []const u8 {
    var start: usize = 0;
    while (start < text.len and (text[start] == ' ' or text[start] == '\t' or text[start] == '\n' or text[start] == '\r')) : (start += 1) {}
    if (start >= text.len) return text[0..0];
    var end: usize = text.len;
    while (end > start and (text[end - 1] == ' ' or text[end - 1] == '\t' or text[end - 1] == '\n' or text[end - 1] == '\r')) : (end -= 1) {}
    return text[start..end];
}

pub fn parseChain(allocator: std.mem.Allocator, text: []const u8) !ReasoningChain {
    var steps: std.ArrayList(ReasoningStep) = .{};

    const trimmed = trimWhitespace(text);
    if (trimmed.len == 0) {
        return ReasoningChain{
            .steps = try steps.toOwnedSlice(allocator),
            .original_text = text,
            .step_count = 0,
        };
    }

    // Try numbered step parsing first
    var lines = std.mem.splitScalar(u8, trimmed, '\n');
    var has_numbered = false;
    var line_parts: std.ArrayList([]const u8) = .{};
    defer line_parts.deinit(allocator);

    while (lines.next()) |line| {
        const tl = trimWhitespace(line);
        if (tl.len == 0) continue;
        if (isNumberedStep(tl)) has_numbered = true;
        try line_parts.append(allocator, tl);
    }

    if (has_numbered and line_parts.items.len > 1) {
        // Parse as numbered steps
        for (line_parts.items, 0..) |line, i| {
            const content = if (isNumberedStep(line)) stripNumberPrefix(line) else line;
            const step_type: ReasoningStep.StepType = if (i == 0)
                .premise
            else if (i == line_parts.items.len - 1)
                .conclusion
            else
                .intermediate;

            try steps.append(allocator, ReasoningStep{
                .index = i,
                .content = content,
                .step_type = step_type,
            });
        }
    } else {
        // Parse by delimiters
        var remaining = trimmed;
        var step_index: usize = 0;

        while (remaining.len > 0) {
            if (containsDelimiter(remaining)) |result| {
                const before = trimWhitespace(remaining[0..result.pos]);
                if (before.len > 0) {
                    const step_type: ReasoningStep.StepType = if (step_index == 0) .premise else .intermediate;
                    try steps.append(allocator, ReasoningStep{
                        .index = step_index,
                        .content = before,
                        .step_type = step_type,
                    });
                    step_index += 1;
                }
                remaining = remaining[result.pos + result.len ..];
            } else {
                const piece = trimWhitespace(remaining);
                if (piece.len > 0) {
                    try steps.append(allocator, ReasoningStep{
                        .index = step_index,
                        .content = piece,
                        .step_type = if (step_index == 0) .premise else .conclusion,
                    });
                }
                break;
            }
        }

        // Mark last step as conclusion if more than one step
        if (steps.items.len > 1) {
            steps.items[steps.items.len - 1].step_type = .conclusion;
        }
    }

    const count = steps.items.len;
    return ReasoningChain{
        .steps = try steps.toOwnedSlice(allocator),
        .original_text = text,
        .step_count = count,
    };
}

test "parse simple because-therefore chain" {
    const allocator = std.testing.allocator;
    const chain = try parseChain(allocator, "Because it is raining therefore I take an umbrella");
    defer allocator.free(chain.steps);

    try std.testing.expectEqual(@as(usize, 2), chain.step_count);
    try std.testing.expectEqualStrings("it is raining", chain.steps[0].content);
    try std.testing.expectEqual(ReasoningStep.StepType.premise, chain.steps[0].step_type);
    try std.testing.expectEqualStrings("I take an umbrella", chain.steps[1].content);
    try std.testing.expectEqual(ReasoningStep.StepType.conclusion, chain.steps[1].step_type);
}

test "parse numbered steps" {
    const allocator = std.testing.allocator;
    const input =
        \\1. All humans are mortal
        \\2. Socrates is a human
        \\3. Socrates is mortal
    ;
    const chain = try parseChain(allocator, input);
    defer allocator.free(chain.steps);

    try std.testing.expectEqual(@as(usize, 3), chain.step_count);
    try std.testing.expectEqualStrings("All humans are mortal", chain.steps[0].content);
    try std.testing.expectEqual(ReasoningStep.StepType.premise, chain.steps[0].step_type);
    try std.testing.expectEqualStrings("Socrates is a human", chain.steps[1].content);
    try std.testing.expectEqual(ReasoningStep.StepType.intermediate, chain.steps[1].step_type);
    try std.testing.expectEqualStrings("Socrates is mortal", chain.steps[2].content);
    try std.testing.expectEqual(ReasoningStep.StepType.conclusion, chain.steps[2].step_type);
}

test "parse empty text" {
    const allocator = std.testing.allocator;
    const chain = try parseChain(allocator, "");
    defer allocator.free(chain.steps);

    try std.testing.expectEqual(@as(usize, 0), chain.step_count);
}

test "parse chain with thus" {
    const allocator = std.testing.allocator;
    const chain = try parseChain(allocator, "The data shows growth thus the company is profitable");
    defer allocator.free(chain.steps);

    try std.testing.expectEqual(@as(usize, 2), chain.step_count);
    try std.testing.expectEqualStrings("The data shows growth", chain.steps[0].content);
    try std.testing.expectEqualStrings("the company is profitable", chain.steps[1].content);
}

test "trimWhitespace" {
    try std.testing.expectEqualStrings("hello", trimWhitespace("  hello  "));
    try std.testing.expectEqualStrings("", trimWhitespace("   "));
    try std.testing.expectEqualStrings("a b", trimWhitespace("a b"));
}
