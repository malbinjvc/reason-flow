const std = @import("std");
const models = @import("models.zig");
const parser = @import("parser.zig");

const ReasoningChain = models.ReasoningChain;
const ValidationResult = models.ValidationResult;
const FallacyType = models.FallacyType;

fn toLowerBuf(input: []const u8, buf: []u8) []const u8 {
    const len = @min(input.len, buf.len);
    for (0..len) |i| {
        buf[i] = std.ascii.toLower(input[i]);
    }
    return buf[0..len];
}

fn containsIgnoreCase(text: []const u8, needle: []const u8) bool {
    var buf: [4096]u8 = undefined;
    const lower = toLowerBuf(text, &buf);
    return std.mem.indexOf(u8, lower, needle) != null;
}

fn checkCircularReasoning(chain: ReasoningChain) bool {
    if (chain.step_count < 2) return false;
    const first = parser.trimWhitespace(chain.steps[0].content);
    const last = parser.trimWhitespace(chain.steps[chain.step_count - 1].content);
    // If the first and last steps are very similar, it's circular
    if (std.mem.eql(u8, first, last)) return true;
    // Check if the conclusion restates the premise with minor differences
    var buf1: [4096]u8 = undefined;
    var buf2: [4096]u8 = undefined;
    const lower_first = toLowerBuf(first, &buf1);
    const lower_last = toLowerBuf(last, &buf2);
    if (std.mem.eql(u8, lower_first, lower_last)) return true;
    // Check if one contains the other
    if (lower_first.len > 10 and lower_last.len > 10) {
        if (std.mem.indexOf(u8, lower_last, lower_first) != null) return true;
        if (std.mem.indexOf(u8, lower_first, lower_last) != null) return true;
    }
    return false;
}

fn checkContradictions(chain: ReasoningChain) bool {
    if (chain.step_count < 2) return false;
    const negation_pairs = [_][2][]const u8{
        .{ "is not", "is" },
        .{ "cannot", "can" },
        .{ "never", "always" },
        .{ "false", "true" },
        .{ "impossible", "possible" },
        .{ "incorrect", "correct" },
    };

    for (0..chain.step_count) |i| {
        for (i + 1..chain.step_count) |j| {
            const step_a = chain.steps[i].content;
            const step_b = chain.steps[j].content;
            for (negation_pairs) |pair| {
                if (containsIgnoreCase(step_a, pair[0]) and containsIgnoreCase(step_b, pair[1]) and !containsIgnoreCase(step_b, pair[0])) {
                    return true;
                }
                if (containsIgnoreCase(step_b, pair[0]) and containsIgnoreCase(step_a, pair[1]) and !containsIgnoreCase(step_a, pair[0])) {
                    return true;
                }
            }
        }
    }
    return false;
}

fn checkUnsupportedClaims(chain: ReasoningChain) bool {
    // Check if any step uses vague/unsupported language
    const vague_indicators = [_][]const u8{
        "everyone knows",
        "obviously",
        "it is clear that",
        "nobody can deny",
        "undeniable",
        "trust me",
        "some people say",
    };

    for (chain.steps) |step| {
        for (vague_indicators) |indicator| {
            if (containsIgnoreCase(step.content, indicator)) {
                return true;
            }
        }
    }
    return false;
}

fn detectFallacyKeywords(chain: ReasoningChain) ?FallacyType {
    const full_text = chain.original_text;

    if (containsIgnoreCase(full_text, "everyone knows") or containsIgnoreCase(full_text, "nobody can deny")) {
        return .hasty_generalization;
    }
    if (containsIgnoreCase(full_text, "expert says") or containsIgnoreCase(full_text, "authority") or containsIgnoreCase(full_text, "famous person")) {
        return .appeal_to_authority;
    }
    if (containsIgnoreCase(full_text, "either") and containsIgnoreCase(full_text, "or")) {
        return .false_dichotomy;
    }
    if (containsIgnoreCase(full_text, "will lead to") and containsIgnoreCase(full_text, "disaster")) {
        return .slippery_slope;
    }
    if (containsIgnoreCase(full_text, "stupid") or containsIgnoreCase(full_text, "idiot") or containsIgnoreCase(full_text, "fool")) {
        return .ad_hominem;
    }
    if (containsIgnoreCase(full_text, "irrelevant") or containsIgnoreCase(full_text, "by the way")) {
        return .red_herring;
    }
    return null;
}

