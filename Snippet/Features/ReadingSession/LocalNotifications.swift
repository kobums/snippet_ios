import Foundation
import UserNotifications

// MARK: - LocalNotifications

/// 로컬 알림 헬퍼 — UNUserNotificationCenter 권한 요청 + "독서 중" 알림.
///
/// 백그라운드 진입 시 "독서 중" 알림 1개를 표시한다.
/// 앱이 포그라운드로 복귀하면 보류 중인 독서 알림을 제거한다.
enum LocalNotifications {

    static let readingNotificationID = "reading_session_active"

    // MARK: - 권한 요청

    /// 앱 최초 실행 시 또는 독서 세션 시작 전 호출.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - 독서 중 알림 예약

    /// 백그라운드 진입 시 즉시 발화 알림 예약 (trigger = 1초 후).
    /// 이미 예약된 독서 알림은 덮어쓴다.
    static func scheduleReadingActiveNotification(bookTitle: String, elapsedSeconds: Int) {
        let center = UNUserNotificationCenter.current()

        // 기존 독서 알림 제거
        center.removePendingNotificationRequests(withIdentifiers: [readingNotificationID])

        let content = UNMutableNotificationContent()
        content.title = "독서 중"
        content.body  = "\(bookTitle) — \(formattedElapsed(elapsedSeconds)) 경과"
        content.sound = .none

        // 1초 후 발화 (백그라운드 전환 직후)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(
            identifier: readingNotificationID,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - 독서 알림 제거

    /// 앱이 포그라운드로 복귀했거나 세션이 종료/포기될 때 호출.
    static func cancelReadingActiveNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [readingNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [readingNotificationID])
    }

    // MARK: - 헬퍼

    private static func formattedElapsed(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
