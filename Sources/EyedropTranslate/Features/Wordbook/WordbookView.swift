import SwiftUI

/// 划词本列表：原文 / 释义 / 相对时间；搜索；删除；空态。
struct WordbookView: View {
    @ObservedObject var store: WordbookStore
    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(PlaceholderStrings.wordbookTitle)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            TextField(PlaceholderStrings.wordbookSearchPrompt, text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            let items = store.filtered(query: query)
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(PlaceholderStrings.wordbookEmpty)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { entry in
                        WordbookRow(entry: entry) {
                            store.delete(entry)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(
            minWidth: Constants.Wordbook.windowWidth,
            minHeight: Constants.Wordbook.windowHeight
        )
    }
}

private struct WordbookRow: View {
    let entry: WordbookEntry
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.source)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(entry.gloss)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(Self.relativeTime(entry.createdAt))
                        .font(AppTheme.Typography.caption2)
                        .foregroundStyle(.tertiary)
                    if let app = entry.sourceApp, !app.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(app)
                            .font(AppTheme.Typography.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            Button(role: .destructive, action: onDelete) {
                Text(PlaceholderStrings.wordbookDelete)
                    .font(AppTheme.Typography.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
