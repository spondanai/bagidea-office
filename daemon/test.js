const assert = require('assert');
const { meetingModel, backendOf, parseResetMs, reg } = require('./server.js');

console.log("Running tests...");

// Reset registry to clean state for testing
Object.assign(reg, {
  agents: {
    "agent-claude": { backend: "claude", model: "claude-3-opus-20240229" },
    "agent-gemini": { backend: "gemini", model: "gemini-1.5-pro-latest" },
    "agent-custom": { backend: "openai", model: "gpt-4" },
    "agent-default": {}
  },
  officeModel: "claude-3-sonnet-20240229",
  meetingModels: {
    claude: "custom-haiku-model"
  }
});

// Test 1: backendOf logic (Backend mapping)
console.log("- Testing backendOf()");
assert.strictEqual(backendOf(reg.agents["agent-claude"]).kind, "claude");
assert.strictEqual(backendOf(reg.agents["agent-gemini"]).cmd, "gemini");
assert.strictEqual(backendOf(reg.agents["agent-gemini"]).kind, "generic");
assert.strictEqual(backendOf(reg.agents["agent-default"]).kind, "claude");

// Test 2: meetingModel logic (Economy Tier Enforcement)
console.log("- Testing meetingModel()");
// agent-claude should use the overridden meeting model in reg
assert.strictEqual(meetingModel(reg.agents["agent-claude"]), "custom-haiku-model");
// agent-gemini should use the built-in economy tier fallback for gemini
assert.strictEqual(meetingModel(reg.agents["agent-gemini"]), "gemini-3-flash-preview");
// agent-custom (openai) has no builtin meeting model, should fallback to its own model
assert.strictEqual(meetingModel(reg.agents["agent-custom"]), "gpt-4");

// Test 3: parseResetMs logic (Usage parsing)
console.log("- Testing parseResetMs()");
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
const dateStr = tomorrow.toLocaleString('en-US', { month: 'short', day: 'numeric' }) + " 10:00 AM";

assert.ok(parseResetMs(dateStr) > 0);
assert.strictEqual(parseResetMs("32:99 AM"), null);

console.log("✅ All tests passed successfully!");
process.exit(0);