pub fn validate(allocator: std.mem.Allocator, chain: ReasoningChain) !ValidationResult {
    var fallacies: std.ArrayList(FallacyType) = .{};
    var issues: std.ArrayList([]const u8) = .{};

    // Check circular reasoning
    if (checkCircularReasoning(chain)) {
        try fallacies.append(allocator, .circular_reasoning);
        try issues.append(allocator, "Circular reasoning detected: conclusion restates premise");
    }

    // Check contradictions
    if (checkContradictions(chain)) {
        try issues.append(allocator, "Contradiction detected between reasoning steps");
    }

    // Check unsupported claims
    if (checkUnsupportedClaims(chain)) {
        try issues.append(allocator, "Unsupported or vague claims detected");
    }

    // Detect specific fallacies
    if (detectFallacyKeywords(chain)) |fallacy| {
        try fallacies.append(allocator, fallacy);
        const msg = switch (fallacy) {
            .hasty_generalization => "Hasty generalization: overly broad claim without evidence",
            .appeal_to_authority => "Appeal to authority: relying on authority rather than evidence",
            .false_dichotomy => "False dichotomy: presenting only two options",
            .slippery_slope => "Slippery slope: assuming extreme consequences",
            .ad_hominem => "Ad hominem: attacking the person rather than the argument",
            .red_herring => "Red herring: introducing irrelevant information",
            else => "Logical fallacy detected",
        };
        try issues.append(allocator, msg);
    }

    // Check minimum chain length
    if (chain.step_count < 2) {
        try issues.append(allocator, "Reasoning chain too short: needs at least a premise and conclusion");
    }

    const fallacy_count = fallacies.items.len;
    const issue_count = issues.items.len;
    const is_valid = fallacy_count == 0 and issue_count == 0;

    return ValidationResult{
        .is_valid = is_valid,
        .fallacies = try fallacies.toOwnedSlice(allocator),
        .fallacy_count = fallacy_count,
        .issues = try issues.toOwnedSlice(allocator),
        .issue_count = issue_count,
    };
}

test "validate valid chain" {
    const allocator = std.testing.allocator;
    const chain_text = "Because it is raining therefore I take an umbrella";
    const chain = try @import("parser.zig").parseChain(allocator, chain_text);
    defer allocator.free(chain.steps);

    const result = try validate(allocator, chain);
    defer allocator.free(result.fallacies);
    defer allocator.free(result.issues);

    try std.testing.expect(result.is_valid);
    try std.testing.expectEqual(@as(usize, 0), result.fallacy_count);
}

test "validate circular reasoning" {
    const allocator = std.testing.allocator;
    // Construct a chain manually with circular reasoning
    var steps = [_]models.ReasoningStep{
        .{ .index = 0, .content = "The sky is blue", .step_type = .premise },
        .{ .index = 1, .content = "The sky is blue", .step_type = .conclusion },
    };
    const chain = ReasoningChain{
        .steps = &steps,
        .original_text = "The sky is blue therefore the sky is blue",
        .step_count = 2,
    };

    const result = try validate(allocator, chain);
    defer allocator.free(result.fallacies);
    defer allocator.free(result.issues);

    try std.testing.expect(!result.is_valid);
    try std.testing.expect(result.fallacy_count > 0);
}

test "validate ad hominem detection" {
    const allocator = std.testing.allocator;
    var steps = [_]models.ReasoningStep{
        .{ .index = 0, .content = "He is stupid", .step_type = .premise },
        .{ .index = 1, .content = "His argument is wrong", .step_type = .conclusion },
    };
    const chain = ReasoningChain{
        .steps = &steps,
        .original_text = "He is stupid therefore his argument is wrong",
        .step_count = 2,
    };

    const result = try validate(allocator, chain);
    defer allocator.free(result.fallacies);
    defer allocator.free(result.issues);

    try std.testing.expect(!result.is_valid);
    // Should detect ad hominem
    var found_ad_hominem = false;
    for (result.fallacies) |f| {
        if (f == .ad_hominem) found_ad_hominem = true;
    }
    try std.testing.expect(found_ad_hominem);
}
