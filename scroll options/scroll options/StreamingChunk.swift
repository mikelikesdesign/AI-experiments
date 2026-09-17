import Foundation

/// Reveal complete words and retain the source's exact spacing and paragraph breaks.
struct StreamingChunk {
    let text: String

    var pause: Duration {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("\n") { return .milliseconds(180) }
        if let last = word.last, ".!?".contains(last) { return .milliseconds(110) }
        if let last = word.last, ",;:".contains(last) { return .milliseconds(65) }
        return .milliseconds(min(60, max(28, word.count * 4)))
    }

    static func make(from text: String) -> [Self] {
        var chunks: [Self] = []
        var start = text.startIndex
        var previousWasWhitespace = false

        for index in text.indices {
            let isWhitespace = text[index].isWhitespace
            if previousWasWhitespace && !isWhitespace {
                chunks.append(Self(text: String(text[start..<index])))
                start = index
            }
            previousWasWhitespace = isWhitespace
        }
        if start < text.endIndex {
            chunks.append(Self(text: String(text[start...])))
        }
        return chunks
    }
}
