//
//  ChatThreadListView.swift
//  scroll options
//
//  Recent conversations, most recent first. This is the root of the
//  navigation stack; a chat is pushed on top of it.
//

import SwiftUI

struct ChatThreadListView: View {
    let threads: [ChatThread]
    let onSelect: (ChatThread) -> Void
    let onNewChat: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                ChatThreadRows(threads: threads, onSelect: onSelect)
                    .padding(.horizontal, 16)
                    .padding(.top, 68)
                    .padding(.bottom, 32)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onNewChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Start new chat")
            .accessibilityIdentifier("startNewChatFromList")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("chatThreadList")
    }
}

/// Section headers and rows for a list of threads, most recent first.
struct ChatThreadRows: View {
    let threads: [ChatThread]
    let onSelect: (ChatThread) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Chats")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            ForEach(ChatThreadSection.group(threads)) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(section.threads) { thread in
                        ChatThreadRow(thread: thread) {
                            onSelect(thread)
                        }
                    }
                }
            }
        }
    }
}

private struct ChatThreadRow: View {
    let thread: ChatThread
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(thread.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(thread.lastActivity, format: .relative(presentation: .named))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Text(thread.preview)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(thread.title)
        .accessibilityHint("Opens this chat.")
        .accessibilityIdentifier("chatThread-\(thread.id)")
    }
}

struct ChatThreadSection: Identifiable {
    let title: String
    let threads: [ChatThread]

    var id: String { title }

    /// Groups threads by recency, newest first within each section.
    static func group(_ threads: [ChatThread], now: Date = .now,
                      calendar: Calendar = .current) -> [ChatThreadSection] {
        let sorted = threads.sorted { $0.lastActivity > $1.lastActivity }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now

        var buckets: [(title: String, threads: [ChatThread])] = [
            ("Today", []), ("Yesterday", []), ("Previous 7 Days", []), ("Older", []),
        ]
        for thread in sorted {
            let date = thread.lastActivity
            if calendar.isDateInToday(date) || date > now {
                buckets[0].threads.append(thread)
            } else if calendar.isDateInYesterday(date) {
                buckets[1].threads.append(thread)
            } else if date >= weekAgo {
                buckets[2].threads.append(thread)
            } else {
                buckets[3].threads.append(thread)
            }
        }
        return buckets
            .filter { !$0.threads.isEmpty }
            .map { ChatThreadSection(title: $0.title, threads: $0.threads) }
    }
}

#Preview {
    ChatThreadListView(threads: ChatThread.samples, onSelect: { _ in }, onNewChat: {})
        .preferredColorScheme(.dark)
}
