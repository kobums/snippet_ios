#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// 독서 세션 Live Activity 속성.
///
/// ⚠️ 이 타입은 **앱 타깃과 위젯 익스텐션 타깃 양쪽**에 멤버로 포함돼야 한다
/// (ActivityKit이 두 프로세스에서 동일 타입을 디코딩). 위젯 타깃 추가 절차는
/// `../LIVE-ACTIVITY-SETUP.md` 참조.
///
/// 시간 표시: `ContentState.timerReferenceDate`(= now - 누적경과)를 기준으로
/// `Text(timerInterval:)`가 잠금화면/다이나믹 아일랜드에서 자동 카운트한다.
@available(iOS 16.1, *)
struct ReadingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 타이머 가상 시작 시각 = 현재 - 총 누적 경과. running일 때 `Text(timerInterval:)` 기준점.
        var timerReferenceDate: Date
        /// 일시정지 여부 — true면 정적 경과(`pausedElapsed`) 표시.
        var isPaused: Bool
        /// 일시정지 시점의 총 경과(초).
        var pausedElapsed: TimeInterval
    }

    /// 책 제목 (Live Activity 헤더).
    var bookTitle: String
    /// 시작 페이지 (보조 표시).
    var startPage: Int
}
#endif
