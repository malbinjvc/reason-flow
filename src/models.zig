const std = @import("std");

pub const FallacyType = enum {
    circular_reasoning,
    ad_hominem,
    straw_man,
    false_dichotomy,
    slippery_slope,
    appeal_to_authority,
    hasty_generalization,
    red_herring,
    none,

    pub fn toString(self: FallacyType) []const u8 {
        return switch (self) {
            .circular_reasoning => "circular_reasoning",
            .ad_hominem => "ad_hominem",
            .straw_man => "straw_man",
            .false_dichotomy => "false_dichotomy",
            .slippery_slope => "slippery_slope",
            .appeal_to_authority => "appeal_to_authority",
            .hasty_generalization => "hasty_generalization",
            .red_herring => "red_herring",
            .none => "none",
        };
    }
};

pub const ReasoningStep = struct {
    index: usize,
    content: []const u8,
    step_type: StepType,

    pub const StepType = enum {
        premise,
        conclusion,
        intermediate,

        pub fn toString(self: StepType) []const u8 {
            return switch (self) {
                .premise => "premise",
                .conclusion => "conclusion",
                .intermediate => "intermediate",
            };
        }
    };
};

pub const ReasoningChain = struct {
    steps: []ReasoningStep,
    original_text: []const u8,
    step_count: usize,
};

pub const ValidationResult = struct {
    is_valid: bool,
    fallacies: []FallacyType,
    fallacy_count: usize,
    issues: [][]const u8,
    issue_count: usize,
};

pub const ScoreResult = struct {
    overall_score: f64,
    evidence_strength: f64,
    logical_coherence: f64,
    completeness: f64,
};

pub const AnalysisReport = struct {
    chain: ReasoningChain,
    validation: ValidationResult,
    score: ScoreResult,
    ai_summary: []const u8,
};

test "FallacyType toString" {
    try std.testing.expectEqualStrings("circular_reasoning", FallacyType.circular_reasoning.toString());
    try std.testing.expectEqualStrings("none", FallacyType.none.toString());
    try std.testing.expectEqualStrings("ad_hominem", FallacyType.ad_hominem.toString());
}

test "StepType toString" {
    try std.testing.expectEqualStrings("premise", ReasoningStep.StepType.premise.toString());
    try std.testing.expectEqualStrings("conclusion", ReasoningStep.StepType.conclusion.toString());
    try std.testing.expectEqualStrings("intermediate", ReasoningStep.StepType.intermediate.toString());
}
