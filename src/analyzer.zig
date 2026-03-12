const std = @import("std");
const models = @import("models.zig");
const parser = @import("parser.zig");
const validator = @import("validator.zig");
const scorer = @import("scorer.zig");
const claude_client = @import("claude_client.zig");

const AnalysisReport = models.AnalysisReport;

pub fn analyzeText(allocator: std.mem.Allocator, text: []const u8) !AnalysisReport {
    // Parse the reasoning chain
    const chain = try parser.parseChain(allocator, text);

    // Validate the chain
    const validation = try validator.validate(allocator, chain);

    // Score the chain
    const score = scorer.scoreChain(chain);

    // Get AI analysis (mocked)
    const client = claude_client.MockClaudeClient.init();
    const ai_summary = client.analyzeReasoning(text);

    return AnalysisReport{
        .chain = chain,
        .validation = validation,
        .score = score,
        .ai_summary = ai_summary,
    };
}

pub fn freeReport(allocator: std.mem.Allocator, report: AnalysisReport) void {
    allocator.free(report.chain.steps);
    allocator.free(report.validation.fallacies);
    allocator.free(report.validation.issues);
}

test "full analysis pipeline" {
    const allocator = std.testing.allocator;
    const text = "Because research data shows positive results therefore the hypothesis is supported";
    const report = try analyzeText(allocator, text);
    defer freeReport(allocator, report);

    try std.testing.expect(report.chain.step_count >= 2);
    try std.testing.expect(report.score.overall_score > 0.0);
    try std.testing.expect(report.ai_summary.len > 0);
}

test "analyze empty text" {
    const allocator = std.testing.allocator;
    const report = try analyzeText(allocator, "");
    defer freeReport(allocator, report);

    try std.testing.expectEqual(@as(usize, 0), report.chain.step_count);
}
