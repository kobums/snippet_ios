import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// 독서 세션 Live Activity 시작/갱신/종료 래퍼.
///
/// ActivityKit 미지원 환경(iOS 16.0 이하)·위젯 타깃 미추가 시에도 앱이 컴파일·동작하도록
/// 전부 `#if canImport(ActivityKit)` + 가용성 가드로 감쌌다. Live Activity가 떠 있지 않아도
/// 타이머 자체는 기존 로컬 알림 경로로 정상 동작한다.
@MainActor
final class ReadingActivityController {

    static let shared = ReadingActivityController()
    private init() {}

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var activity: Activity<ReadingActivityAttributes>? {
        get { _activity as? Activity<ReadingActivityAttributes> }
        set { _activity = newValue }
    }
    private var _activity: Any?
    #endif

    /// 앱 시작 시 이전 실행에서 남은 고아 Live Activity 정리.
    ///
    /// 앱이 강제 종료되면 메모리 참조(`_activity`)가 사라져 `end()`가 닿지 않고,
    /// 잠금화면의 타이머가 계속 카운트업한다. 시스템에 등록된 활동 전체를 순회해
    /// 제거한다. (세션 복구 기능이 배선되기 전까지, 시작 시점의 활동은 전부 고아다)
    func cleanupOrphans() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        endAllActivities()
        #endif
    }

    /// 세션 시작 — Live Activity 시작 (running).
    func start(bookTitle: String, startPage: Int, elapsed: TimeInterval) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // 추적 중인 활동뿐 아니라 고아 활동까지 전부 정리 후 새로 시작 (중복 표시 방지)
        endAllActivities()
        let attributes = ReadingActivityAttributes(bookTitle: bookTitle, startPage: startPage)
        let state = ReadingActivityAttributes.ContentState(
            timerReferenceDate: Date().addingTimeInterval(-elapsed),
            isPaused: false,
            pausedElapsed: elapsed
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            // Live Activity 시작 실패는 무시 (타이머 동작에 영향 없음)
        }
        #endif
    }

    /// running 상태 갱신 — elapsed 기준으로 타이머 기준점 재설정.
    func updateRunning(elapsed: TimeInterval) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let state = ReadingActivityAttributes.ContentState(
            timerReferenceDate: Date().addingTimeInterval(-elapsed),
            isPaused: false,
            pausedElapsed: elapsed
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
        #endif
    }

    /// 일시정지 상태 갱신 — 정적 경과 표시.
    func updatePaused(elapsed: TimeInterval) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let state = ReadingActivityAttributes.ContentState(
            timerReferenceDate: Date().addingTimeInterval(-elapsed),
            isPaused: true,
            pausedElapsed: elapsed
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
        #endif
    }

    /// 세션 종료 — Live Activity 즉시 제거.
    func end() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        endInternal()
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func endInternal() {
        if let activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }

    /// 추적 중인 활동 + 시스템에 등록된 이 앱의 모든 활동(고아 포함)을 종료.
    @available(iOS 16.1, *)
    private func endAllActivities() {
        for existing in Activity<ReadingActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }
    #endif
}
