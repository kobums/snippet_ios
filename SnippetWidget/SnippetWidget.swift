import WidgetKit
import SwiftUI

// MARK: - SnippetWidget (WidgetKit 익스텐션)
//
// ⚠️ 이 파일은 메인 앱 타깃이 아니라 **위젯 익스텐션 타깃**에 속한다.
// Xcode에서 Widget Extension 타깃을 추가한 뒤 이 파일을 그 타깃 멤버로 포함시킨다.
// 자세한 절차는 ../WIDGET-SETUP.md 참조.
//
// 데이터: 메인 앱이 App Group(group.com.gowoobro.snippet) UserDefaults에
//   snippet_text / snippet_tag 키로 최신 스니펫을 기록한다(SharedSnippetStore).

private let appGroupId = "group.com.gowoobro.snippet"

// MARK: - Entry

struct SnippetEntry: TimelineEntry {
    let date: Date
    let text: String
    let tag: String
}

// MARK: - Provider

struct SnippetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnippetEntry {
        SnippetEntry(date: Date(), text: "오늘의 스니펫을 만나보세요", tag: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (SnippetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnippetEntry>) -> Void) {
        // 앱이 reloadAllTimelines()로 갱신하므로 단일 엔트리 + never 정책
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> SnippetEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let text = defaults?.string(forKey: "snippet_text") ?? "오늘의 스니펫을 만나보세요"
        let tag = defaults?.string(forKey: "snippet_tag") ?? ""
        return SnippetEntry(date: Date(), text: text, tag: tag)
    }
}

// MARK: - View

struct SnippetWidgetEntryView: View {
    var entry: SnippetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
            if !entry.tag.isEmpty {
                Text("#\(entry.tag)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Widget

struct SnippetWidget: Widget {
    let kind: String = "SnippetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnippetProvider()) { entry in
            SnippetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘의 스니펫")
        .description("블라인드로 만나는 한 문장")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct SnippetWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnippetWidget()
        // 독서 세션 Live Activity (iOS 16.1+) — ReadingLiveActivity.swift
        if #available(iOS 16.1, *) {
            ReadingLiveActivity()
        }
    }
}
