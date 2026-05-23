import Foundation

struct AIModelOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let tapeLabel: String

    static let all: [AIModelOption] = [
        AIModelOption(id: "opus-3-7", displayName: "Opus 3.7", tapeLabel: "Opus 3.7"),
        AIModelOption(id: "gemini-3-1-pro", displayName: "Gemini 3.1 Pro", tapeLabel: "Gemini 3.1"),
        AIModelOption(id: "grok-4-3", displayName: "Grok 4.3", tapeLabel: "Grok 4.3"),
        AIModelOption(id: "claude-opus-4-7", displayName: "Claude Opus 4.7", tapeLabel: "Opus 4.7"),
        AIModelOption(id: "gpt-5-5", displayName: "GPT-5.5", tapeLabel: "GPT-5.5"),
        AIModelOption(id: "llama-4-maverick", displayName: "Llama 4 Maverick", tapeLabel: "Llama 4"),
        AIModelOption(id: "mistral-large-3", displayName: "Mistral Large 3", tapeLabel: "Mistral L3"),
        AIModelOption(id: "qwen3-max", displayName: "Qwen3 Max", tapeLabel: "Qwen3 Max")
    ]

    static let defaultModel = all.first { $0.id == "claude-opus-4-7" } ?? all[0]
}
