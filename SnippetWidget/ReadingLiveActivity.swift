#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - 독서 세션 Live Activity (위젯 익스텐션)
//
// ⚠️ 이 파일과 `ReadingActivityAttributes.swift`는 **위젯 익스텐션 타깃** 멤버여야 한다.
// 절차는 ../LIVE-ACTIVITY-SETUP.md 참조.
//
// 시간 표시: ContentState.timerReferenceDate(= now - 누적경과) 기준으로
//   running이면 Text(timerInterval:)로 자동 카운트, paused면 정적 경과를 보여준다.

@available(iOS 16.1, *)
struct ReadingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            // 잠금화면 / 배너 UI
            ReadingLiveActivityLockScreen(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("독서 중", systemImage: "book.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerView(context: context)
                        .font(.title3.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.bookTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "book.fill")
            } compactTrailing: {
                timerView(context: context)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "book.fill")
            }
        }
    }

    /// running이면 자동 카운트 타이머, paused면 정적 경과.
    @ViewBuilder
    private func timerView(context: ActivityViewContext<ReadingActivityAttributes>) -> some View {
        if context.state.isPaused {
            Text(formatElapsed(context.state.pausedElapsed))
        } else {
            Text(timerInterval: context.state.timerReferenceDate...Date.distantFuture, countsDown: false)
        }
    }
}

@available(iOS 16.1, *)
private struct ReadingLiveActivityLockScreen: View {
    let context: ActivityViewContext<ReadingActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.bookTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(context.attributes.startPage)p 에서 시작")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Group {
                if context.state.isPaused {
                    Text(formatElapsed(context.state.pausedElapsed))
                } else {
                    Text(timerInterval: context.state.timerReferenceDate...Date.distantFuture, countsDown: false)
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.title2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 80)
        }
        .padding()
    }
}

private func formatElapsed(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
}
#endif
