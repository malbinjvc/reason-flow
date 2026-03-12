const std = @import("std");
const models = @import("models.zig");

const ReasoningChain = models.ReasoningChain;
const ScoreResult = models.ScoreResult;

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

fn countKeywords(text: []const u8, keywords: []const []const u8) usize {
    var count: usize = 0;
    for (keywords) |kw| {
        if (containsIgnoreCase(text, kw)) count += 1;
    }
    return count;
}

fn scoreEvidenceStrength(chain: ReasoningChain) f64 {
    const evidence_keywords = [_][]const u8{
        "data",     "study",      "research",   "evidence",
        "shows",    "proves",     "experiment",  "statistics",
        "measured", "observed",   "according to", "survey",
        "analysis", "found that", "demonstrates",
    };

    var total_keywords: usize = 0;
    for (chain.steps) |step| {
        total_keywords += countKeywords(step.content, &evidence_keywords);
    }

    // More evidence keywords = higher score, max at 1.0
    const raw_score = @as(f64, @floatFromInt(total_keywords)) / 5.0;
    return @min(raw_score, 1.0);
}

fn scoreLogicalCoherence(chain: ReasoningChain) f64 {
    if (chain.step_count < 2) return 0.2;

    var score: f64 = 0.5; // Base score

    // Bonus for having logical connectors
    const connector_keywords = [_][]const u8{
        "therefore", "because", "thus", "hence",
        "since",     "implies", "leads to", "follows that",
        "consequently", "as a result",
    };

    var connector_count: usize = 0;
    for (chain.steps) |step| {
        connector_count += countKeywords(step.content, &connector_keywords);
    }
    // Also check original text
    connector_count += countKeywords(chain.original_text, &connector_keywords);

    score += @as(f64, @floatFromInt(@min(connector_count, 4))) * 0.1;

    // Bonus for having multiple steps
    if (chain.step_count >= 3) score += 0.1;
    if (chain.step_count >= 5) score += 0.1;

    // Penalty for very long chains with no intermediate steps
    if (chain.step_count == 2) {
        // Simple A->B, less rigorous
        score -= 0.05;
    }

    return @min(@max(score, 0.0), 1.0);
}

fn scoreCompleteness(chain: ReasoningChain) f64 {
    if (chain.step_count == 0) return 0.0;

    var score: f64 = 0.3;

    // Has both premise and conclusion?
    var has_premise = false;
    var has_conclusion = false;
    for (chain.steps) |step| {
        if (step.step_type == .premise) has_premise = true;
        if (step.step_type == .conclusion) has_conclusion = true;
    }

    if (has_premise) score += 0.2;
    if (has_conclusion) score += 0.2;
    if (has_premise and has_conclusion) score += 0.1;

    // Longer content is generally more complete
    var total_len: usize = 0;
    for (chain.steps) |step| {
        total_len += step.content.len;
    }
    if (total_len > 50) score += 0.1;
    if (total_len > 100) score += 0.1;

    return @min(score, 1.0);
}

pub fn scoreChain(chain: ReasoningChain) ScoreResult {
    const evidence = scoreEvidenceStrength(chain);
    const coherence = scoreLogicalCoherence(chain);
    const completeness = scoreCompleteness(chain);

    const overall = (evidence * 0.35) + (coherence * 0.40) + (completeness * 0.25);

    return ScoreResult{
        .overall_score = overall,
        .evidence_strength = evidence,
        .logical_coherence = coherence,
        .completeness = completeness,
    };
}

test "score chain with evidence keywords" {
    var steps = [_]models.ReasoningStep{
        .{ .index = 0, .content = "Research shows that data proves the hypothesis", .step_type = .premise },
        .{ .index = 1, .content = "The evidence demonstrates the conclusion", .step_type = .conclusion },
    };
    const chain = ReasoningChain{
        .steps = &steps,
        .original_text = "Research shows that data proves the hypothesis therefore the evidence demonstrates the conclusion",
        .step_count = 2,
    };

    const result = scoreChain(chain);
    try std.testing.expect(result.evidence_strength > 0.5);
    try std.testing.expect(result.overall_score > 0.0);
    try std.testing.expect(result.overall_score <= 1.0);
}

test "score empty chain" {
    const chain = ReasoningChain{
        .steps = &[_]models.ReasoningStep{},
        .original_text = "",
        .step_count = 0,
    };

    const result = scoreChain(chain);
    try std.testing.expect(result.evidence_strength == 0.0);
    try std.testing.expect(result.completeness == 0.0);
}

test "score chain completeness" {
    var steps = [_]models.ReasoningStep{
        .{ .index = 0, .content = "All mammals breathe air and have lungs for respiration", .step_type = .premise },
        .{ .index = 1, .content = "Whales are classified as mammals by biologists", .step_type = .intermediate },
        .{ .index = 2, .content = "Whales must therefore breathe air using their lungs", .step_type = .conclusion },
    };
    const chain = ReasoningChain{
        .steps = &steps,
        .original_text = "All mammals breathe air. Whales are mammals. Therefore whales breathe air.",
        .step_count = 3,
    };

    const result = scoreChain(chain);
    try std.testing.expect(result.completeness > 0.6);
    try std.testing.expect(result.logical_coherence > 0.4);
}
