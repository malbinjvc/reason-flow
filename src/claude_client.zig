const std = @import("std");

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

pub const MockClaudeClient = struct {
    model: []const u8 = "claude-3-opus-mock",

    pub fn init() MockClaudeClient {
        return MockClaudeClient{};
    }

    /// Analyze text and return a deterministic summary based on keywords.
    /// This is a mock — no real API calls are made.
    pub fn analyzeReasoning(self: *const MockClaudeClient, text: []const u8) []const u8 {
        _ = self;

        if (text.len == 0) {
            return "No reasoning text provided for analysis.";
        }

        // Keyword-based deterministic analysis
        if (containsIgnoreCase(text, "evidence") or containsIgnoreCase(text, "research") or containsIgnoreCase(text, "data")) {
            return "Strong evidence-based reasoning detected. The argument is well-supported by empirical claims.";
        }

        if (containsIgnoreCase(text, "everyone knows") or containsIgnoreCase(text, "obviously")) {
            return "Weak reasoning detected. The argument relies on unsupported generalizations.";
        }

        if (containsIgnoreCase(text, "stupid") or containsIgnoreCase(text, "idiot")) {
            return "Ad hominem attack detected. The argument targets the person rather than addressing the claim.";
        }

        if (containsIgnoreCase(text, "either") and containsIgnoreCase(text, "or")) {
            return "Potential false dichotomy detected. Consider whether additional options exist.";
        }

        if (containsIgnoreCase(text, "disaster") or containsIgnoreCase(text, "catastrophe")) {
            return "Potential slippery slope detected. The argument assumes extreme consequences without justification.";
        }

        if (containsIgnoreCase(text, "science") or containsIgnoreCase(text, "study")) {
            return "The reasoning references scientific methodology. Verify the cited sources for credibility.";
        }

        if (containsIgnoreCase(text, "moral") or containsIgnoreCase(text, "ethical")) {
            return "Ethical reasoning detected. The argument involves value judgments that may vary by framework.";
        }

        return "General reasoning chain analyzed. The argument follows a basic logical structure.";
    }

    pub fn healthCheck(self: *const MockClaudeClient) bool {
        _ = self;
        return true;
    }
};

test "mock claude client evidence analysis" {
    const client = MockClaudeClient.init();
    const result = client.analyzeReasoning("Research evidence shows data supports the conclusion");
    try std.testing.expect(std.mem.indexOf(u8, result, "evidence-based") != null);
}

test "mock claude client empty text" {
    const client = MockClaudeClient.init();
    const result = client.analyzeReasoning("");
    try std.testing.expect(std.mem.indexOf(u8, result, "No reasoning") != null);
}

test "mock claude client fallacy detection" {
    const client = MockClaudeClient.init();
    const result = client.analyzeReasoning("He is stupid therefore wrong");
    try std.testing.expect(std.mem.indexOf(u8, result, "Ad hominem") != null);
}

test "mock claude client health check" {
    const client = MockClaudeClient.init();
    try std.testing.expect(client.healthCheck());
}
